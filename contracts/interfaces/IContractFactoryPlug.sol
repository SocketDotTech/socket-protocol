// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {IsPlug} from "../protocol/utils/common/Structs.sol";

/// @title IContractFactory
/// @notice Interface for contract factory functionality
interface IContractFactoryPlug {
    /// @notice Deploys a contract using CREATE2
    /// @param isPlug_ Whether the contract is a plug
    /// @param creationCode_ The contract creation code
    /// @param salt_ The salt value for CREATE2
    /// @return address The deployed contract address
    function deployContract(
        IsPlug isPlug_,
        bytes32 salt_,
        address appGateway_,
        address switchboard_,
        bytes memory creationCode_,
        bytes memory initCallData_
    ) external returns (address);

    /// @notice Gets the deterministic address for a contract deployment
    /// @param creationCode_ The contract creation code
    /// @param salt_ The salt value
    /// @return address_ The predicted contract address
    function getAddress(bytes memory creationCode_, uint256 salt_) external view returns (address);
}
