// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Gauge} from "../utils/Gauge.sol";
import {LimitParams, UpdateLimitParams} from "../common/Structs.sol";
import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
import "../interfaces/IWatcherPrecompile.sol";
import {OwnableTwoStep} from "../utils/OwnableTwoStep.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../common/Constants.sol";

abstract contract WatcherPrecompileLimits is
    Gauge,
    AddressResolverUtil,
    OwnableTwoStep,
    IWatcherPrecompile
{
    uint256 public maxLimit;
    uint256 public ratePerSecond;
    uint256 public LIMIT_DECIMALS;

    // appGateway => limitType => receivingLimitParams
    mapping(address => mapping(bytes32 => LimitParams)) internal _limitParams;

    // Mapping to track active app gateways
    mapping(address => bool) private _activeAppGateways;

    ////////////////////////////////////////////////////////
    ////////////////////// EVENTS //////////////////////////
    ////////////////////////////////////////////////////////

    // Emitted when limit parameters are updated
    event LimitParamsUpdated(UpdateLimitParams[] updates);
    error ActionNotSupported(address appGateway_, bytes32 limitType_);
    error NotDeliveryHelper();

    function getCurrentLimit(
        bytes32 limitType_,
        address appGateway_
    ) external view returns (uint256) {
        return _getCurrentLimit(_limitParams[appGateway_][limitType_]);
    }

    function getLimitParams(
        address appGateway_,
        bytes32 limitType_
    ) external view returns (LimitParams memory) {
        return _limitParams[appGateway_][limitType_];
    }

    /**
     * @notice Checks, updates, and reverts based on the limit.
     * @param appGateway_ The app gateway address to check limits for
     * @param limitType_ The type of limit to check
     */
    function checkAndUpdateLimit(
        address appGateway_,
        bytes32 limitType_,
        uint256 consumeLimit_
    ) external {
        if (msg.sender != addressResolver__.deliveryHelper()) revert NotDeliveryHelper();
        _consumeLimit(appGateway_, limitType_, consumeLimit_);
    }

    function updateLimitParams(UpdateLimitParams[] calldata updates_) external onlyOwner {
        _updateLimitParams(updates_);
    }

    /**
     * @notice This function is used to set bridge limits.
     * @dev It can only be updated by the owner.
     * @param updates_ An array of structs containing update parameters.
     */
    function _updateLimitParams(UpdateLimitParams[] calldata updates_) internal {
        for (uint256 i = 0; i < updates_.length; i++) {
            _consumePartLimit(0, _limitParams[updates_[i].appGateway][updates_[i].limitType]); // To keep the current limit in sync
            _limitParams[updates_[i].appGateway][updates_[i].limitType].maxLimit = updates_[i]
                .maxLimit;
            _limitParams[updates_[i].appGateway][updates_[i].limitType].ratePerSecond = updates_[i]
                .ratePerSecond;
        }

        emit LimitParamsUpdated(updates_);
    }

    /**
     * @notice Internal function to consume limit based on caller
     * @param appGateway_ The app gateway address to check limits for
     * @param limitType_ The type of limit to consume
     */
    function _consumeLimit(
        address appGateway_,
        bytes32 limitType_,
        uint256 consumeLimit_
    ) internal returns (address appGateway) {
        if (msg.sender != addressResolver__.deliveryHelper()) return appGateway_;

        appGateway = _getAppGateway(appGateway_);
        LimitParams storage limitParams = _limitParams[appGateway][limitType_];

        // Initialize limit if not active
        if (!_activeAppGateways[appGateway]) {
            LimitParams memory limitParam = LimitParams({
                maxLimit: maxLimit,
                ratePerSecond: ratePerSecond,
                lastUpdateTimestamp: block.timestamp,
                lastUpdateLimit: maxLimit
            });

            _limitParams[appGateway][QUERY] = limitParam;
            _limitParams[appGateway][FINALIZE] = limitParam;
            _limitParams[appGateway][SCHEDULE] = limitParam;

            _activeAppGateways[appGateway] = true;
        }

        // Update the limit
        _consumeFullLimit(consumeLimit_, limitParams);
    }

    function _getAppGateway(address appGateway_) internal view returns (address appGateway) {
        address resolverAddress = msg.sender == addressResolver__.deliveryHelper()
            ? appGateway_
            : msg.sender;

        appGateway = _getCoreAppGateway(resolverAddress);
    }

    function setMaxLimit(uint256 maxLimit_) external onlyOwner {
        maxLimit = maxLimit_;
    }

    function setRatePerSecond(uint256 ratePerSecond_) external onlyOwner {
        ratePerSecond = ratePerSecond_;
    }

    uint256[49] __gap;
}
