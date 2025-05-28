// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Initializable} from "solady/utils/Initializable.sol";
import {LibCall} from "solady/utils/LibCall.sol";
import {AddressResolverUtil} from "./AddressResolverUtil.sol";
import {IAppGateway} from "../interfaces/IAppGateway.sol";
import "../interfaces/IPromise.sol";
import {NotInvoker, RequestCountMismatch} from "../../utils/common/Errors.sol";

abstract contract AsyncPromiseStorage is IPromise {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    /// @notice The callback selector to be called on the invoker.
    bytes4 public callbackSelector;

    /// @notice The flag to check if the promise exceeded the max copy limit
    bool public override exceededMaxCopy;

    /// @notice The current state of the async promise.
    AsyncPromiseState public override state;

    /// @notice The request count of the promise
    uint40 public override requestCount;

    /// @notice The local contract which initiated the call.
    /// @dev The callback will be executed on this address
    address public override localInvoker;

    /// @notice The return data of the promise
    bytes public override returnData;

    /// @notice The callback data to be used when the promise is resolved.
    bytes public callbackData;

    // slots [53-102] reserved for gap
    uint256[50] _gap_after;

    // slots 103-154 (51) reserved for addr resolver util
}

/// @title AsyncPromise
/// @notice this contract stores the callback selector and data to be executed once the on-chain call is executed
/// This promise expires once the callback is executed
contract AsyncPromise is AsyncPromiseStorage, Initializable, AddressResolverUtil {
    using LibCall for address;

    /// @notice Error thrown when attempting to resolve an already resolved promise.
    error PromiseAlreadyResolved();
    /// @notice Only the local invoker can set then's promise callback
    error OnlyInvoker();
    /// @notice Error thrown when attempting to set an already existing promise
    error PromiseAlreadySetUp();
    /// @notice Error thrown when the promise reverts
    error PromiseRevertFailed();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initialize promise states
    /// @param invoker_ The address of the local invoker
    /// @param addressResolver_ The address resolver contract address
    function initialize(
        uint40 requestCount_,
        address invoker_,
        address addressResolver_
    ) public initializer {
        localInvoker = invoker_;
        requestCount = requestCount_;
        _setAddressResolver(addressResolver_);
    }

    /// @notice Marks the promise as resolved and executes the callback if set.
    /// @dev Only callable by the watcher precompile.
    /// @param resolvedPromise_ The data returned from the async payload execution.
    function markResolved(
        PromiseReturnData memory resolvedPromise_
    ) external override onlyWatcher returns (bool success) {
        if (
            state == AsyncPromiseState.CALLBACK_REVERTING ||
            state == AsyncPromiseState.ONCHAIN_REVERTING ||
            state == AsyncPromiseState.RESOLVED
        ) revert PromiseAlreadyResolved();
        state = AsyncPromiseState.RESOLVED;

        // Call callback to app gateway
        if (callbackSelector == bytes4(0)) {
            success = true;
        } else {
            exceededMaxCopy = resolvedPromise_.maxCopyExceeded;
            returnData = resolvedPromise_.returnData;

            bytes memory combinedCalldata = abi.encodePacked(
                callbackSelector,
                abi.encode(callbackData, resolvedPromise_.returnData)
            );

            (success, , ) = localInvoker.tryCall(0, gasleft(), 0, combinedCalldata);
            if (!success) {
                state = AsyncPromiseState.CALLBACK_REVERTING;
                _handleRevert(resolvedPromise_.payloadId);
            }
        }
    }

    /// @notice Marks the promise as onchain reverting.
    /// @dev Only callable by the watcher precompile.
    function markOnchainRevert(
        PromiseReturnData memory resolvedPromise_
    ) external override onlyWatcher {
        if (
            state == AsyncPromiseState.CALLBACK_REVERTING ||
            state == AsyncPromiseState.ONCHAIN_REVERTING ||
            state == AsyncPromiseState.RESOLVED
        ) revert PromiseAlreadyResolved();

        // to update the state in case selector is bytes(0) but reverting onchain
        state = AsyncPromiseState.ONCHAIN_REVERTING;
        exceededMaxCopy = resolvedPromise_.maxCopyExceeded;
        returnData = resolvedPromise_.returnData;
        _handleRevert(resolvedPromise_.payloadId);
    }

    /// @notice Handles the revert of the promise.
    /// @dev Only callable by the watcher.
    /// @dev handleRevert function can be retried till it succeeds
    function _handleRevert(bytes32 payloadId_) internal {
        try IAppGateway(localInvoker).handleRevert(payloadId_) {} catch {
            // todo: in this case, promise will stay unresolved
            revert PromiseRevertFailed();
        }
    }

    /// @notice Sets the callback selector and data for the promise.
    /// @param selector_ The function selector for the callback.
    /// @param data_ The data to be passed to the callback.
    function then(bytes4 selector_, bytes memory data_) external override {
        if (msg.sender != localInvoker) revert NotInvoker();
        // if the promise is already set up, revert
        if (state != AsyncPromiseState.WAITING_FOR_CALLBACK_SELECTOR) {
            revert PromiseAlreadySetUp();
        }
        if (watcher__().latestAsyncPromise() != address(this)) revert PromiseAlreadySetUp();
        if (requestCount != watcher__().getCurrentRequestCount()) revert RequestCountMismatch();

        // if the promise is waiting for the callback selector, set it and update the state
        callbackSelector = selector_;
        callbackData = data_;
        state = AsyncPromiseState.WAITING_FOR_CALLBACK_EXECUTION;
    }
}
