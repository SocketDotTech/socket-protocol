// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcherPrecompile.sol";
import "../../interfaces/IPromise.sol";
import "../../libs/PayloadHeaderDecoder.sol";
import "../../common/Structs.sol";
import "../../common/Errors.sol";
import "../../core/WatcherIdUtils.sol";

interface IPromiseResolver {
      function resolvePromises(
        ResolvedPromises[] calldata resolvedPromises_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    function markRevert(
        bool isRevertingOnchain_,
        bytes32 payloadId_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;
}

/// @title PromiseResolver
/// @notice Contract that handles promise resolution and revert marking logic
/// @dev This contract interacts with the WatcherPrecompileStorage for storage access
contract PromiseResolver {
    using PayloadHeaderDecoder for bytes32;

    // The address of the WatcherPrecompileStorage contract
    address public watcherStorage;

    // Only WatcherPrecompileStorage can call functions
    modifier onlyWatcherStorage() {
        require(msg.sender == watcherStorage, "Only WatcherStorage can call");
        _;
    }

    /// @notice Sets the WatcherPrecompileStorage address
    /// @param watcherStorage_ The address of the WatcherPrecompileStorage contract
    constructor(address watcherStorage_) {
        watcherStorage = watcherStorage_;
    }

    /// @notice Updates the WatcherPrecompileStorage address
    /// @param watcherStorage_ The new address of the WatcherPrecompileStorage contract
    function setWatcherStorage(address watcherStorage_) external onlyWatcherStorage {
        watcherStorage = watcherStorage_;
    }

    /// @notice Resolves a promise with return data
    /// @param resolvedPromise The resolved promise data
    /// @param requestCount The request count associated with the promise
    /// @return success Whether the promise was successfully resolved
    function resolvePromise(
        ResolvedPromises memory resolvedPromise,
        uint40 requestCount
    ) external onlyWatcherStorage returns (bool success) {
        // Get payload params and request params from WatcherPrecompileStorage
        IWatcherPrecompile watcher = IWatcherPrecompile(watcherStorage);
        PayloadParams memory payloadParams = watcher.getPayloadParams(resolvedPromise.payloadId);

        address asyncPromise = payloadParams.asyncPromise;

        // If there's no promise contract, nothing to resolve
        if (asyncPromise == address(0)) {
            return false;
        }

        // Attempt to resolve the promise through the promise contract
        bool resolutionSuccess = IPromise(asyncPromise).markResolved(
            requestCount,
            resolvedPromise.payloadId,
            resolvedPromise.returnData
        );

        if (!resolutionSuccess) {
            // Emit event through WatcherPrecompileStorage
            emit IWatcherPrecompile.PromiseNotResolved(resolvedPromise.payloadId, asyncPromise);
            return false;
        }

        // Update storage in WatcherPrecompileStorage
        watcher.updateResolvedAt(resolvedPromise.payloadId, block.timestamp);
        watcher.decrementBatchCounters(requestCount);
        // payloadsRemaining--

        // Emit event through WatcherPrecompileStorage
        emit IWatcherPrecompile.PromiseResolved(resolvedPromise.payloadId, asyncPromise);

        // Check if we need to process next batch
        processBatch(requestCount);

        return true;
    }

    /// @notice Marks a request as reverting
    /// @param isRevertingOnchain Whether the request is reverting onchain
    /// @param payloadId The unique identifier of the payload
    /// @param currentTimestamp The current block timestamp
    /// @return success Whether the request was successfully marked as reverting
    function markRevert(
        bool isRevertingOnchain,
        bytes32 payloadId,
        uint256 currentTimestamp
    ) external onlyWatcherStorage returns (bool success) {
        // Get payload params from WatcherPrecompileStorage
        IWatcherPrecompile watcher = IWatcherPrecompile(watcherStorage);
        PayloadParams memory payloadParams = watcher.getPayloadParams(payloadId);

        // Validate deadline
        if (payloadParams.deadline > currentTimestamp) {
            return false;
        }

        uint40 requestCount = payloadParams.payloadHeader.getRequestCount();

        // Mark request as cancelled directly in the watcher
        watcher.cancelRequest(requestCount);

        // Handle onchain revert if necessary
        if (isRevertingOnchain && payloadParams.asyncPromise != address(0)) {
            IPromise(payloadParams.asyncPromise).markOnchainRevert(requestCount, payloadId);
        }

        // Emit event through WatcherPrecompileStorage
        emit IWatcherPrecompile.MarkedRevert(payloadId, isRevertingOnchain);

        return true;
    }

    /// @notice Check if we need to process next batch
    /// @param requestCount The request count
    function _checkAndProcessBatch(uint40 requestCount) private {
        IWatcherPrecompile watcher = IWatcherPrecompile(watcherStorage);

        // Check if current batch is complete and there are more payloads to process
        if (shouldProcessNextBatch(requestCount)) {
            // Process next batch
            watcher.processNextBatch(requestCount);
        }

        // Check if request is complete
        if (isRequestComplete(requestCount)) {
            // Finish request
            watcher.finishRequest(requestCount);
        }
    }

    /// @notice Determines if a request is complete
    /// @param payloadsRemaining Total payloads remaining for the request
    /// @return isComplete Whether the request is complete
    function isRequestComplete(uint256 payloadsRemaining) public pure returns (bool isComplete) {
        return payloadsRemaining == 0;
    }

    /// @notice Validates that a promise can be resolved
    /// @param payloadId The unique identifier of the payload
    /// @param requestCount The request count
    /// @return isValid Whether the promise can be resolved
    function validatePromiseResolution(
        bytes32 payloadId,
        uint40 requestCount
    ) external view returns (bool isValid) {
        if (payloadId == bytes32(0) || requestCount == 0) return false;

        IWatcherPrecompile watcher = IWatcherPrecompile(watcherStorage);
        // Check if the request has been cancelled
        if (watcher.isRequestCancelled(requestCount)) return false;

        // Check if the promise has already been executed
        if (watcher.isPromiseExecuted(payloadId)) return false;

        return true;
    }

    /// @notice Validates that a request can be marked as reverting
    /// @param payloadId The unique identifier of the payload
    /// @param deadline The deadline for the payload execution
    /// @param currentTimestamp The current block timestamp
    /// @return isValid Whether the request can be marked as reverting
    function validateRevertMarking(
        bytes32 payloadId,
        uint256 deadline,
        uint256 currentTimestamp
    ) external view returns (bool isValid) {
        if (payloadId == bytes32(0)) return false;
        if (deadline > currentTimestamp) return false;

        IWatcherPrecompile watcher = IWatcherPrecompile(watcherStorage);
        uint40 requestCount = watcher.getRequestCountFromPayloadId(payloadId);

        // Check if the request has already been cancelled
        if (watcher.isRequestCancelled(requestCount)) return false;

        return true;
    }

    /// @notice Determines if a batch should be processed next
    /// @param currentBatchPayloadsLeft Number of payloads left in current batch
    /// @param payloadsRemaining Total payloads remaining
    /// @return shouldProcess Whether next batch should be processed
    function shouldProcessNextBatch(
        uint256 currentBatchPayloadsLeft,
        uint256 payloadsRemaining
    ) public pure returns (bool shouldProcess) {
        return currentBatchPayloadsLeft == 0 && payloadsRemaining > 0;
    }
}
