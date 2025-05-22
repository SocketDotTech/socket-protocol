// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./interfaces/IAddressResolver.sol";
import "./interfaces/IMiddleware.sol";
import "./interfaces/IAppGateway.sol";
import "./interfaces/IForwarder.sol";
import {AddressResolverUtil} from "./AddressResolverUtil.sol";
import {AsyncModifierNotUsed, WatcherNotSet} from "../utils/common/Errors.sol";
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
        if (address(watcher__()) == address(0)) {
            revert WatcherNotSet();
        }

        // validates if the async modifier is set
        bool isAsyncModifierSet = IAppGateway(msg.sender).isAsyncModifierSet();
        if (!isAsyncModifierSet) revert AsyncModifierNotUsed();

        // fetch the override params from app gateway
        (OverrideParams overrideParams, bytes32 sbType) = IAppGateway(msg.sender)
            .getOverrideParams();

        // Queue the call in the middleware.
        watcher__().queue(
            QueuePayloadParams({
                overrideParams: overrideParams,
                transaction: Transaction({
                    chainSlug: chainSlug,
                    target: onChainAddress,
                    payload: msg.data
                }),
                asyncPromise: address(0),
                switchboardType: sbType
            }),
            latestPromiseCaller
        );
    }
}
