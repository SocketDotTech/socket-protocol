// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./WatcherPrecompileStorage.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {AccessControl} from "../utils/AccessControl.sol";
import "solady/utils/Initializable.sol";
import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
abstract contract WatcherPrecompileCore is
    IWatcherPrecompile,
    WatcherPrecompileStorage,
    Initializable,
    AccessControl,
    AddressResolverUtil
{
    using DumpDecoder for bytes32;

    // ================== Timeout functions ==================

    /// @notice Sets a timeout for a payload execution on app gateway
    /// @param payload_ The payload data
    /// @param delayInSeconds_ The delay in seconds
    function _setTimeout(
        bytes calldata payload_,
        uint256 delayInSeconds_
    ) internal returns (bytes32 timeoutId) {
        if (delayInSeconds_ > maxTimeoutDelayInSeconds) revert TimeoutDelayTooLarge();

        // from auction manager
        watcherPrecompileLimits__.consumeLimit(_getCoreAppGateway(msg.sender), SCHEDULE, 1);
        uint256 executeAt = block.timestamp + delayInSeconds_;
        timeoutId = _encodeTimeoutId(evmxSlug, address(this));
        timeoutRequests[timeoutId] = TimeoutRequest(
            timeoutId,
            msg.sender,
            delayInSeconds_,
            executeAt,
            0,
            false,
            payload_
        );
        emit TimeoutRequested(timeoutId, msg.sender, payload_, executeAt);
    }

    function _finalize(
        PayloadParams memory params_,
        address transmitter_
    ) internal returns (bytes32 digest) {
        // Verify that the app gateway is properly configured for this chain and target
        watcherPrecompileConfig__.verifyConnections(
            params_.dump.getChainSlug(),
            params_.target,
            params_.appGateway,
            params_.switchboard
        );

        uint256 deadline = block.timestamp + expiryTime;
        payloads[params_.payloadId].deadline = deadline;
        payloads[params_.payloadId].finalizedTransmitter = transmitter_;

        bytes32 prevDigestsHash = _getPreviousDigestsHash(
            params_.dump.getRequestCount(),
            params_.dump.getBatchCount()
        );
        payloads[params_.payloadId].prevDigestsHash = prevDigestsHash;

        // Construct parameters for digest calculation
        DigestParams memory digestParams_ = DigestParams(
            transmitter_,
            params_.payloadId,
            deadline,
            params_.dump.getCallType(),
            params_.dump.getWriteFinality(),
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

    function _getBatch(uint40 batchCount) internal view returns (PayloadParams[] memory) {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount];
        PayloadParams[] memory payloadParamsArray = new PayloadParams[](payloadIds.length);

        for (uint40 i = 0; i < payloadIds.length; i++) {
            payloadParamsArray[i] = payloads[payloadIds[i]];
        }
        return payloadParamsArray;
    }

    // ================== Query functions ==================
    /// @notice Creates a new query request
    /// @param params_ The payload parameters
    function _query(PayloadParams memory params_) internal {
        bytes32 prevDigestsHash = _getPreviousDigestsHash(
            params_.dump.getRequestCount(),
            params_.dump.getBatchCount()
        );
        payloads[params_.payloadId].prevDigestsHash = prevDigestsHash;
        emit QueryRequested(params_);
    }

    /// @notice Calculates the digest hash of payload parameters
    /// @param params_ The payload parameters
    /// @return digest The calculated digest
    function getDigest(DigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            abi.encode(
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

    function _getPreviousDigestsHash(
        uint40 requestCount_,
        uint40 batchCount_
    ) internal view returns (bytes32) {
        RequestParams memory r = requestParams[requestCount_];

        // If this is the first batch of the request, return 0 bytes
        if (batchCount_ == r.payloadParamsArray[0].dump.getBatchCount()) {
            return bytes32(0);
        }

        PayloadParams[] memory previousPayloads = _getBatch(batchCount_ - 1);
        bytes32 prevDigestsHash = bytes32(0);

        for (uint40 i = 0; i < previousPayloads.length; i++) {
            PayloadParams memory p = payloads[previousPayloads[i].payloadId];
            DigestParams memory digestParams = DigestParams(
                p.finalizedTransmitter,
                p.payloadId,
                p.deadline,
                p.dump.getCallType(),
                p.dump.getWriteFinality(),
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

    // ================== Helper functions ==================

    /// @notice Verifies the connection between chain slug, target, and app gateway
    /// @param chainSlug_ The identifier of the chain
    /// @param target_ The target address
    /// @param appGateway_ The app gateway address to verify
    /// @dev Internal function to validate connections
    function _verifyConnections(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        address switchboard_
    ) internal view {
        // todo: revisit this
        // if target is contractFactoryPlug, return
        if (target_ == watcherPrecompileConfig__.contractFactoryPlug(chainSlug_)) return;

        (address appGateway, address switchboard) = watcherPrecompileConfig__.getPlugConfigs(
            chainSlug_,
            target_
        );
        if (appGateway != appGateway_) revert InvalidGateway();
        if (switchboard != switchboard_) revert InvalidSwitchboard();
    }

    function _encodeTimeoutId(uint32 chainSlug_, address watcher_) internal returns (bytes32) {
        // Encode timeout ID by bit-shifting and combining:
        // chainSlug (32 bits) | switchboard or watcher precompile address (160 bits) | counter (64 bits)
        return
            bytes32(
                (uint256(chainSlug_) << 224) | (uint256(uint160(watcher_)) << 64) | timeoutCounter++
            );
    }

    function _createPayloadId(
        PayloadSubmitParams memory p_,
        uint40 requestCount_,
        uint40 batchCount_,
        uint40 payloadCount_
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(requestCount_, batchCount_, payloadCount_, p_.switchboard, p_.chainSlug)
            );
    }

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

    function getBatches(uint40 requestCount_) external view returns (uint40[] memory) {
        return requestBatchIds[requestCount_];
    }

    function getBatchPayloadIds(uint40 batchCount_) external view returns (bytes32[] memory) {
        return batchPayloadIds[batchCount_];
    }

    function getPayloadParams(bytes32 payloadId_) external view returns (PayloadParams memory) {
        return payloads[payloadId_];
    }
}
