// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/ISocket.sol";
import "../../interfaces/ISwitchboard.sol";
import "../utils/AccessControl.sol";
import {GOVERNANCE_ROLE, RESCUE_ROLE} from "../utils/common/AccessRoles.sol";

/**
 * @title SocketConfig
 * @notice An abstract contract for configuring socket connections for plugs between different chains,
 * manages plug configs and switchboard registrations
 * @dev This contract is meant to be inherited by other contracts that require socket configuration functionality
 */
abstract contract SocketConfig is ISocket, AccessControl {
    /**
     * @dev Struct to store the configuration for a plug connection
     */
    struct PlugConfig {
        // address of the sibling plug on the remote chain
        address appGateway;
        // switchboard instance for the plug connection
        ISwitchboard switchboard__;
    }

    enum SwitchboardStatus {
        NOT_REGISTERED,
        REGISTERED,
        DISABLED
    }

    // Error triggered when a switchboard already exists
    mapping(address => SwitchboardStatus) public isValidSwitchboard;

    // plug => (appGateway, switchboard__)
    mapping(address => PlugConfig) internal _plugConfigs;

    error SwitchboardExists();
    // Error triggered when a connection is invalid
    error InvalidConnection();
    error InvalidSwitchboard();
    error SwitchboardExistsOrDisabled();

    // Event triggered when a new switchboard is added
    event SwitchboardAdded(address switchboard);
    event SwitchboardDisabled(address switchboard);

    function registerSwitchboard() external {
        if (isValidSwitchboard[msg.sender] != SwitchboardStatus.NOT_REGISTERED)
            revert SwitchboardExistsOrDisabled();

        isValidSwitchboard[msg.sender] = SwitchboardStatus.REGISTERED;
        emit SwitchboardAdded(msg.sender);
    }

    function disableSwitchboard() external onlyRole(GOVERNANCE_ROLE) {
        isValidSwitchboard[msg.sender] = SwitchboardStatus.DISABLED;
        emit SwitchboardDisabled(msg.sender);
    }

    /**
     * @notice connects Plug to Socket and sets the config for given `siblingChainSlug_`
     */
    function connect(address appGateway_, address switchboard_) external override {
        if (isValidSwitchboard[switchboard_] != SwitchboardStatus.REGISTERED)
            revert InvalidSwitchboard();

        PlugConfig storage _plugConfig = _plugConfigs[msg.sender];

        _plugConfig.appGateway = appGateway_;
        _plugConfig.switchboard__ = ISwitchboard(switchboard_);

        emit PlugConnected(msg.sender, appGateway_, switchboard_);
    }

    /**
     * @notice returns the config for given `plugAddress_` and `siblingChainSlug_`
     * @param plugAddress_ address of plug present at current chain
     */
    function getPlugConfig(
        address plugAddress_
    ) external view returns (address appGateway, address switchboard__) {
        PlugConfig memory _plugConfig = _plugConfigs[plugAddress_];
        return (_plugConfig.appGateway, address(_plugConfig.switchboard__));
    }
}
