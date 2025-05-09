// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/// @title Trigger
/// @notice Contract that handles trigger validation and execution logic
/// @dev This contract interacts with the WatcherPrecompileStorage for storage access
contract Trigger {
    // The address of the WatcherPrecompileStorage contract
    address public watcherStorage;

    /// @notice stores temporary address of the app gateway caller from a chain
    address public appGatewayCaller;

    // slot 57
    /// @notice Mapping to store if appGateway has been called with trigger from on-chain Inbox
    /// @dev Maps call ID to boolean indicating if the appGateway has been called
    /// @dev callId => bool
    mapping(bytes32 => bool) public appGatewayCalled;


    // Only WatcherPrecompileStorage can call functions
    modifier onlyWatcherStorage() {
        require(msg.sender == watcherStorage, "Only WatcherStorage can call");
        _;
    }

    /// @notice Sets the WatcherPrecompileStorage address
    /// @param watcherStorage_ The address of the WatcherPrecompileStorage contract
    constructor(address watcherStorage_) {
        watcherStorage = watcherStorage_;
    }

    /// @notice Updates the WatcherPrecompileStorage address
    /// @param watcherStorage_ The new address of the WatcherPrecompileStorage contract
    function setWatcherStorage(address watcherStorage_) external onlyWatcherStorage {
        watcherStorage = watcherStorage_;
    }

    /// @notice Calls app gateways with the specified parameters
    /// @param params_ Array of call from chain parameters
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    /// @dev This function calls app gateways with the specified parameters
    /// @dev It verifies that the signature is valid and that the app gateway hasn't been called yet
    function callAppGateways(
        TriggerParams[] memory params_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external onlyWatcherStorage {
        for (uint256 i = 0; i < params_.length; i++) {
            if (appGatewayCalled[params_[i].triggerId]) revert AppGatewayAlreadyCalled();

            address appGateway = WatcherIdUtils.decodeAppGatewayId(params_[i].appGatewayId);
            if (
                !watcherPrecompileConfig__.isValidPlug(
                    appGateway,
                    params_[i].chainSlug,
                    params_[i].plug
                )
            ) revert InvalidCallerTriggered();

            IFeesManager(addressResolver__.feesManager()).assignWatcherPrecompileCreditsFromAddress(
                    watcherPrecompileLimits__.callBackFees(),
                    appGateway
                );

            appGatewayCaller = appGateway;
            appGatewayCalled[params_[i].triggerId] = true;

            (bool success, , ) = appGateway.tryCall(
                0,
                gasleft(),
                0, // setting max_copy_bytes to 0 as not using returnData right now
                params_[i].payload
            );
            if (!success) {
                emit AppGatewayCallFailed(params_[i].triggerId);
            } else {
                emit CalledAppGateway(params_[i].triggerId);
            }
        }

        appGatewayCaller = address(0);
    }
}
