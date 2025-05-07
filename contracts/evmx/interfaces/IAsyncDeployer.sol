// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/// @title IAsyncDeployer
/// @notice Interface for deploying Forwarder and AsyncPromise contracts
/// @dev Provides address lookup functionality for core system components
interface IAsyncDeployer {
    // Forwarder Management
    function getOrDeployForwarderContract(
        address appGateway_,
        address chainContractAddress_,
        uint32 chainSlug_
    ) external returns (address);

    function getForwarderAddress(
        address chainContractAddress_,
        uint32 chainSlug_
    ) external view returns (address);

    function setForwarderImplementation(address implementation_) external;

    // Async Promise Management
    function deployAsyncPromiseContract(address invoker_) external returns (address);

    function getAsyncPromiseAddress(address invoker_) external view returns (address);

    function setAsyncPromiseImplementation(address implementation_) external;
}
