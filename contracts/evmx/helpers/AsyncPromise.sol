// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Initializable} from "solady/utils/Initializable.sol";
import {LibCall} from "solady/utils/LibCall.sol";
import {IPromise} from "./interfaces/IPromise.sol";
import {IAppGateway} from "./interfaces/IAppGateway.sol";
import {AddressResolverUtil} from "./AddressResolverUtil.sol";
import {AsyncPromiseState} from "../utils/common/Structs.sol";
import {MAX_COPY_BYTES} from "../utils/common/Constants.sol";

abstract contract AsyncPromiseStorage is IPromise {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // bytes1
    /// @notice The callback selector to be called on the invoker.
    bytes4 public callbackSelector;
    // bytes4
    /// @notice Indicates whether the promise has been resolved.
    bool public override resolved;
    // bytes8
    /// @notice The current state of the async promise.
    AsyncPromiseState public state;
    // bytes20
    /// @notice The local contract which initiated the async call.
    /// @dev The callback will be executed on this address
    address public localInvoker;

    // slot 52
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
    function initialize(address invoker_, address addressResolver_) public initializer {
        localInvoker = invoker_;
        _setAddressResolver(addressResolver_);
    }

    /// @notice Marks the promise as resolved and executes the callback if set.
    /// @dev Only callable by the watcher precompile.
    /// @param returnData_ The data returned from the async payload execution.
    function markResolved(
        uint40 requestCount_,
        bytes32 payloadId_,
        bytes memory returnData_
    ) external override onlyWatcher returns (bool success) {
        if (resolved) revert PromiseAlreadyResolved();

        resolved = true;
        state = AsyncPromiseState.RESOLVED;

        // Call callback to app gateway
        if (callbackSelector == bytes4(0)) return true;

        bytes memory combinedCalldata = abi.encodePacked(
            callbackSelector,
            abi.encode(callbackData, returnData_)
        );

        // setting max_copy_bytes to 0 as not using returnData right now
        (success, , ) = localInvoker.tryCall(0, gasleft(), 0, combinedCalldata);
        if (success) return success;

        _handleRevert(requestCount_, payloadId_, AsyncPromiseState.CALLBACK_REVERTING);
    }

    /// @notice Marks the promise as onchain reverting.
    /// @dev Only callable by the watcher precompile.
    function markOnchainRevert(
        uint40 requestCount_,
        bytes32 payloadId_
    ) external override onlyWatcher {
        _handleRevert(requestCount_, payloadId_, AsyncPromiseState.ONCHAIN_REVERTING);
    }

    function _handleRevert(
        uint40 requestCount_,
        bytes32 payloadId_,
        AsyncPromiseState state_
    ) internal {
        // to update the state in case selector is bytes(0) but reverting onchain
        resolved = true;
        state = state_;
        try IAppGateway(localInvoker).handleRevert(requestCount_, payloadId_) {
            // Successfully handled revert
        } catch {
            revert PromiseRevertFailed();
        }
    }

    /// @notice Sets the callback selector and data for the promise.
    /// @param selector_ The function selector for the callback.
    /// @param data_ The data to be passed to the callback.
    /// @return promise_ The address of the current promise.
    function then(
        bytes4 selector_,
        bytes memory data_
    ) external override onlyWatcher returns (address promise_) {
        // if the promise is already set up, revert
        if (state == AsyncPromiseState.WAITING_FOR_CALLBACK_EXECUTION) {
            revert PromiseAlreadySetUp();
        }

        // if the promise is waiting for the callback selector, set it and update the state
        if (state == AsyncPromiseState.WAITING_FOR_SET_CALLBACK_SELECTOR) {
            callbackSelector = selector_;
            callbackData = data_;
            state = AsyncPromiseState.WAITING_FOR_CALLBACK_EXECUTION;
        }

        promise_ = address(this);
    }
}
