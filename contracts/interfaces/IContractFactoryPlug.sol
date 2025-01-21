// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title IContractFactory
/// @notice Interface for contract factory functionality
interface IContractFactoryPlug {
    /// @notice Deploys a contract using CREATE2
    /// @param creationCode_ The contract creation code
    /// @param salt_ The salt value for CREATE2
    /// @return address The deployed contract address
    function deployContract(
        bytes memory creationCode_,
        bytes32 salt_,
        address appGateway_,
        address switchboard_
    ) external returns (address);

    /// @notice Gets the deterministic address for a contract deployment
    /// @param creationCode_ The contract creation code
    /// @param salt_ The salt value
    /// @return address_ The predicted contract address
    function getAddress(bytes memory creationCode_, uint256 salt_) external view returns (address);
}
