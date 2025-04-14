// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/**
 * @title IPlug
 * @notice Interface for a plug contract that executes the payload received from a source chain.
 */
interface IPlug {
    /// @notice Initializes the socket
    /// @param appGateway_ The app gateway address
    /// @param socket_ The socket address
    /// @param switchboard_ The switchboard address
    function initSocket(address appGateway_, address socket_, address switchboard_) external;

    /// @notice Gets the overrides
    /// @return overrides_ The overrides
    function overrides() external view returns (bytes memory overrides_);
}
