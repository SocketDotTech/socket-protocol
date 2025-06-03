// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import "../interfaces/IConfigurations.sol";
import {WatcherBase} from "./WatcherBase.sol";
import {encodeAppGatewayId} from "../../utils/common/IdUtils.sol";
import {InvalidGateway, InvalidSwitchboard} from "../../utils/common/Errors.sol";
import "solady/auth/Ownable.sol";
import "../../utils/RescueFundsLib.sol";

abstract contract ConfigurationsStorage is IConfigurations {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    /// @notice Maps network and plug to their configuration
    /// @dev chainSlug => plug => PlugConfig
    mapping(uint32 => mapping(address => PlugConfig)) internal _plugConfigs;

    // slot 51
    /// @notice Maps chain slug to their associated switchboard
    /// @dev chainSlug => sb type => switchboard address
    mapping(uint32 => mapping(bytes32 => address)) public switchboards;

    // slot 52
    /// @notice Maps chain slug to their associated socket
    /// @dev chainSlug => socket address
    mapping(uint32 => address) public sockets;

    // slot 53
    /// @notice Maps app gateway, chain slug, and plug to whether it is valid
    /// @dev appGateway => chainSlug => plug => isValid
    mapping(address => mapping(uint32 => mapping(address => bool))) public isValidPlug;

    // slots [54-103] reserved for gap
    uint256[50] _gap_after;

    // 1 slot reserved for watcher base
}

/// @title Configurations
/// @notice Configuration contract for the Watcher Precompile system
/// @dev Handles the mapping between networks, plugs, and app gateways for payload execution
contract Configurations is ConfigurationsStorage, Initializable, Ownable, WatcherBase {
    /// @notice Emitted when a new plug is configured for an app gateway
    /// @param appGatewayId The id of the app gateway
    /// @param chainSlug The identifier of the destination network
    /// @param plug The address of the plug
    event PlugAdded(bytes32 appGatewayId, uint32 chainSlug, address plug);

    /// @notice Emitted when a switchboard is set for a network
    /// @param chainSlug The identifier of the network
    /// @param sbType The type of switchboard
    /// @param switchboard The address of the switchboard
    event SwitchboardSet(uint32 chainSlug, bytes32 sbType, address switchboard);

    /// @notice Emitted when socket is set for a network
    /// @param chainSlug The identifier of the network
    /// @param socket The address of the socket
    event SocketSet(uint32 chainSlug, address socket);

    /// @notice Emitted when a valid plug is set for an app gateway
    /// @param appGateway The address of the app gateway
    /// @param chainSlug The identifier of the network
    /// @param plug The address of the plug
    /// @param isValid Whether the plug is valid
    event IsValidPlugSet(address appGateway, uint32 chainSlug, address plug, bool isValid);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    function initialize(address watcher_, address owner_) external reinitializer(1) {
        _initializeOwner(owner_);
        _initializeWatcher(watcher_);
    }

    /// @notice Configures app gateways with their respective plugs and switchboards
    /// @dev Only callable by the watcher
    /// @dev This helps in verifying that plugs are called by respective app gateways
    /// @param configs_ Array of configurations containing app gateway, network, plug, and switchboard details
    function setAppGatewayConfigs(AppGatewayConfig[] calldata configs_) external onlyWatcher {
        for (uint256 i = 0; i < configs_.length; i++) {
            // Store the plug configuration for this network and plug
            _plugConfigs[configs_[i].chainSlug][configs_[i].plug] = configs_[i].plugConfig;

            emit PlugAdded(
                configs_[i].plugConfig.appGatewayId,
                configs_[i].chainSlug,
                configs_[i].plug
            );
        }
    }

    /// @notice Sets the socket for a network
    /// @param chainSlug_ The identifier of the network
    /// @param socket_ The address of the socket
    function setSocket(uint32 chainSlug_, address socket_) external onlyOwner {
        sockets[chainSlug_] = socket_;
        emit SocketSet(chainSlug_, socket_);
    }

    /// @notice Sets the switchboard for a network
    /// @param chainSlug_ The identifier of the network
    /// @param sbType_ The type of switchboard, hash of a string
    /// @param switchboard_ The address of the switchboard
    function setSwitchboard(
        uint32 chainSlug_,
        bytes32 sbType_,
        address switchboard_
    ) external onlyOwner {
        switchboards[chainSlug_][sbType_] = switchboard_;
        emit SwitchboardSet(chainSlug_, sbType_, switchboard_);
    }

    /// @notice Sets the valid plugs for an app gateway
    /// @dev Only callable by the app gateway
    /// @dev This helps in verifying that app gateways are called by respective plugs
    /// @param chainSlug_ The identifier of the network
    /// @param plug_ The address of the plug
    /// @param isValid_ Whether the plug is valid
    function setIsValidPlug(
        bool isValid_,
        uint32 chainSlug_,
        address plug_,
        address appGateway_
    ) external onlyWatcher {
        isValidPlug[appGateway_][chainSlug_][plug_] = isValid_;
        emit IsValidPlugSet(appGateway_, chainSlug_, plug_, isValid_);
    }

    /// @notice Retrieves the configuration for a specific plug on a network
    /// @dev Returns zero addresses if configuration doesn't exist
    /// @param chainSlug_ The identifier of the network
    /// @param plug_ The address of the plug
    /// @return The app gateway id and switchboard address for the plug
    /// @dev Returns zero addresses if configuration doesn't exist
    function getPlugConfigs(
        uint32 chainSlug_,
        address plug_
    ) public view returns (bytes32, address) {
        return (
            _plugConfigs[chainSlug_][plug_].appGatewayId,
            _plugConfigs[chainSlug_][plug_].switchboard
        );
    }

    /// @notice Verifies the connections between the target, app gateway, and switchboard
    /// @dev Only callable by the watcher
    /// @param chainSlug_ The identifier of the network
    /// @param target_ The address of the target
    /// @param appGateway_ The address of the app gateway
    /// @param switchboardType_ The type of switchboard
    function verifyConnections(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        bytes32 switchboardType_
    ) external view {
        (bytes32 appGatewayId, address switchboard) = getPlugConfigs(chainSlug_, target_);
        if (appGatewayId != encodeAppGatewayId(appGateway_)) revert InvalidGateway();
        if (switchboard != switchboards[chainSlug_][switchboardType_]) revert InvalidSwitchboard();
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(address token_, address rescueTo_, uint256 amount_) external onlyWatcher {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
