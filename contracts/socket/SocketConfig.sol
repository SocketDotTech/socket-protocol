// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/ISocket.sol";
import "../interfaces/ISwitchboard.sol";
import {IPlug} from "../interfaces/IPlug.sol";

import "../utils/AccessControl.sol";
import {GOVERNANCE_ROLE, RESCUE_ROLE, SWITCHBOARD_DISABLER_ROLE} from "../utils/common/AccessRoles.sol";
import {CallType, PlugConfig, SwitchboardStatus, ExecutionStatus} from "../utils/common/Structs.sol";
import {PlugNotFound, InvalidAppGateway, InvalidTransmitter} from "../utils/common/Errors.sol";
import "../interfaces/ISocketFeeManager.sol";
import {MAX_COPY_BYTES} from "../utils/common/Constants.sol";

/**
 * @title SocketConfig
 * @notice An abstract contract for configuring socket connections for plugs,
 * manages plug configs and switchboard registrations
 * @dev This contract is meant to be inherited by other contracts that require socket configuration functionality
 */
abstract contract SocketConfig is ISocket, AccessControl {
    // socket fee manager
    ISocketFeeManager public socketFeeManager;

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
    // @notice event triggered when a switchboard is enabled
    event SwitchboardEnabled(address switchboard);
    event SocketFeeManagerUpdated(address oldSocketFeeManager, address newSocketFeeManager);

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
    function disableSwitchboard() external onlyRole(SWITCHBOARD_DISABLER_ROLE) {
        isValidSwitchboard[msg.sender] = SwitchboardStatus.DISABLED;
        emit SwitchboardDisabled(msg.sender);
    }

    // @notice function to enable a switchboard
    // @dev only callable by governance role
    function enableSwitchboard() external onlyRole(GOVERNANCE_ROLE) {
        isValidSwitchboard[msg.sender] = SwitchboardStatus.REGISTERED;
        emit SwitchboardEnabled(msg.sender);
    }

    function setSocketFeeManager(address socketFeeManager_) external onlyRole(GOVERNANCE_ROLE) {
        emit SocketFeeManagerUpdated(address(socketFeeManager), socketFeeManager_);
        socketFeeManager = ISocketFeeManager(socketFeeManager_);
    }

    /**
     * @notice connects Plug to Socket and sets the config for given `siblingChainSlug_`
     */
    function connect(bytes32 appGatewayId_, address switchboard_) external override {
        if (isValidSwitchboard[switchboard_] != SwitchboardStatus.REGISTERED)
            revert InvalidSwitchboard();

        PlugConfig storage _plugConfig = _plugConfigs[msg.sender];

        _plugConfig.appGatewayId = appGatewayId_;
        _plugConfig.switchboard = switchboard_;

        emit PlugConnected(msg.sender, appGatewayId_, switchboard_);
    }

    // @notice function to set the max copy bytes for socket
    // @dev only callable by governance role
    // @param maxCopyBytes_ max copy bytes for socket
    function setMaxCopyBytes(uint16 maxCopyBytes_) external onlyRole(GOVERNANCE_ROLE) {
        maxCopyBytes = maxCopyBytes_;
    }

    /**
     * @notice returns the config for given `plugAddress_`
     * @param plugAddress_ address of plug present at current chain
     * @return appGatewayId The app gateway id
     * @return switchboard The switchboard address
     */
    function getPlugConfig(
        address plugAddress_
    ) external view returns (bytes32 appGatewayId, address switchboard) {
        PlugConfig memory _plugConfig = _plugConfigs[plugAddress_];
        return (_plugConfig.appGatewayId, _plugConfig.switchboard);
    }
}
