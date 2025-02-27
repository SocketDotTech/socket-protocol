// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {AccessControl} from "../utils/AccessControl.sol";
import {Gauge} from "../utils/Gauge.sol";
import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
import {WATCHER_ROLE} from "../utils/common/AccessRoles.sol";
import "./WatcherPrecompileStorage.sol";
import "solady/utils/Initializable.sol";

abstract contract WatcherPrecompileLimits is
    WatcherPrecompileStorage,
    Initializable,
    AccessControl,
    Gauge,
    AddressResolverUtil
{
    // Slots from parent contracts:
    // slot 0-119: watcher precompile storage
    // 0 slots for initializable and ownable
    // slots 120-170: access control (gap + 1)
    // slots 171-220: gauge (gap)
    // slots 221-271: address resolver util (gap + 1)
    // slots 272-321: gap for future storage variables
    uint256[50] _gap_watcher_precompile_limits;

    ////////////////////////////////////////////////////////
    ////////////////////// EVENTS //////////////////////////
    ////////////////////////////////////////////////////////

    // Emitted when limit parameters are updated
    event LimitParamsUpdated(UpdateLimitParams[] updates);
    // Emitted when an app gateway is activated with default limits
    event AppGatewayActivated(address indexed appGateway, uint256 maxLimit, uint256 ratePerSecond);

    error ActionNotSupported(address appGateway_, bytes32 limitType_);
    error NotDeliveryHelper();
    error LimitExceeded(
        address appGateway,
        bytes32 limitType,
        uint256 requested,
        uint256 available
    );

    /**
     * @notice Get the current limit for a specific app gateway and limit type
     * @param limitType_ The type of limit to query
     * @param appGateway_ The app gateway address
     * @return The current limit value
     */
    function getCurrentLimit(
        bytes32 limitType_,
        address appGateway_
    ) external view returns (uint256) {
        return _getCurrentLimit(_limitParams[appGateway_][limitType_]);
    }

    /**
     * @notice Get the limit parameters for a specific app gateway and limit type
     * @param limitType_ The type of limit to query
     * @param appGateway_ The app gateway address
     * @return The limit parameters
     */
    function getLimitParams(
        bytes32 limitType_,
        address appGateway_
    ) external view returns (LimitParams memory) {
        return _limitParams[appGateway_][limitType_];
    }

    /**
     * @notice Check and update limit for a specific app gateway
     * @param appGateway_ The app gateway address
     * @param limitType_ The type of limit to check
     * @param consumeLimit_ The amount of limit to consume
     */
    function checkAndConsumeLimit(
        address appGateway_,
        bytes32 limitType_,
        uint256 consumeLimit_
    ) external {
        if (msg.sender != addressResolver__.deliveryHelper()) revert NotDeliveryHelper();
        _consumeLimit(appGateway_, limitType_, consumeLimit_);
    }

    /**
     * @notice Update limit parameters for multiple app gateways
     * @param updates_ Array of limit parameter updates
     */
    function updateLimitParams(UpdateLimitParams[] calldata updates_) external onlyOwner {
        _updateLimitParams(updates_);
    }

    /**
     * @notice Internal function to update limit parameters
     * @param updates_ Array of limit parameter updates
     */
    function _updateLimitParams(UpdateLimitParams[] calldata updates_) internal {
        for (uint256 i = 0; i < updates_.length; i++) {
            _consumePartLimit(0, _limitParams[updates_[i].appGateway][updates_[i].limitType]);
            _limitParams[updates_[i].appGateway][updates_[i].limitType].maxLimit = updates_[i]
                .maxLimit;
            _limitParams[updates_[i].appGateway][updates_[i].limitType].ratePerSecond = updates_[i]
                .ratePerSecond;
        }

        emit LimitParamsUpdated(updates_);
    }

    /**
     * @notice Internal function to consume limit based on caller
     * @param appGateway_ The app gateway address
     * @param limitType_ The type of limit to consume
     * @param consumeLimit_ The amount of limit to consume
     * @return appGateway The resolved app gateway address
     */
    function _consumeLimit(
        address appGateway_,
        bytes32 limitType_,
        uint256 consumeLimit_
    ) internal returns (address appGateway) {
        // delivery helper consumes the limit while batching hence returned here
        if (msg.sender == addressResolver__.deliveryHelper()) return appGateway_;

        appGateway = _getAppGateway(appGateway_);
        LimitParams storage limitParams = _limitParams[appGateway][limitType_];

        // Initialize limit if not active
        if (!_activeAppGateways[appGateway]) {
            LimitParams memory limitParam = LimitParams({
                maxLimit: defaultLimit,
                ratePerSecond: defaultRatePerSecond,
                lastUpdateTimestamp: block.timestamp,
                lastUpdateLimit: defaultLimit
            });

            _limitParams[appGateway][QUERY] = limitParam;
            _limitParams[appGateway][FINALIZE] = limitParam;
            _limitParams[appGateway][SCHEDULE] = limitParam;

            _activeAppGateways[appGateway] = true;
            emit AppGatewayActivated(appGateway, defaultLimit, defaultRatePerSecond);
        }

        // Update the limit
        _consumeFullLimit(consumeLimit_ * 10 ** LIMIT_DECIMALS, limitParams);
    }

    /**
     * @notice Internal function to get the core app gateway address
     * @param originAppGateway_ The input app gateway address
     * @return appGateway The resolved core app gateway address
     */
    function _getAppGateway(address originAppGateway_) internal view returns (address appGateway) {
        address originAppGateway = msg.sender == addressResolver__.deliveryHelper()
            ? originAppGateway_
            : msg.sender;

        appGateway = _getCoreAppGateway(originAppGateway);
    }

    /**
     * @notice Set the default limit value
     * @param defaultLimit_ The new default limit value
     */
    function setDefaultLimit(uint256 defaultLimit_) external onlyOwner {
        defaultLimit = defaultLimit_;
    }

    /**
     * @notice Set the rate at which limit replenishes
     * @param defaultRatePerSecond_ The new rate per second
     */
    function setDefaultRatePerSecond(uint256 defaultRatePerSecond_) external onlyOwner {
        defaultRatePerSecond = defaultRatePerSecond_;
    }
}
