// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {PayloadParams, ResolvedPromises} from "../../utils/common/Structs.sol";
import "../interfaces/IPromise.sol";
import "./WatcherBase.sol";

interface IPromiseResolver {
    function resolvePromises(ResolvedPromises[] calldata resolvedPromises_) external;

    function markRevert(bool isRevertingOnchain_, bytes32 payloadId_) external;
}

/// @title PromiseResolver
/// @notice Contract that handles promise resolution and revert marking logic
/// @dev This contract interacts with the Watcher for storage access
contract PromiseResolver is IPromiseResolver {
    error DeadlineNotPassedForOnChainRevert();

    /// @notice Sets the Watcher address
    /// @param watcher_ The address of the Watcher contract
    constructor(address watcher_) WatcherBase(watcher_) {}

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    /// @dev This function resolves multiple promises with their return data
    /// @dev It also processes the next batch if the current batch is complete
    function resolvePromises(ResolvedPromises[] memory resolvedPromises_) external onlyWatcher {
        for (uint256 i = 0; i < resolvedPromises_.length; i++) {
            (uint40 requestCount, bool success) = _processPromiseResolution(resolvedPromises_[i]);
            if (success) {
                requestHandler__().updateRequestAndProcessBatch(
                    requestCount,
                    resolvedPromises_[i].payloadId
                );
            }
        }
    }

    // todo: add max copy bytes and update function inputs
    function _processPromiseResolution(
        ResolvedPromises memory resolvedPromise_
    ) internal returns (uint40 requestCount, bool success) {
        PayloadParams memory payloadParams = requestHandler__().getPayloadParams(
            resolvedPromise_.payloadId
        );

        address asyncPromise = payloadParams.asyncPromise;
        requestCount = payloadParams.requestCount;

        if (asyncPromise != address(0)) {
            success = IPromise(asyncPromise).markResolved(
                requestCount,
                resolvedPromise_.payloadId,
                resolvedPromise_.returnData
            );

            if (!success) {
                emit PromiseNotResolved(resolvedPromise_.payloadId, asyncPromise);
                return (requestCount, false);
            }
        } else {
            success = true;
        }

        emit PromiseResolved(resolvedPromise_.payloadId, asyncPromise);
    }

    /// @notice Marks a request as reverting
    /// @param isRevertingOnchain_ Whether the request is reverting onchain
    /// @param payloadId_ The unique identifier of the payload
    /// @return success Whether the request was successfully marked as reverting
    function markRevert(bool isRevertingOnchain_, bytes32 payloadId_) external onlyWatcher {
        // Get payload params from Watcher
        PayloadParams memory payloadParams = requestHandler__().getPayloadParams(payloadId_);
        if (payloadParams.deadline > block.timestamp) revert DeadlineNotPassedForOnChainRevert();

        // marks the request as cancelled and settles the fees
        requestHandler__().cancelRequest(payloadParams.requestCount);

        // marks the promise as onchain reverting if the request is reverting onchain
        if (isRevertingOnchain_ && payloadParams.asyncPromise != address(0))
            IPromise(payloadParams.asyncPromise).markOnchainRevert(
                payloadParams.requestCount,
                payloadId_
            );

        emit MarkedRevert(payloadId_, isRevertingOnchain_);
    }
}
