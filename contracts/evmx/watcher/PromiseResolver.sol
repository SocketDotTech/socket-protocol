// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./WatcherBase.sol";
import "../interfaces/IPromise.sol";
import "../interfaces/IPromiseResolver.sol";
import {DeadlineNotPassedForOnChainRevert} from "../../utils/common/Errors.sol";
import "../../utils/RescueFundsLib.sol";

/// @title PromiseResolver
/// @notice Contract that handles promise resolution and revert marking logic
/// @dev This contract interacts with the Watcher for storage access
contract PromiseResolver is IPromiseResolver, WatcherBase {
    /// @notice Emitted when a promise is resolved
    /// @param payloadId The unique identifier for the resolved promise
    event PromiseResolved(bytes32 indexed payloadId, address asyncPromise);

    /// @notice Emitted when a promise is not resolved
    /// @param payloadId The unique identifier for the not resolved promise
    event PromiseNotResolved(bytes32 indexed payloadId, address asyncPromise);

    /// @notice Emitted when a payload is marked as revert
    /// @param payloadId The unique identifier for the payload
    /// @param isRevertingOnchain Whether the payload is reverting onchain
    event MarkedRevert(bytes32 indexed payloadId, bool isRevertingOnchain);

    /// @notice Sets the Watcher address
    /// @param watcher_ The address of the Watcher contract
    constructor(address watcher_) {
        _initializeWatcher(watcher_);
    }

    /// @notice Resolves multiple promises with their return data
    /// @param promiseReturnData_ Array of resolved promises and their return data
    /// @dev This function resolves multiple promises with their return data
    /// @dev It also processes the next batch if the current batch is complete
    function resolvePromises(PromiseReturnData[] memory promiseReturnData_) external onlyWatcher {
        for (uint256 i = 0; i < promiseReturnData_.length; i++) {
            (uint40 requestCount, bool success) = _processPromiseResolution(promiseReturnData_[i]);
            if (success) {
                requestHandler__().updateRequestAndProcessBatch(
                    requestCount,
                    promiseReturnData_[i].payloadId
                );
            }
        }
    }

    function _processPromiseResolution(
        PromiseReturnData memory resolvedPromise_
    ) internal returns (uint40 requestCount, bool success) {
        bytes32 payloadId = resolvedPromise_.payloadId;
        PayloadParams memory payloadParams = watcher__.getPayloadParams(payloadId);
        if (payloadParams.deadline < block.timestamp) revert DeadlinePassed();

        address asyncPromise = payloadParams.asyncPromise;
        requestCount = payloadParams.requestCount;

        if (asyncPromise != address(0)) {
            success = IPromise(asyncPromise).markResolved(resolvedPromise_);

            if (!success) {
                emit PromiseNotResolved(payloadId, asyncPromise);
                return (requestCount, false);
            }
        } else {
            success = true;
        }

        emit PromiseResolved(payloadId, asyncPromise);
    }

    /// @notice Marks a request as reverting
    /// @param isRevertingOnchain_ Whether the request is reverting onchain
    /// @param resolvedPromise_ The resolved promise
    /// @dev This function marks a request as reverting
    /// @dev It cancels the request and marks the promise as onchain reverting if the request is reverting onchain
    function markRevert(
        PromiseReturnData memory resolvedPromise_,
        bool isRevertingOnchain_
    ) external onlyWatcher {
        // Get payload params from Watcher
        bytes32 payloadId = resolvedPromise_.payloadId;
        PayloadParams memory payloadParams = watcher__.getPayloadParams(payloadId);
        if (payloadParams.deadline > block.timestamp) revert DeadlineNotPassedForOnChainRevert();

        // marks the request as cancelled and settles the fees
        requestHandler__().cancelRequestForReverts(payloadParams.requestCount);

        // marks the promise as onchain reverting if the request is reverting onchain
        if (isRevertingOnchain_ && payloadParams.asyncPromise != address(0))
            IPromise(payloadParams.asyncPromise).markOnchainRevert(resolvedPromise_);

        emit MarkedRevert(payloadId, isRevertingOnchain_);
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(address token_, address rescueTo_, uint256 amount_) external onlyWatcher {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
