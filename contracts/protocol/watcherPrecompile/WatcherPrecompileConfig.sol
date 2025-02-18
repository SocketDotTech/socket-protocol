// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./WatcherPrecompileLimits.sol";

/// @title WatcherPrecompileConfig
/// @notice Configuration contract for the Watcher Precompile system
/// @dev Handles the mapping between networks, plugs, and app gateways for payload execution
abstract contract WatcherPrecompileConfig is WatcherPrecompileLimits {
    /// @notice Maps network and plug to their configuration
    /// @dev chainSlug => plug => PlugConfig
    mapping(uint32 => mapping(address => PlugConfig)) internal _plugConfigs;

    /// @notice Maps app gateway to their associated plugs per network
    /// @dev appGateway => chainSlug => plug
    mapping(address => mapping(uint32 => address)) public appGatewayPlugs;

    /// @notice Maps chain slug to their associated switchboard
    /// @dev chainSlug => sb type => switchboard address
    mapping(uint32 => mapping(bytes32 => address)) public switchboards;

    // appGateway => chainSlug => plug => isValid
    mapping(address => mapping(uint32 => mapping(address => bool))) public isValidInboxCaller;

    /// @notice Emitted when a new plug is configured for an app gateway
    /// @param appGateway The address of the app gateway
    /// @param chainSlug The identifier of the destination network
    /// @param plug The address of the plug
    event PlugAdded(address appGateway, uint32 chainSlug, address plug);

    /// @notice Emitted when a switchboard is set for a network
    /// @param chainSlug The identifier of the network
    /// @param sbType The type of switchboard
    /// @param switchboard The address of the switchboard
    event SwitchboardSet(uint32 chainSlug, bytes32 sbType, address switchboard);

    /// @notice Configures app gateways with their respective plugs and switchboards
    /// @param configs_ Array of configurations containing app gateway, network, plug, and switchboard details
    /// @dev Only callable by the contract owner
    /// @dev This helps in verifying that plugs are called by respective app gateways
    function setAppGateways(AppGatewayConfig[] calldata configs_) external onlyOwner {
        for (uint256 i = 0; i < configs_.length; i++) {
            // Store the plug configuration for this network and plug
            _plugConfigs[configs_[i].chainSlug][configs_[i].plug] = PlugConfig({
                appGateway: configs_[i].appGateway,
                switchboard: configs_[i].switchboard
            });

            // Create reverse mapping from app gateway to plug for easy lookup
            appGatewayPlugs[configs_[i].appGateway][configs_[i].chainSlug] = configs_[i].plug;

            emit PlugAdded(configs_[i].appGateway, configs_[i].chainSlug, configs_[i].plug);
        }
    }

    /// @notice Sets the switchboard for a network
    /// @param chainSlug_ The identifier of the network
    /// @param switchboard_ The address of the switchboard
    function setSwitchboard(
        uint32 chainSlug_,
        bytes32 sbType_,
        address switchboard_
    ) external onlyOwner {
        switchboards[chainSlug_][sbType_] = switchboard_;
        emit SwitchboardSet(chainSlug_, sbType_, switchboard_);
    }

    // @dev app gateway can set the valid plugs for each chain slug
    function setIsValidInboxCaller(uint32 chainSlug_, address plug_, bool isValid_) external {
        isValidInboxCaller[msg.sender][chainSlug_][plug_] = isValid_;
    }

    /// @notice Retrieves the configuration for a specific plug on a network
    /// @param chainSlug_ The identifier of the network
    /// @param plug_ The address of the plug
    /// @return The app gateway address and switchboard address for the plug
    /// @dev Returns zero addresses if configuration doesn't exist
    function getPlugConfigs(
        uint32 chainSlug_,
        address plug_
    ) public view returns (address, address) {
        return (
            _plugConfigs[chainSlug_][plug_].appGateway,
            _plugConfigs[chainSlug_][plug_].switchboard
        );
    }

    uint256[49] __gap_config;
}
