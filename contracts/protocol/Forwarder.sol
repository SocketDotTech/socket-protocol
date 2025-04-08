// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../interfaces/IAddressResolver.sol";
import "../interfaces/IMiddleware.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IPromise.sol";
import "../interfaces/IForwarder.sol";

import {AddressResolverUtil} from "./utils/AddressResolverUtil.sol";
import "solady/utils/Initializable.sol";

abstract contract ForwarderStorage is IForwarder {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    /// @notice chain id
    uint32 public chainSlug;

    /// @notice on-chain address associated with this forwarder
    address public onChainAddress;

    // slot 51
    /// @notice caches the latest async promise address for the last call
    address public latestAsyncPromise;

    // slots [52-101] reserved for gap
    uint256[50] _gap_after;
}

/// @title Forwarder Contract
/// @notice This contract acts as a forwarder for async calls to the on-chain contracts.
contract Forwarder is ForwarderStorage, Initializable, AddressResolverUtil {
    error AsyncModifierNotUsed();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @param chainSlug_ chain id
    /// @param onChainAddress_ on-chain address
    /// @param addressResolver_ address resolver contract address
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
    /// @param selector_ The function selector for callback
    /// @param data_ The data to be passed to callback
    /// @return promise_ The address of the new promise
    function then(bytes4 selector_, bytes memory data_) external returns (address promise_) {
        if (latestAsyncPromise == address(0)) revert("Forwarder: no async promise found");
        promise_ = IPromise(latestAsyncPromise).then(selector_, data_);
        latestAsyncPromise = address(0);
    }

    /// @notice Returns the on-chain address associated with this forwarder.
    /// @return The on-chain address.
    function getOnChainAddress() external view returns (address) {
        return onChainAddress;
    }

    /// @notice Returns the chain id
    /// @return chain id
    function getChainSlug() external view returns (uint32) {
        return chainSlug;
    }

    /// @notice Fallback function to process the contract calls to onChainAddress
    /// @dev It queues the calls in the auction house and deploys the promise contract
    fallback() external payable {
        // Retrieve the auction house address from the address resolver.
        if (address(deliveryHelper__()) == address(0)) {
            revert("Forwarder: deliveryHelper not found");
        }

        bool isAsyncModifierSet = IAppGateway(msg.sender).isAsyncModifierSet();
        if (!isAsyncModifierSet) revert AsyncModifierNotUsed();

        // Deploy a new async promise contract.
        latestAsyncPromise = addressResolver__.deployAsyncPromiseContract(msg.sender);

        // Determine if the call is a read or write operation.
        (
            Read isReadCall,
            Parallel isParallelCall,
            WriteFinality writeFinality,
            uint256 readAt,
            uint256 gasLimit,
            uint256 value,
            bytes32 sbType
        ) = IAppGateway(msg.sender).getOverrideParams();
        address switchboard = watcherPrecompileConfig().switchboards(chainSlug, sbType);

        // Queue the call in the auction house.
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

    receive() external payable {}
}
