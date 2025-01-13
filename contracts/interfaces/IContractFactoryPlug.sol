// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title IContractFactory
/// @notice Interface for contract factory functionality
interface IContractFactoryPlug {
    /// @notice Deploys a contract using CREATE2
    /// @param creationCode The contract creation code
    /// @param salt The salt value for CREATE2
    /// @return address The deployed contract address
    function deployContract(
        bytes memory creationCode,
        bytes32 salt,
        address appGateway_,
        address switchboard_
    ) external returns (address);

    /// @notice Gets the deterministic address for a contract deployment
    /// @param creationCode The contract creation code
    /// @param salt The salt value
    /// @return address The predicted contract address
    function getAddress(
        bytes memory creationCode,
        uint256 salt
    ) external view returns (address);
}
