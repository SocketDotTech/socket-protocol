// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {IsPlug} from "../../utils/common/Structs.sol";

/// @title IDeployForwarder
/// @notice Interface for the DeployForwarder contract responsible for handling deployment requests
interface IDeployForwarder {
    /// @notice Returns the current salt counter used for contract deployments
    /// @return The salt counter
    function saltCounter() external view returns (uint256);

    /// @notice Returns the deployer switchboard type
    /// @return The deployer switchboard type
    function deployerSwitchboardType() external view returns (bytes32);

    /// @notice Deploys a contract
    /// @param isPlug_ Whether the contract is a plug
    /// @param chainSlug_ The chain slug
    /// @param initCallData_ The initialization calldata for the contract
    /// @param payload_ The payload for the contract
    function deploy(
        IsPlug isPlug_,
        uint32 chainSlug_,
        bytes memory initCallData_,
        bytes memory payload_
    ) external;
}
