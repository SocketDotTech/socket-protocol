// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "../../interfaces/IAddressResolver.sol";
import "../../interfaces/IMiddleware.sol";
import "../../interfaces/IWatcherPrecompile.sol";
import "../../interfaces/IWatcherPrecompileConfig.sol";
import "../../interfaces/IWatcherPrecompileLimits.sol";

/// @title AddressResolverUtil
/// @notice Utility contract for resolving system contract addresses
/// @dev Provides access control and address resolution functionality for the system
abstract contract AddressResolverUtil {
    /// @notice The address resolver contract reference
    /// @dev Used to look up system contract addresses
    // slot 0
    IAddressResolver public addressResolver__;

    // slots 1-50 reserved for future use
    uint256[50] __gap_resolver_util;

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
    /// @return IMiddleware interface of the registered auction house
    /// @dev Resolves and returns the auction house contract for interaction
    function deliveryHelper__() public view returns (IMiddleware) {
        return IMiddleware(addressResolver__.deliveryHelper());
    }

    /// @notice Gets the watcher precompile contract interface
    /// @return IWatcherPrecompile interface of the registered watcher precompile
    /// @dev Resolves and returns the watcher precompile contract for interaction
    function watcherPrecompile__() public view returns (IWatcherPrecompile) {
        return addressResolver__.watcherPrecompile__();
    }

    /// @notice Gets the watcher precompile config contract interface
    /// @return IWatcherPrecompileConfig interface of the registered watcher precompile config
    /// @dev Resolves and returns the watcher precompile config contract for interaction
    function watcherPrecompileConfig() public view returns (IWatcherPrecompileConfig) {
        return addressResolver__.watcherPrecompile__().watcherPrecompileConfig__();
    }

    /// @notice Gets the watcher precompile limits contract interface
    /// @return IWatcherPrecompileLimits interface of the registered watcher precompile limits
    /// @dev Resolves and returns the watcher precompile limits contract for interaction
    function watcherPrecompileLimits() public view returns (IWatcherPrecompileLimits) {
        return addressResolver__.watcherPrecompile__().watcherPrecompileLimits__();
    }

    /// @notice Internal function to set the address resolver
    /// @param _addressResolver The address of the resolver contract
    /// @dev Should be called in the initialization of inheriting contracts
    function _setAddressResolver(address _addressResolver) internal {
        addressResolver__ = IAddressResolver(_addressResolver);
    }

    function _getCoreAppGateway(
        address originAppGateway_
    ) internal view returns (address appGateway) {
        appGateway = addressResolver__.contractsToGateways(originAppGateway_);
        if (appGateway == address(0)) appGateway = originAppGateway_;
    }
}
