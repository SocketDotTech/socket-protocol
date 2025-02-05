// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IAppDeployer.sol";

/// @title IMultiChainAppDeployer
/// @notice Interface for the multi-chain app deployer
interface IMultiChainAppDeployer is IAppDeployer {
    /// @notice deploy contracts to multiple chains
    function deployMultiChainContracts(uint32[] memory chainSlugs_) external;
}
