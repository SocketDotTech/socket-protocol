// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;
import "./IWatcher.sol";

/// @title IAddressResolver
/// @notice Interface for resolving system contract addresses
/// @dev Provides address lookup functionality for core system components
interface IAddressResolver {
    /// @notice Emitted when a new address is set in the resolver
    /// @param name The identifier of the contract
    /// @param oldAddress The previous address of the contract
    /// @param newAddress The new address of the contract
    event AddressSet(bytes32 indexed name, address oldAddress, address newAddress);

    /// @notice Emitted when a new plug is added to the resolver
    /// @param appGateway The address of the app gateway
    /// @param chainSlug The chain slug
    /// @param plug The address of the plug
    event PlugAdded(address appGateway, uint32 chainSlug, address plug);

    /// @notice Emitted when a new forwarder is deployed
    /// @param newForwarder The address of the new forwarder
    /// @param salt The salt used to deploy the forwarder
    event ForwarderDeployed(address newForwarder, bytes32 salt);

    /// @notice Emitted when a new async promise is deployed
    /// @param newAsyncPromise The address of the new async promise
    /// @param salt The salt used to deploy the async promise
    event AsyncPromiseDeployed(address newAsyncPromise, bytes32 salt);

    /// @notice Emitted when an implementation is updated
    /// @param contractName The name of the contract
    /// @param newImplementation The new implementation address
    event ImplementationUpdated(string contractName, address newImplementation);

    // any other address resolution
    function getAddress(bytes32 name) external view returns (address);

    function setAddress(bytes32 name, address addr) external;

    // System component addresses
    function getWatcherPrecompile() external view returns (address);

    function getFeesManager() external view returns (address);

    function getDefaultAuctionManager() external view returns (address);

    function getAsyncDeployer() external view returns (address);

    function setFeesManager(address feesManager_) external;

    function setDefaultAuctionManager(address defaultAuctionManager_) external;

    function setWatcherPrecompile(address watcherPrecompile_) external;

    function setAsyncDeployer(address asyncDeployer_) external;
}
