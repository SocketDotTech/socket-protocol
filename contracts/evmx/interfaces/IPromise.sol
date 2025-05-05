// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/// @title IPromise
interface IPromise {
    /// @notice Sets the callback selector and data for the promise.
    /// @param selector_ The function selector for the callback.
    /// @param data_ The data to be passed to the callback.
    /// @return promise_ The address of the current promise
    function then(bytes4 selector_, bytes memory data_) external returns (address promise_);

    /// @notice Marks the promise as resolved and executes the callback if set.
    /// @dev Only callable by the watcher precompile.
    /// @param returnData_ The data returned from the async payload execution.
    function markResolved(
        uint40 requestCount_,
        bytes32 payloadId_,
        bytes memory returnData_
    ) external returns (bool success);

    /// @notice Marks the promise as onchain reverting.
    /// @dev Only callable by the watcher precompile.
    function markOnchainRevert(uint40 requestCount_, bytes32 payloadId_) external;

    /// @notice Indicates whether the promise has been resolved.
    function resolved() external view returns (bool);
}
