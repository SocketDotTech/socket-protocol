// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./WatcherStorage.sol";

/// @title Trigger
/// @notice Contract that handles trigger validation and execution logic
/// @dev This contract interacts with the WatcherPrecompileStorage for storage access
abstract contract Trigger is WatcherStorage {
    /// @notice stores temporary chainSlug of the trigger from a chain
    uint32 public triggerFromChainSlug;
    /// @notice stores temporary plug of the trigger from a chain
    address public triggerFromPlug;

    /// @notice Stores the trigger fees
    uint256 public triggerFees;

    /// @notice Mapping to store if appGateway has been called with trigger from on-chain Inbox
    /// @dev Maps call ID to boolean indicating if the appGateway has been called
    /// @dev callId => bool
    mapping(bytes32 => bool) public isAppGatewayCalled;

    /// @notice Sets the trigger fees
    /// @param triggerFees_ The amount of fees to set
    function _setTriggerFees(uint256 triggerFees_) internal {
        triggerFees = triggerFees_;
    }

    /// @notice Calls app gateways with the specified parameters
    /// @param params_ Array of call from chain parameters
    /// @dev This function calls app gateways with the specified parameters
    /// @dev This function cannot be retried even if it fails
    /// @dev Call can fail due to gas limit but watcher is a trusted entity
    function _callAppGateways(TriggerParams memory params_) internal {
        if (isAppGatewayCalled[params_.triggerId]) revert AppGatewayAlreadyCalled();

        if (!configurations__().isValidPlug(params_.appGatewayId, params_.chainSlug, params_.plug))
            revert InvalidCallerTriggered();

        feesManager__().transferFrom(appGateway, address(this), triggerFees);

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
