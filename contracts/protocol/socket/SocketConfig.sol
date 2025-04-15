// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/ISocket.sol";
import "../../interfaces/ISwitchboard.sol";
import {IPlug} from "../../interfaces/IPlug.sol";

import "../utils/AccessControl.sol";
import {GOVERNANCE_ROLE, RESCUE_ROLE} from "../utils/common/AccessRoles.sol";
import {PlugConfig, SwitchboardStatus, ExecutionStatus} from "../utils/common/Structs.sol";
import {PlugDisconnected, InvalidAppGateway, InvalidTransmitter} from "../utils/common/Errors.sol";
import {MAX_COPY_BYTES} from "../utils/common/Constants.sol";

/**
 * @title SocketConfig
 * @notice An abstract contract for configuring socket connections for plugs,
 * manages plug configs and switchboard registrations
 * @dev This contract is meant to be inherited by other contracts that require socket configuration functionality
 */
abstract contract SocketConfig is ISocket, AccessControl {
    // @notice mapping of switchboard address to its status, helps socket to block invalid switchboards
    mapping(address => SwitchboardStatus) public isValidSwitchboard;

    // @notice mapping of plug address to its config
    mapping(address => PlugConfig) internal _plugConfigs;

    // @notice max copy bytes for socket
    uint16 public maxCopyBytes = 2048; // 2KB

    // @notice error triggered when a connection is invalid
    error InvalidConnection();
    // @notice error triggered when a switchboard is invalid
    error InvalidSwitchboard();
    // @notice error triggered when a switchboard already exists
    error SwitchboardExists();
    // @notice error triggered when a switchboard already exists or is disabled
    error SwitchboardExistsOrDisabled();

    // @notice event triggered when a new switchboard is added
    event SwitchboardAdded(address switchboard);
    // @notice event triggered when a switchboard is disabled
    event SwitchboardDisabled(address switchboard);

    // @notice function to register a switchboard
    // @dev only callable by switchboards
    function registerSwitchboard() external {
        if (isValidSwitchboard[msg.sender] != SwitchboardStatus.NOT_REGISTERED)
            revert SwitchboardExistsOrDisabled();

        isValidSwitchboard[msg.sender] = SwitchboardStatus.REGISTERED;
        emit SwitchboardAdded(msg.sender);
    }

    // @notice function to disable a switchboard
    // @dev only callable by governance role
    function disableSwitchboard() external onlyRole(GOVERNANCE_ROLE) {
        isValidSwitchboard[msg.sender] = SwitchboardStatus.DISABLED;
        emit SwitchboardDisabled(msg.sender);
    }

    // @notice function to connect a plug to a socket
    // @dev only callable by plugs (msg.sender)
    // @param appGateway_ address of app gateway on sibling chain
    // @param switchboard_ address of switchboard on sibling chain
    function connect(address appGateway_, address switchboard_) external override {
        if (isValidSwitchboard[switchboard_] != SwitchboardStatus.REGISTERED)
            revert InvalidSwitchboard();

        PlugConfig storage _plugConfig = _plugConfigs[msg.sender];

        _plugConfig.appGateway = appGateway_;
        _plugConfig.switchboard = switchboard_;

        emit PlugConnected(msg.sender, appGateway_, switchboard_);
    }

    // @notice function to set the max copy bytes for socket
    // @dev only callable by governance role
    // @param maxCopyBytes_ max copy bytes for socket
    function setMaxCopyBytes(uint16 maxCopyBytes_) external onlyRole(GOVERNANCE_ROLE) {
        maxCopyBytes = maxCopyBytes_;
    }

    // @notice function to get the config for a plug
    // @param plugAddress_ address of plug present at current chain
    // @return appGateway address of app gateway on sibling chain
    // @return switchboard address of switchboard on sibling chain
    function getPlugConfig(
        address plugAddress_
    ) external view returns (address appGateway, address switchboard) {
        PlugConfig memory _plugConfig = _plugConfigs[plugAddress_];
        return (_plugConfig.appGateway, _plugConfig.switchboard);
    }
}
