// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/**
 * @title IPlug
 * @notice Interface for a plug contract that executes the payload received from a source chain.
 */
interface IPlug {
    function connectSocket(address appGateway_, address socket_, address switchboard_) external;
}
