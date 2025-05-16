// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

//TODO:GW: remove this interface, we don't need it anymore
/// @title IForwarderSolana
/// @notice Interface for the ForwarderSolana contract that allows contracts to call async promises
interface IForwarderSolana {
    /// @notice Returns the on-chain address of the contract being referenced
    /// @return The on-chain address
    function getOnChainAddress() external view returns (bytes32);

    /// @notice Returns the chain slug of the on chain contract
    /// @return The chain slug
    function getChainSlug() external view returns (uint32);
}
