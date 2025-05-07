// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import "../interfaces/IConfigurations.sol";
import {AddressResolverUtil} from "../AddressResolverUtil.sol";
import {InvalidWatcherSignature, NonceUsed} from "../../utils/common/Errors.sol";
import "./core/WatcherIdUtils.sol";

/// @title Configurations
/// @notice Configuration contract for the Watcher Precompile system
/// @dev Handles the mapping between networks, plugs, and app gateways for payload execution
contract Configurations is IConfigurations, Initializable, Ownable, AddressResolverUtil {
    // slots 0-50 (51) reserved for addr resolver util

    // slots [51-100]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 101: evmxSlug
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;

    // slot 102: _plugConfigs
    /// @notice Maps network and plug to their configuration
    /// @dev chainSlug => plug => PlugConfig
    mapping(uint32 => mapping(address => PlugConfig)) internal _plugConfigs;

    // slot 103: switchboards
    /// @notice Maps chain slug to their associated switchboard
    /// @dev chainSlug => sb type => switchboard address
    mapping(uint32 => mapping(bytes32 => address)) public switchboards;

    // slot 104: sockets
    /// @notice Maps chain slug to their associated socket
    /// @dev chainSlug => socket address
    mapping(uint32 => SocketConfig) public socketConfigs;

    // slot 107: contractsToGateways
    /// @notice Maps contract address to their associated app gateway
    /// @dev contractAddress => appGateway
    mapping(address => address) public coreAppGateways;

    // slot 108: isNonceUsed
    /// @notice Maps nonce to whether it has been used
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // slot 109: isValidPlug
    /// @notice Maps app gateway, chain slug, and plug to whether it is valid
    /// @dev appGateway => chainSlug => plug => isValid
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

    /// @notice Emitted when a valid plug is set for an app gateway
    /// @param appGateway The address of the app gateway
    /// @param chainSlug The identifier of the network
    /// @param plug The address of the plug
    /// @param isValid Whether the plug is valid
    event IsValidPlugSet(address appGateway, uint32 chainSlug, address plug, bool isValid);

    error InvalidGateway();
    error InvalidSwitchboard();

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

    /// @notice Configures app gateways with their respective plugs and switchboards
    /// @dev Only callable by the watcher
    /// @dev This helps in verifying that plugs are called by respective app gateways
    /// @param configs_ Array of configurations containing app gateway, network, plug, and switchboard details
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

    /// @notice Sets the socket, contract factory plug, and fees plug for a network
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
    function setIsValidPlug(uint32 chainSlug_, address plug_, bool isValid_) external {
        isValidPlug[msg.sender][chainSlug_][plug_] = isValid_;
        emit IsValidPlugSet(msg.sender, chainSlug_, plug_, isValid_);
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
    /// @param switchboard_ The address of the switchboard
    function verifyConnections(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        address switchboard_,
        address middleware_
    ) external view {
        // if target is contractFactoryPlug, return
        // as connection is with middleware delivery helper and not app gateway
        if (
            middleware_ == address(deliveryHelper__()) && target_ == contractFactoryPlug[chainSlug_]
        ) return;

        (bytes32 appGatewayId, address switchboard) = getPlugConfigs(chainSlug_, target_);
        if (appGatewayId != WatcherIdUtils.encodeAppGatewayId(appGateway_)) revert InvalidGateway();
        if (switchboard != switchboard_) revert InvalidSwitchboard();
    }

    function _isWatcherSignatureValid(
        bytes memory inputData_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) internal {
        if (isNonceUsed[signatureNonce_]) revert NonceUsed();
        isNonceUsed[signatureNonce_] = true;

        bytes32 digest = keccak256(
            abi.encode(address(this), evmxSlug, signatureNonce_, inputData_)
        );
        digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        // recovered signer is checked for the valid roles later
        address signer = ECDSA.recover(digest, signature_);
        if (signer != owner()) revert InvalidWatcherSignature();
    }
}
