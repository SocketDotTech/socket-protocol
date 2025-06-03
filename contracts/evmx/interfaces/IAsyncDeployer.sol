// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/// @title IAsyncDeployer
/// @notice Interface for deploying Forwarder and AsyncPromise contracts
/// @dev Provides address lookup functionality for core system components
interface IAsyncDeployer {
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

    // Forwarder Management
    function getOrDeployForwarderContract(
        address chainContractAddress_,
        uint32 chainSlug_
    ) external returns (address);

    function getForwarderAddress(
        address chainContractAddress_,
        uint32 chainSlug_
    ) external view returns (address);

    function setForwarderImplementation(address implementation_) external;

    // Async Promise Management
    function deployAsyncPromiseContract(
        address invoker_,
        uint40 requestCount_
    ) external returns (address);

    function getAsyncPromiseAddress(
        address invoker_,
        uint40 requestCount_
    ) external view returns (address);

    function setAsyncPromiseImplementation(address implementation_) external;
}
