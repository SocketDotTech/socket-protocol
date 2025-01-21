// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "../interfaces/IAddressResolver.sol";
import "../interfaces/IDeliveryHelper.sol";
import "../interfaces/IWatcherPrecompile.sol";

/// @title AddressResolverUtil
/// @notice Utility contract for resolving system contract addresses
/// @dev Provides access control and address resolution functionality for the system
abstract contract AddressResolverUtil {
    /// @notice The address resolver contract reference
    /// @dev Used to look up system contract addresses
    IAddressResolver public addressResolver__;

    /// @notice Error thrown when an invalid address attempts to call the Payload Delivery only function
    error OnlyPayloadDelivery();
    /// @notice Error thrown when an invalid address attempts to call the Watcher only function
    error OnlyWatcherPrecompile();

    /// @notice Restricts function access to the auction house contract
    /// @dev Validates that msg.sender matches the registered auction house address
    modifier onlyDeliveryHelper() {
        if (msg.sender != addressResolver__.deliveryHelper()) {
            revert OnlyPayloadDelivery();
        }

        _;
    }

    /// @notice Restricts function access to the watcher precompile contract
    /// @dev Validates that msg.sender matches the registered watcher precompile address
    modifier onlyWatcherPrecompile() {
        if (msg.sender != address(addressResolver__.watcherPrecompile__())) {
            revert OnlyWatcherPrecompile();
        }

        _;
    }

    /// @notice Gets the auction house contract interface
    /// @return IDeliveryHelper interface of the registered auction house
    /// @dev Resolves and returns the auction house contract for interaction
    function deliveryHelper() public view returns (IDeliveryHelper) {
        return IDeliveryHelper(addressResolver__.deliveryHelper());
    }

    /// @notice Gets the watcher precompile contract interface
    /// @return IWatcherPrecompile interface of the registered watcher precompile
    /// @dev Resolves and returns the watcher precompile contract for interaction
    function watcherPrecompile__() public view returns (IWatcherPrecompile) {
        return IWatcherPrecompile(addressResolver__.watcherPrecompile__());
    }

    /// @notice Internal function to set the address resolver
    /// @param _addressResolver The address of the resolver contract
    /// @dev Should be called in the initialization of inheriting contracts
    function _setAddressResolver(address _addressResolver) internal {
        addressResolver__ = IAddressResolver(_addressResolver);
    }

    function _getCoreAppGateway(address appGateway_) internal view returns (address appGateway) {
        appGateway = addressResolver__.contractsToGateways(appGateway_);
        if (appGateway == address(0)) appGateway = appGateway_;
    }

    // for proxy contracts
    uint256[49] __gap_resolver_util;
}
