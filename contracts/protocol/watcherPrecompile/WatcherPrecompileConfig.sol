// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./WatcherPrecompileLimits.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import "solady/utils/Initializable.sol";
import "../../interfaces/IWatcherPrecompileConfig.sol";
import "./WatcherPrecompileUtils.sol";
/// @title WatcherPrecompileConfig
/// @notice Configuration contract for the Watcher Precompile system
/// @dev Handles the mapping between networks, plugs, and app gateways for payload execution
contract WatcherPrecompileConfig is
    IWatcherPrecompileConfig,
    Initializable,
    AccessControl,
    AddressResolverUtil,
    WatcherPrecompileUtils
{
    // slot 52: evmxSlug
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;

    // slot 55: _plugConfigs
    /// @notice Maps network and plug to their configuration
    /// @dev chainSlug => plug => PlugConfig
    mapping(uint32 => mapping(address => PlugConfig)) internal _plugConfigs;

    // slot 56: switchboards
    /// @notice Maps chain slug to their associated switchboard
    /// @dev chainSlug => sb type => switchboard address
    mapping(uint32 => mapping(bytes32 => address)) public switchboards;

    // slot 57: sockets
    /// @notice Maps chain slug to their associated socket
    /// @dev chainSlug => socket address
    mapping(uint32 => address) public sockets;

    // slot 58: contractFactoryPlug
    /// @notice Maps chain slug to their associated contract factory plug
    /// @dev chainSlug => contract factory plug address
    mapping(uint32 => address) public contractFactoryPlug;

    // slot 59: feesPlug
    /// @notice Maps chain slug to their associated fees plug
    /// @dev chainSlug => fees plug address
    mapping(uint32 => address) public feesPlug;

    // slot 60: isNonceUsed
    /// @notice Maps nonce to whether it has been used
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // slot 61: isValidPlug
    // appGateway => chainSlug => plug => isValid
    mapping(address => mapping(uint32 => mapping(address => bool))) public isValidPlug;

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

    /// @notice Emitted when contracts are set for a network
    /// @param chainSlug The identifier of the network
    /// @param socket The address of the socket
    /// @param contractFactoryPlug The address of the contract factory plug
    /// @param feesPlug The address of the fees plug
    event OnChainContractSet(
        uint32 chainSlug,
        address socket,
        address contractFactoryPlug,
        address feesPlug
    );

    error InvalidGateway();
    error InvalidSwitchboard();
    error NonceUsed();
    error InvalidWatcherSignature();

    /// @notice Initial initialization (version 1)
    function initialize(
        address owner_,
        address addressResolver_,
        uint32 evmxSlug_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);

        evmxSlug = evmxSlug_;
    }

    /// @notice Emitted when a plug is set as valid for an app gateway

    /// @notice Configures app gateways with their respective plugs and switchboards
    /// @param configs_ Array of configurations containing app gateway, network, plug, and switchboard details
    /// @dev Only callable by the contract owner
    /// @dev This helps in verifying that plugs are called by respective app gateways
    function setAppGateways(
        AppGatewayConfig[] calldata configs_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.setAppGateways.selector, configs_),
            signatureNonce_,
            signature_
        );

        for (uint256 i = 0; i < configs_.length; i++) {
            // Store the plug configuration for this network and plug
            _plugConfigs[configs_[i].chainSlug][configs_[i].plug] = PlugConfig({
                appGatewayId: configs_[i].appGatewayId,
                switchboard: configs_[i].switchboard
            });

            emit PlugAdded(configs_[i].appGatewayId, configs_[i].chainSlug, configs_[i].plug);
        }
    }

    /// @notice Sets the switchboard for a network
    /// @param chainSlug_ The identifier of the network
    function setOnChainContracts(
        uint32 chainSlug_,
        address socket_,
        address contractFactoryPlug_,
        address feesPlug_
    ) external onlyOwner {
        sockets[chainSlug_] = socket_;
        contractFactoryPlug[chainSlug_] = contractFactoryPlug_;
        feesPlug[chainSlug_] = feesPlug_;

        emit OnChainContractSet(chainSlug_, socket_, contractFactoryPlug_, feesPlug_);
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
    function setIsValidPlug(uint32 chainSlug_, address plug_, bool isValid_) external {
        isValidPlug[msg.sender][chainSlug_][plug_] = isValid_;
    }

    /// @notice Retrieves the configuration for a specific plug on a network
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

    function verifyConnections(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        address switchboard_
    ) external view {
        // todo: revisit this
        // if target is contractFactoryPlug, return
        if (target_ == contractFactoryPlug[chainSlug_]) return;

        (bytes32 appGatewayId, address switchboard) = getPlugConfigs(chainSlug_, target_);
        if (appGatewayId != _encodeAppGatewayId(appGateway_)) revert InvalidGateway();
        if (switchboard != switchboard_) revert InvalidSwitchboard();
    }

    function _isWatcherSignatureValid(
        bytes memory digest_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) internal {
        if (isNonceUsed[signatureNonce_]) revert NonceUsed();
        isNonceUsed[signatureNonce_] = true;

        bytes32 digest = keccak256(abi.encode(address(this), evmxSlug, signatureNonce_, digest_));
        digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        // recovered signer is checked for the valid roles later
        address signer = ECDSA.recover(digest, signature_);
        if (signer != owner()) revert InvalidWatcherSignature();
    }
}
