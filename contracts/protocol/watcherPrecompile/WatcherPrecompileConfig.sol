// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./WatcherPrecompileLimits.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

/// @title WatcherPrecompileConfig
/// @notice Configuration contract for the Watcher Precompile system
/// @dev Handles the mapping between networks, plugs, and app gateways for payload execution
abstract contract WatcherPrecompileConfig is WatcherPrecompileLimits {
    // slot 322-371: gap for future storage variables
    uint256[50] _gap_watcher_precompile_config;

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

    /// @notice Emitted when contracts are set for a network
    /// @param chainSlug The identifier of the network
    /// @param sbType The type of switchboard
    /// @param switchboard The address of the switchboard
    /// @param socket The address of the socket
    /// @param contractFactoryPlug The address of the contract factory plug
    /// @param feesPlug The address of the fees plug
    event OnChainContractSet(
        uint32 chainSlug,
        bytes32 sbType,
        address switchboard,
        address socket,
        address contractFactoryPlug,
        address feesPlug
    );

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
                appGateway: configs_[i].appGateway,
                switchboard: configs_[i].switchboard
            });

            emit PlugAdded(configs_[i].appGateway, configs_[i].chainSlug, configs_[i].plug);
        }
    }

    /// @notice Sets the switchboard for a network
    /// @param chainSlug_ The identifier of the network
    /// @param switchboard_ The address of the switchboard
    function setOnChainContracts(
        uint32 chainSlug_,
        bytes32 sbType_,
        address switchboard_,
        address socket_,
        address contractFactoryPlug_,
        address feesPlug_
    ) external override onlyOwner {
        switchboards[chainSlug_][sbType_] = switchboard_;
        sockets[chainSlug_] = socket_;
        contractFactoryPlug[chainSlug_] = contractFactoryPlug_;
        feesPlug[chainSlug_] = feesPlug_;

        emit OnChainContractSet(
            chainSlug_,
            sbType_,
            switchboard_,
            socket_,
            contractFactoryPlug_,
            feesPlug_
        );
    }

    // @dev app gateway can set the valid plugs for each chain slug
    function setIsValidPlug(uint32 chainSlug_, address plug_, bool isValid_) external {
        isValidPlug[msg.sender][chainSlug_][plug_] = isValid_;
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
