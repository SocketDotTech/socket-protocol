// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;
import "./IWatcherPrecompile.sol";

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

    /// @notice Gets the address of the delivery helper contract
    /// @return The delivery helper contract address
    /// @dev Returns zero address if not configured
    function deliveryHelper() external view returns (address);

    /// @notice Gets the address of the fees manager contract
    /// @return The fees manager contract address
    /// @dev Returns zero address if not configured
    function feesManager() external view returns (address);

    /// @notice Gets the address of the default auction manager contract
    /// @return The auction manager contract address
    /// @dev Returns zero address if not configured
    function defaultAuctionManager() external view returns (address);

    /// @notice Gets the watcher precompile contract instance
    /// @return The watcher precompile contract instance
    /// @dev Returns instance with zero address if not configured
    function watcherPrecompile__() external view returns (IWatcherPrecompile);

    /// @notice Maps contract addresses to their corresponding gateway addresses
    /// @param contractAddress_ The address of the contract to lookup
    /// @return The gateway address associated with the contract
    function contractsToGateways(address contractAddress_) external view returns (address);

    /// @notice Gets the list of all deployed async promise contracts
    /// @return Array of async promise contract addresses
    function getPromises() external view returns (address[] memory);

    /// @notice Maps a contract address to its gateway
    /// @param contractAddress_ The contract address to map
    /// @dev Creates bidirectional mapping between contract and gateway
    function setContractsToGateways(address contractAddress_) external;

    /// @notice Clears the list of deployed async promise contracts array
    function clearPromises() external;

    /// @notice Deploys or returns the address of a new forwarder contract if not already deployed
    /// @param chainContractAddress_ The contract address on the `chainSlug_`
    /// @param chainSlug_ The identifier of the chain
    /// @return The address of the newly deployed forwarder contract
    function getOrDeployForwarderContract(
        address appGateway_,
        address chainContractAddress_,
        uint32 chainSlug_
    ) external returns (address);

    /// @notice Deploys a new async promise contract
    /// @param invoker_ The address that can invoke/execute the promise
    /// @return The address of the newly deployed async promise contract
    function deployAsyncPromiseContract(address invoker_) external returns (address);
}
