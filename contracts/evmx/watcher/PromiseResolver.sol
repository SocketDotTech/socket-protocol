// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcher.sol";
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

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    /// @dev This function resolves multiple promises with their return data
    /// @dev It verifies that the signature is valid
    /// @dev It also processes the next batch if the current batch is complete
    function resolvePromises(
        ResolvedPromises[] memory resolvedPromises_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external {
        for (uint256 i = 0; i < resolvedPromises_.length; i++) {
            uint40 requestCount = payloads[resolvedPromises_[i].payloadId]
                .payloadHeader
                .getRequestCount();
            RequestParams storage requestParams_ = requestParams[requestCount];

            _processPromiseResolution(resolvedPromises_[i], requestParams_);
            _checkAndProcessBatch(requestParams_, requestCount);
        }
    }

    function _processPromiseResolution(
        ResolvedPromises memory resolvedPromise_,
        RequestParams storage requestParams_
    ) internal {
        PayloadParams memory payloadParams = payloads[resolvedPromise_.payloadId];
        address asyncPromise = payloadParams.asyncPromise;
        uint40 requestCount = payloadParams.payloadHeader.getRequestCount();

        if (asyncPromise != address(0)) {
            bool success = IPromise(asyncPromise).markResolved(
                requestCount,
                resolvedPromise_.payloadId,
                resolvedPromise_.returnData
            );

            if (!success) {
                emit PromiseNotResolved(resolvedPromise_.payloadId, asyncPromise);
                return;
            }
        }

        isPromiseExecuted[resolvedPromise_.payloadId] = true;
        requestParams_.currentBatchPayloadsLeft--;
        requestParams_.payloadsRemaining--;

        emit PromiseResolved(resolvedPromise_.payloadId, asyncPromise);
    }

    function _checkAndProcessBatch(
        RequestParams storage requestParams_,
        uint40 requestCount
    ) internal {
        if (requestParams_.currentBatchPayloadsLeft == 0 && requestParams_.payloadsRemaining > 0) {
            _processBatch(requestCount, ++requestParams_.currentBatch);
        }

        if (requestParams_.payloadsRemaining == 0) {
            IMiddleware(requestParams_.middleware).finishRequest(requestCount);
        }
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
        PayloadParams memory payloadParams = payloads[payloadId_];
        if (payloadParams.deadline > block.timestamp) revert DeadlineNotPassedForOnChainRevert();

        RequestParams storage currentRequestParams = requestParams[
            payloadParams.payloadHeader.getRequestCount()
        ];
        currentRequestParams.isRequestCancelled = true;

        IMiddleware(currentRequestParams.middleware).handleRequestReverts(
            payloadParams.payloadHeader.getRequestCount()
        );

        if (isRevertingOnchain_ && payloadParams.asyncPromise != address(0))
            IPromise(payloadParams.asyncPromise).markOnchainRevert(
                payloadParams.payloadHeader.getRequestCount(),
                payloadId_
            );

        emit MarkedRevert(payloadId_, isRevertingOnchain_);
    }
}
