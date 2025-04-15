// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./WatcherPrecompileStorage.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {AccessControl} from "../../utils/AccessControl.sol";
import "solady/utils/Initializable.sol";
import {AddressResolverUtil} from "../../utils/AddressResolverUtil.sol";

/// @title WatcherPrecompileCore
/// @notice Core functionality for the WatcherPrecompile system
/// @dev This contract implements the core functionality for payload verification, execution, and app configurations
/// @dev It is inherited by WatcherPrecompile and provides the base implementation for request handling
abstract contract WatcherPrecompileCore is
    IWatcherPrecompile,
    WatcherPrecompileStorage,
    Initializable,
    AccessControl,
    AddressResolverUtil
{
    using PayloadHeaderDecoder for bytes32;

    // slots [216-265] reserved for gap
    uint256[50] _core_gap;

    // ================== Timeout functions ==================

    /// @notice Sets a timeout for a payload execution on app gateway
    /// @return timeoutId The unique identifier for the timeout request
    function _setTimeout(
        uint256 delayInSeconds_,
        bytes calldata payload_
    ) internal returns (bytes32 timeoutId) {
        if (delayInSeconds_ > maxTimeoutDelayInSeconds) revert TimeoutDelayTooLarge();

        uint256 executeAt = block.timestamp + delayInSeconds_;
        timeoutId = _encodeTimeoutId();

        // stores timeout request for watcher to track and resolve when timeout is reached
        timeoutRequests[timeoutId] = TimeoutRequest(
            timeoutId,
            msg.sender,
            delayInSeconds_,
            executeAt,
            0,
            false,
            payload_
        );

        // consumes limit for SCHEDULE precompile
        watcherPrecompileLimits__.consumeLimit(_getCoreAppGateway(msg.sender), SCHEDULE, 1);

        // emits event for watcher to track timeout and resolve when timeout is reached
        emit TimeoutRequested(timeoutId, msg.sender, payload_, executeAt);
    }

    /// @notice Finalizes a payload request and requests the watcher to release the proofs
    /// @param params_ The payload parameters to be finalized
    /// @param transmitter_ The address of the transmitter
    /// @return digest The digest hash of the finalized payload
    /// @dev This function verifies the app gateway configuration and creates a digest for the payload
    function _finalize(
        PayloadParams memory params_,
        address transmitter_
    ) internal returns (bytes32 digest) {
        uint32 chainSlug = params_.payloadHeader.getChainSlug();

        // Verify that the app gateway is properly configured for this chain and target
        watcherPrecompileConfig__.verifyConnections(
            chainSlug,
            params_.target,
            params_.appGateway,
            params_.switchboard,
            requestParams[params_.payloadHeader.getRequestCount()].middleware
        );

        uint256 deadline = block.timestamp + expiryTime;
        payloads[params_.payloadId].deadline = deadline;
        payloads[params_.payloadId].finalizedTransmitter = transmitter_;

        bytes32 prevDigestsHash = _getPreviousDigestsHash(params_.payloadHeader.getBatchCount());
        payloads[params_.payloadId].prevDigestsHash = prevDigestsHash;

        // Construct parameters for digest calculation
        DigestParams memory digestParams_ = DigestParams(
            watcherPrecompileConfig__.sockets(chainSlug),
            transmitter_,
            params_.payloadId,
            deadline,
            params_.payloadHeader.getCallType(),
            params_.payloadHeader.getWriteFinality(),
            params_.gasLimit,
            params_.value,
            params_.readAt,
            params_.payload,
            params_.target,
            params_.appGateway,
            prevDigestsHash
        );

        // Calculate digest from payload parameters
        digest = getDigest(digestParams_);
        emit FinalizeRequested(digest, payloads[params_.payloadId]);
    }

    // ================== Query functions ==================

    /// @notice Creates a new query request
    /// @param params_ The payload parameters for the query
    /// @dev This function sets up a query request and emits a QueryRequested event
    function _query(PayloadParams memory params_) internal {
        bytes32 prevDigestsHash = _getPreviousDigestsHash(params_.payloadHeader.getBatchCount());
        payloads[params_.payloadId].prevDigestsHash = prevDigestsHash;
        emit QueryRequested(params_);
    }

    // ================== Helper functions ==================

    /// @notice Calculates the digest hash of payload parameters
    /// @param params_ The payload parameters to calculate the digest for
    /// @return digest The calculated digest hash
    /// @dev This function creates a keccak256 hash of the payload parameters
    function getDigest(DigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            abi.encode(
                params_.socket,
                params_.transmitter,
                params_.payloadId,
                params_.deadline,
                params_.callType,
                params_.writeFinality,
                params_.gasLimit,
                params_.value,
                params_.readAt,
                params_.payload,
                params_.target,
                params_.appGateway,
                params_.prevDigestsHash
            )
        );
    }

    /// @notice Gets the hash of previous batch digests
    /// @param batchCount_ The batch count to get the previous digests hash
    /// @return The hash of all digests in the previous batch
    function _getPreviousDigestsHash(uint40 batchCount_) internal view returns (bytes32) {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount_];
        bytes32 prevDigestsHash = bytes32(0);

        for (uint40 i = 0; i < payloadIds.length; i++) {
            PayloadParams memory p = payloads[payloadIds[i]];
            DigestParams memory digestParams = DigestParams(
                watcherPrecompileConfig__.sockets(p.payloadHeader.getChainSlug()),
                p.finalizedTransmitter,
                p.payloadId,
                p.deadline,
                p.payloadHeader.getCallType(),
                p.payloadHeader.getWriteFinality(),
                p.gasLimit,
                p.value,
                p.readAt,
                p.payload,
                p.target,
                p.appGateway,
                p.prevDigestsHash
            );
            prevDigestsHash = keccak256(abi.encodePacked(prevDigestsHash, getDigest(digestParams)));
        }
        return prevDigestsHash;
    }

    /// @notice Gets the batch of payload parameters for a given batch count
    /// @param batchCount The batch count to get the payload parameters for
    /// @return An array of PayloadParams for the given batch
    /// @dev This function retrieves all payload parameters for a specific batch
    function _getBatch(uint40 batchCount) internal view returns (PayloadParams[] memory) {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount];
        PayloadParams[] memory payloadParamsArray = new PayloadParams[](payloadIds.length);

        for (uint40 i = 0; i < payloadIds.length; i++) {
            payloadParamsArray[i] = payloads[payloadIds[i]];
        }
        return payloadParamsArray;
    }

    /// @notice Encodes an ID for a timeout or payload
    /// @return The encoded ID
    /// @dev This function creates a unique ID by combining the chain slug, address, and a counter
    function _encodeTimeoutId() internal returns (bytes32) {
        // Encode timeout ID by bit-shifting and combining:
        // EVMx chainSlug (32 bits) | watcher precompile address (160 bits) | counter (64 bits)
        return
            bytes32(
                (uint256(evmxSlug) << 224) |
                    (uint256(uint160(address(this))) << 64) |
                    payloadCounter++
            );
    }

    /// @notice Creates a payload ID from the given parameters
    /// @param requestCount_ The request count
    /// @param batchCount_ The batch count
    /// @param payloadCount_ The payload count
    /// @param switchboard_ The switchboard address
    /// @param chainSlug_ The chain slug
    /// @return The created payload ID
    function _createPayloadId(
        uint40 requestCount_,
        uint40 batchCount_,
        uint40 payloadCount_,
        address switchboard_,
        uint32 chainSlug_
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(requestCount_, batchCount_, payloadCount_, switchboard_, chainSlug_)
            );
    }

    /// @notice Verifies that a watcher signature is valid
    /// @param digest_ The digest to verify
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature to verify
    /// @dev This function verifies that the signature was created by the watcher and that the nonce has not been used before
    function _isWatcherSignatureValid(
        bytes memory digest_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) internal {
        if (isNonceUsed[signatureNonce_]) revert NonceUsed();
        isNonceUsed[signatureNonce_] = true;

        bytes32 digest = keccak256(abi.encode(address(this), evmxSlug, signatureNonce_, digest_));
        digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        // recovered signer is checked for the valid roles later
        address signer = ECDSA.recover(digest, signature_);
        if (signer != owner()) revert InvalidWatcherSignature();
    }

    /// @notice Gets the batch IDs for a request
    /// @param requestCount_ The request count to get the batch IDs for
    /// @return An array of batch IDs for the given request
    function getBatches(uint40 requestCount_) external view returns (uint40[] memory) {
        return requestBatchIds[requestCount_];
    }

    /// @notice Gets the payload IDs for a batch
    /// @param batchCount_ The batch count to get the payload IDs for
    /// @return An array of payload IDs for the given batch
    function getBatchPayloadIds(uint40 batchCount_) external view returns (bytes32[] memory) {
        return batchPayloadIds[batchCount_];
    }

    /// @notice Gets the payload parameters for a payload ID
    /// @param payloadId_ The payload ID to get the parameters for
    /// @return The payload parameters for the given payload ID
    function getPayloadParams(bytes32 payloadId_) external view returns (PayloadParams memory) {
        return payloads[payloadId_];
    }
}
