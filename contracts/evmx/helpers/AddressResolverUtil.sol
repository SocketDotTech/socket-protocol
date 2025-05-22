// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IAddressResolver.sol";
import "../interfaces/IWatcher.sol";
import "../interfaces/IFeesManager.sol";
import "../interfaces/IAsyncDeployer.sol";
import {OnlyWatcherAllowed} from "../../utils/common/Errors.sol";

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

    /// @notice Restricts function access to the watcher precompile contract
    /// @dev Validates that msg.sender matches the registered watcher precompile address
    modifier onlyWatcher() {
        if (msg.sender != address(addressResolver__.watcher__())) {
            revert OnlyWatcherAllowed();
        }

        _;
    }

    /// @notice Gets the watcher precompile contract interface
    /// @return IWatcher interface of the registered watcher precompile
    /// @dev Resolves and returns the watcher precompile contract for interaction
    function watcher__() public view returns (IWatcher) {
        return addressResolver__.watcher__();
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

    /// @notice Gets the deploy forwarder contract interface
    /// @return IDeployForwarder interface of the registered deploy forwarder
    /// @dev Resolves and returns the deploy forwarder contract for interaction
    function deployForwarder__() public view returns (IDeployForwarder) {
        return addressResolver__.deployForwarder__();
    }

    /// @notice Internal function to set the address resolver
    /// @param _addressResolver The address of the resolver contract
    /// @dev Should be called in the initialization of inheriting contracts
    function _setAddressResolver(address _addressResolver) internal {
        addressResolver__ = IAddressResolver(_addressResolver);
    }

    function getCoreAppGateway(address appGateway_) internal view returns (address) {
        return addressResolver__.watcher__().configurations__().getCoreAppGateway(appGateway_);
    }
}
