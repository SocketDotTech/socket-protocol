// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {AsyncPromiseState, PromiseReturnData} from "../../utils/common/Structs.sol";

/// @title IPromise
interface IPromise {
    /// @notice The current state of the async promise.
    function state() external view returns (AsyncPromiseState);

    /// @notice The local contract which initiated the async call.
    /// @dev The callback will be executed on this address
    function localInvoker() external view returns (address);

    /// @notice The request count of the promise
    function requestCount() external view returns (uint40);

    /// @notice The flag to check if the promise exceeded the max copy limit
    function exceededMaxCopy() external view returns (bool);

    /// @notice The return data of the promise
    function returnData() external view returns (bytes memory);

    /// @notice Sets the callback selector and data for the promise.
    /// @param selector_ The function selector for the callback.
    /// @param data_ The data to be passed to the callback.
    function then(bytes4 selector_, bytes memory data_) external;

    /// @notice Marks the promise as resolved and executes the callback if set.
    /// @dev Only callable by the watcher precompile.
    /// @param resolvedPromise_ The data returned from the async payload execution.
    function markResolved(
        PromiseReturnData memory resolvedPromise_
    ) external returns (bool success);

    /// @notice Marks the promise as onchain reverting.
    /// @dev Only callable by the watcher precompile.
    function markOnchainRevert(PromiseReturnData memory resolvedPromise_) external;
}
