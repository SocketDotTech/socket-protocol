// SPDX-License-Identifier: Unlicense
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

    /// @notice Gets the address of the delivery helper contract
    /// @return IDeliveryHelper The delivery helper interface
    /// @dev Returns interface pointing to zero address if not configured
    function deliveryHelper() external view returns (address);

    /// @notice Gets the address of the fees manager contract
    /// @return IFeesManager The fees manager interface
    /// @dev Returns interface pointing to zero address if not configured
    function feesManager() external view returns (address);

    /// @notice Gets the address of the default auction manager contract
    /// @return IAuctionManager The auction manager interface
    /// @dev Returns interface pointing to zero address if not configured
    function defaultAuctionManager() external view returns (address);

    /// @notice Gets the watcher precompile contract interface
    /// @return IWatcherPrecompile The watcher precompile interface
    /// @dev Returns interface pointing to zero address if not configured
    function watcherPrecompile__() external view returns (IWatcherPrecompile);

    /// @notice Maps contract addresses to their corresponding gateway addresses
    /// @param contractAddress_ The address of the contract to lookup
    /// @return The gateway address associated with the contract
    function contractsToGateways(address contractAddress_) external view returns (address);

    /// @notice Gets the list of all deployed async promise contracts
    /// @return Array of async promise contract addresses
    function getPromises() external view returns (address[] memory);

    // State-changing functions
    /// @notice Sets the auction house contract address
    /// @param deliveryHelper_ The new delivery helper contract address
    /// @dev Only callable by contract owner
    function setDeliveryHelper(address deliveryHelper_) external;

    /// @notice Sets the watcher precompile contract address
    /// @param watcherPrecompile_ The new watcher precompile contract address
    /// @dev Only callable by contract owner
    function setWatcherPrecompile(address watcherPrecompile_) external;

    /// @notice Maps a contract address to its gateway
    /// @param contractAddress_ The contract address to map
    /// @dev Creates bidirectional mapping between contract and gateway
    function setContractsToGateways(address contractAddress_) external;

    /// @notice Clears the list of deployed async promise contracts
    /// @dev Only callable by contract owner
    function clearPromises() external;

    /// @notice Deploys a new forwarder contract if not already deployed
    /// @param chainContractAddress_ The contract address on the destination chain
    /// @param chainSlug_ The identifier of the destination chain
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
