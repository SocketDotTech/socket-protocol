// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IAddressResolver.sol";
import "../interfaces/IWatcher.sol";
import "../interfaces/IFeesManager.sol";

/// @title AddressResolverUtil
/// @notice Utility contract for resolving system contract addresses
/// @dev Provides access control and address resolution functionality for the system
abstract contract AddressResolverBase {
    /// @notice The address resolver contract reference
    /// @dev Used to look up system contract addresses
    // slot 0
    IAddressResolver public addressResolver__;

    // slots 1-50 reserved for future use
    uint256[50] __gap_resolver_util;

    /// @notice Error thrown when an invalid address attempts to call the Watcher only function
    error onlyWatcherAllowed();

    /// @notice Restricts function access to the watcher precompile contract
    /// @dev Validates that msg.sender matches the registered watcher precompile address
    modifier onlyWatcher() {
        if (msg.sender != address(addressResolver__.watcherPrecompile__())) {
            revert onlyWatcherAllowed();
        }

        _;
    }

    /// @notice Gets the watcher precompile contract interface
    /// @return IWatcher interface of the registered watcher precompile
    /// @dev Resolves and returns the watcher precompile contract for interaction
    function watcherPrecompile__() public view returns (IWatcher) {
        return addressResolver__.watcherPrecompile__();
    }

    /// @notice Gets the watcher precompile contract interface
    /// @return IWatcher interface of the registered watcher precompile
    /// @dev Resolves and returns the watcher precompile contract for interaction
    function feesManager__() public view returns (IFeesManager) {
        return addressResolver__.feesManager__();
    }

    /// @notice Gets the async deployer contract interface
    /// @return IAsyncDeployer interface of the registered async deployer
    /// @dev Resolves and returns the async deployer contract for interaction
    function asyncDeployer__() public view returns (IAsyncDeployer) {
        return addressResolver__.asyncDeployer__();
    }

    /// @notice Internal function to set the address resolver
    /// @param _addressResolver The address of the resolver contract
    /// @dev Should be called in the initialization of inheriting contracts
    function _setAddressResolver(address _addressResolver) internal {
        addressResolver__ = IAddressResolver(_addressResolver);
    }
}
