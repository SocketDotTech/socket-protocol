// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IAddressResolver.sol";
import "../interfaces/IMiddleware.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IPromise.sol";
import "../interfaces/IForwarder.sol";
import {AddressResolverUtil} from "./utils/AddressResolverUtil.sol";
import {AsyncModifierNotUsed, NoAsyncPromiseFound, PromiseCallerMismatch, RequestCountMismatch, DeliveryHelperNotSet} from "./utils/common/Errors.sol";
import "solady/utils/Initializable.sol";

/// @title Forwarder Storage
/// @notice Storage contract for the Forwarder contract that contains the state variables
abstract contract ForwarderStorage is IForwarder {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    /// @notice chain slug on which the contract is deployed
    uint32 public chainSlug;
    /// @notice on-chain address associated with this forwarder
    address public onChainAddress;

    // slot 51
    /// @notice caches the latest async promise address for the last call
    address public latestAsyncPromise;

    // slot 52
    /// @notice the address of the contract that called the latest async promise
    address public latestPromiseCaller;
    /// @notice the request count of the latest async promise
    uint40 public latestRequestCount;

    // slots [53-102] reserved for gap
    uint256[50] _gap_after;

    // slots 103-154 (51) reserved for addr resolver util
}

/// @title Forwarder Contract
/// @notice This contract acts as a forwarder for async calls to the on-chain contracts.
contract Forwarder is ForwarderStorage, Initializable, AddressResolverUtil {
    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @param chainSlug_ chain slug on which the contract is deployed
    /// @param onChainAddress_ on-chain address associated with this forwarder
    /// @param addressResolver_ address resolver contract
    function initialize(
        uint32 chainSlug_,
        address onChainAddress_,
        address addressResolver_
    ) public initializer {
        chainSlug = chainSlug_;
        onChainAddress = onChainAddress_;
        _setAddressResolver(addressResolver_);
    }

    /// @notice Stores the callback address and data to be executed once the promise is resolved.
    /// @dev This function should not be called before the fallback function.
    /// @dev It resets the latest async promise address
    /// @param selector_ The function selector for callback
    /// @param data_ The data to be passed to callback
    /// @return promise_ The address of the new promise
    function then(bytes4 selector_, bytes memory data_) external returns (address promise_) {
        if (latestAsyncPromise == address(0)) revert NoAsyncPromiseFound();
        if (latestPromiseCaller != msg.sender) revert PromiseCallerMismatch();
        if (latestRequestCount != watcherPrecompile__().nextRequestCount())
            revert RequestCountMismatch();

        address latestAsyncPromise_ = latestAsyncPromise;
        latestAsyncPromise = address(0);

        promise_ = IPromise(latestAsyncPromise_).then(selector_, data_);
    }

    /// @notice Returns the on-chain address associated with this forwarder.
    /// @return The on-chain address.
    function getOnChainAddress() external view returns (address) {
        return onChainAddress;
    }

    /// @notice Returns the chain slug on which the contract is deployed.
    /// @return chain slug
    function getChainSlug() external view returns (uint32) {
        return chainSlug;
    }

    /// @notice Fallback function to process the contract calls to onChainAddress
    /// @dev It queues the calls in the middleware and deploys the promise contract
    fallback() external {
        if (address(deliveryHelper__()) == address(0)) {
            revert DeliveryHelperNotSet();
        }

        // validates if the async modifier is set
        bool isAsyncModifierSet = IAppGateway(msg.sender).isAsyncModifierSet();
        if (!isAsyncModifierSet) revert AsyncModifierNotUsed();

        // Deploy a new async promise contract.
        latestAsyncPromise = addressResolver__.deployAsyncPromiseContract(msg.sender);

        // set the latest promise caller and request count for validating if the future .then call is valid
        latestPromiseCaller = msg.sender;
        latestRequestCount = watcherPrecompile__().nextRequestCount();

        // fetch the override params from app gateway
        (
            Read isReadCall,
            Parallel isParallelCall,
            WriteFinality writeFinality,
            uint256 readAt,
            uint256 gasLimit,
            uint256 value,
            bytes32 sbType
        ) = IAppGateway(msg.sender).getOverrideParams();

        // get the switchboard address from the watcher precompile config
        address switchboard = watcherPrecompileConfig().switchboards(chainSlug, sbType);

        // Queue the call in the middleware.
        deliveryHelper__().queue(
            QueuePayloadParams({
                chainSlug: chainSlug,
                callType: isReadCall == Read.ON ? CallType.READ : CallType.WRITE,
                isParallel: isParallelCall,
                isPlug: IsPlug.NO,
                writeFinality: writeFinality,
                asyncPromise: latestAsyncPromise,
                switchboard: switchboard,
                target: onChainAddress,
                appGateway: msg.sender,
                gasLimit: gasLimit,
                value: value,
                readAt: readAt,
                payload: msg.data,
                initCallData: bytes("")
            })
        );
    }
}
