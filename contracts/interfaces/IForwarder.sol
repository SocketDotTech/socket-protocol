// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/// @title IForwarder
/// @notice Interface for the Forwarder contract that allows contracts to call async promises
interface IForwarder {
    /// @notice Returns the on-chain address of the contract being referenced
    /// @return The on-chain address
    function getOnChainAddress() external view returns (address);

    /// @notice Returns the chain slug of the on chain contract
    /// @return The chain slug
    function getChainSlug() external view returns (uint32);
}
