// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {LibCall} from "solady/utils/LibCall.sol";
import "./WatcherStorage.sol";
import {decodeAppGatewayId} from "../../utils/common/IdUtils.sol";

/// @title Trigger
/// @notice Contract that handles trigger validation and execution logic
abstract contract Trigger is WatcherStorage, AddressResolverUtil {
    using LibCall for address;

    event TriggerFeesSet(uint256 triggerFees);
    event TriggerFailed(bytes32 triggerId);
    event TriggerSucceeded(bytes32 triggerId);

    /// @notice Sets the trigger fees
    /// @param triggerFees_ The amount of fees to set
    function _setTriggerFees(uint256 triggerFees_) internal {
        triggerFees = triggerFees_;
        emit TriggerFeesSet(triggerFees_);
    }

    /// @notice Calls app gateways with the specified parameters
    /// @param params_ Array of call from chain parameters
    /// @dev This function calls app gateways with the specified parameters
    /// @dev This function cannot be retried even if it fails
    /// @dev Call can fail due to gas limit but watcher is a trusted entity
    function _callAppGateways(TriggerParams memory params_) internal {
        if (isAppGatewayCalled[params_.triggerId]) revert AppGatewayAlreadyCalled();

        address appGateway = decodeAppGatewayId(params_.appGatewayId);
        if (!configurations__.isValidPlug(appGateway, params_.chainSlug, params_.plug))
            revert InvalidCallerTriggered();

        feesManager__().transferCredits(appGateway, address(this), triggerFees);

        triggerFromChainSlug = params_.chainSlug;
        triggerFromPlug = params_.plug;
        isAppGatewayCalled[params_.triggerId] = true;
        (bool success, , ) = appGateway.tryCall(
            0,
            gasleft(),
            0, // setting max_copy_bytes to 0 as not using returnData right now
            params_.payload
        );

        if (!success) {
            emit TriggerFailed(params_.triggerId);
        } else {
            emit TriggerSucceeded(params_.triggerId);
        }

        triggerFromChainSlug = 0;
        triggerFromPlug = address(0);
    }
}
