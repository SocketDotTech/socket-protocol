// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {AddressResolverUtil} from "./utils/AddressResolverUtil.sol";
import {IPromise} from "./interfaces/IPromise.sol";
import {IAppGateway} from "./interfaces/IAppGateway.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @notice The state of the async promise
enum AsyncPromiseState {
    WAITING_FOR_SET_CALLBACK_SELECTOR,
    WAITING_FOR_CALLBACK_EXECUTION,
    CALLBACK_REVERTING,
    ONCHAIN_REVERTING,
    RESOLVED
}

/// @title AsyncPromise
/// @notice this contract stores the callback address and data to be executed once the previous call is executed
/// This promise expires once the callback is executed
contract AsyncPromise is IPromise, Initializable, AddressResolverUtil {
    /// @notice The callback selector to be called on the invoker.
    bytes4 public callbackSelector;

    /// @notice Indicates whether the promise has been resolved.
    bool public override resolved;

    /// @notice The current state of the async promise.
    AsyncPromiseState public state;

    /// @notice The local contract which initiated the async call.
    /// @dev The callback will be executed on this address
    address public localInvoker;

    /// @notice The forwarder address which can call the callback
    address public forwarder;

    /// @notice The callback data to be used when the promise is resolved.
    bytes public callbackData;

    /// @notice Error thrown when attempting to resolve an already resolved promise.
    error PromiseAlreadyResolved();
    /// @notice Only the forwarder or local invoker can set then's promise callback
    error OnlyForwarderOrLocalInvoker();
    /// @notice Error thrown when attempting to set an already existing promise
    error PromiseAlreadySetUp();
    /// @notice Error thrown when the promise reverts
    error PromiseRevertFailed();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @param invoker_ The address of the local invoker.
    /// @param forwarder_ The address of the forwarder.
    /// @param addressResolver_ The address resolver contract address.
    function initialize(
        address invoker_,
        address forwarder_,
        address addressResolver_
    ) public initializer {
        _setAddressResolver(addressResolver_);
        localInvoker = invoker_;
        forwarder = forwarder_;
        state = AsyncPromiseState.WAITING_FOR_SET_CALLBACK_SELECTOR;
        resolved = false;
    }

    /// @notice Marks the promise as resolved and executes the callback if set.
    /// @param returnData_ The data returned from the async payload execution.
    /// @dev Only callable by the watcher precompile.
    function markResolved(
        bytes32 asyncId,
        bytes32 payloadId,
        bytes memory returnData_
    ) external override onlyWatcherPrecompile returns (bool success) {
        if (resolved) return true;

        resolved = true;
        state = AsyncPromiseState.RESOLVED;

        // Call callback to app gateway
        if (callbackSelector == bytes4(0)) return true;
        bytes memory combinedCalldata = abi.encodePacked(
            callbackSelector,
            abi.encode(callbackData, returnData_)
        );
        (success, ) = localInvoker.call(combinedCalldata);
        if (success) return success;

        _handleRevert(asyncId, payloadId, AsyncPromiseState.CALLBACK_REVERTING);
    }

    /// @notice Marks the promise as onchain reverting.
    /// @dev Only callable by the watcher precompile.
    function markOnchainRevert(
        bytes32 asyncId,
        bytes32 payloadId
    ) external override onlyWatcherPrecompile {
        _handleRevert(asyncId, payloadId, AsyncPromiseState.ONCHAIN_REVERTING);
    }

    function _handleRevert(bytes32 asyncId, bytes32 payloadId, AsyncPromiseState state_) internal {
        // to update the state in case selector is bytes(0) but reverting onchain
        resolved = false;
        state = state_;

        (bool success, ) = localInvoker.call(
            abi.encodeWithSelector(IAppGateway.handleRevert.selector, asyncId, payloadId)
        );
        if (!success) revert PromiseRevertFailed();
    }

    /// @notice Sets the callback selector and data for the promise.
    /// @param selector_ The function selector for the callback.
    /// @param data_ The data to be passed to the callback.
    /// @return promise_ The address of the current promise.
    function then(
        bytes4 selector_,
        bytes memory data_
    ) external override returns (address promise_) {
        if (msg.sender != forwarder && msg.sender != localInvoker) {
            revert OnlyForwarderOrLocalInvoker();
        }

        if (state == AsyncPromiseState.WAITING_FOR_CALLBACK_EXECUTION) {
            revert PromiseAlreadySetUp();
        }

        if (state == AsyncPromiseState.WAITING_FOR_SET_CALLBACK_SELECTOR) {
            callbackSelector = selector_;
            callbackData = data_;
            state = AsyncPromiseState.WAITING_FOR_CALLBACK_EXECUTION;
        }

        promise_ = address(this);
    }
}
