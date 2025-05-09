// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ECDSA} from "solady/utils/ECDSA.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import "solady/utils/Initializable.sol";
import {AddressResolverUtil} from "../../AddressResolverUtil.sol";
import {IFeesManager} from "../../interfaces/IFeesManager.sol";
import "./WatcherIdUtils.sol";
import "./WatcherPrecompileStorage.sol";

/// @title WatcherPrecompileCore
/// @notice Core functionality for the WatcherPrecompile system
/// @dev This contract implements the core functionality for payload verification, execution, and app configurations
/// @dev It is inherited by WatcherPrecompile and provides the base implementation for request handling
abstract contract WatcherPrecompileCore is
    IWatcherPrecompile,
    WatcherPrecompileStorage,
    Initializable,
    Ownable,
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
        bytes memory payload_
    ) internal returns (bytes32 timeoutId) {
        if (delayInSeconds_ > maxTimeoutDelayInSeconds) revert TimeoutDelayTooLarge();
        _consumeCallbackFeesFromAddress(watcherPrecompileLimits__.timeoutFees(), msg.sender);

        uint256 executeAt = block.timestamp + delayInSeconds_;
        timeoutId = _encodeTimeoutId();

        timeoutRequests[timeoutId].target = msg.sender;
        timeoutRequests[timeoutId].delayInSeconds = delayInSeconds_;
        timeoutRequests[timeoutId].executeAt = executeAt;
        timeoutRequests[timeoutId].payload = payload_;

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

        _consumeCallbackFeesFromRequestCount(
            watcherPrecompileLimits__.finalizeFees(),
            params_.payloadHeader.getRequestCount()
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
            params_.gasLimit,
            params_.value,
            params_.payload,
            params_.target,
            WatcherIdUtils.encodeAppGatewayId(params_.appGateway),
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
        _consumeCallbackFeesFromRequestCount(
            watcherPrecompileLimits__.queryFees(),
            params_.payloadHeader.getRequestCount()
        );

        payloads[params_.payloadId].prevDigestsHash = _getPreviousDigestsHash(
            params_.payloadHeader.getBatchCount()
        );
    }

    // ================== Helper functions ==================

    /// @notice Calculates the digest hash of payload parameters
    /// @dev extraData is empty for now, not needed for this EVMx
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
                params_.gasLimit,
                params_.value,
                params_.payload,
                params_.target,
                params_.appGatewayId,
                params_.prevDigestsHash,
                bytes("")
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
                p.gasLimit,
                p.value,
                p.payload,
                p.target,
                WatcherIdUtils.encodeAppGatewayId(p.appGateway),
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

   

    function _consumeCallbackFeesFromRequestCount(uint256 fees_, uint40 requestCount_) internal {
        // for callbacks in all precompiles
        uint256 feesToConsume = fees_ + watcherPrecompileLimits__.callBackFees();
        IFeesManager(addressResolver__.feesManager())
            .assignWatcherPrecompileCreditsFromRequestCount(feesToConsume, requestCount_);
    }

    function _consumeCallbackFeesFromAddress(uint256 fees_, address consumeFrom_) internal {
        // for callbacks in all precompiles
        uint256 feesToConsume = fees_ + watcherPrecompileLimits__.callBackFees();
        IFeesManager(addressResolver__.feesManager()).assignWatcherPrecompileCreditsFromAddress(
            feesToConsume,
            consumeFrom_
        );
    }

}
