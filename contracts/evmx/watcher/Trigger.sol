// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {TriggerParams} from "../../utils/common/Structs.sol";
import {InvalidCallerTriggered, AppGatewayAlreadyCalled} from "../../utils/common/Errors.sol";

import "./WatcherBase.sol";
import "../helpers/AddressResolverUtil.sol";

/// @title Trigger
/// @notice Contract that handles trigger validation and execution logic
/// @dev This contract interacts with the WatcherPrecompileStorage for storage access
contract Trigger is WatcherBase, AddressResolverUtil {
    /// @notice stores temporary address of the app gateway caller from a chain
    address public appGatewayCaller;

    /// @notice Stores the trigger fees
    uint256 public triggerFees;

    /// @notice Mapping to store if appGateway has been called with trigger from on-chain Inbox
    /// @dev Maps call ID to boolean indicating if the appGateway has been called
    /// @dev callId => bool
    mapping(bytes32 => bool) public appGatewayCalled;

    /// @notice Sets the Watcher address
    /// @param watcher_ The address of the WatcherPrecompileStorage contract
    constructor(address watcher_) WatcherBase(watcher_) {}

    /// @notice Sets the trigger fees
    /// @param triggerFees_ The amount of fees to set
    function setTriggerFees(uint256 triggerFees_) external onlyWatcher {
        triggerFees = triggerFees_;
    }

    /// @notice Calls app gateways with the specified parameters
    /// @param params_ Array of call from chain parameters
    /// @dev This function calls app gateways with the specified parameters
    function callAppGateways(TriggerParams memory params_) external onlyWatcher {
        if (appGatewayCalled[params_.triggerId]) revert AppGatewayAlreadyCalled();

        address appGateway = WatcherIdUtils.decodeAppGatewayId(params_.appGatewayId);
        if (!watcherPrecompileConfig__.isValidPlug(appGateway, params_.chainSlug, params_.plug))
            revert InvalidCallerTriggered();

        feesManager__().assignWatcherPrecompileCreditsFromAddress(triggerFees, appGateway);

        // todo: store and update in watcher contract
        // appGatewayCaller = appGateway;

        appGatewayCalled[params_.triggerId] = true;
        (bool success, , ) = appGateway.tryCall(
            0,
            gasleft(),
            0, // setting max_copy_bytes to 0 as not using returnData right now
            params_.payload
        );
        if (!success) {
            emit AppGatewayCallFailed(params_.triggerId);
        } else {
            emit CalledAppGateway(params_.triggerId);
        }

        // todo: store and update in watcher contract
        // appGatewayCaller = address(0);
    }
}
