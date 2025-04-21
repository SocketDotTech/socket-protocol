// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Gauge} from "../utils/Gauge.sol";
import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
import "../../interfaces/IWatcherPrecompileLimits.sol";
import {SCHEDULE, QUERY, FINALIZE, CALLBACK} from "../utils/common/Constants.sol";

/// @title WatcherPrecompileLimits
/// @notice Contract for managing watcher precompile limits
contract WatcherPrecompileLimits is
    IWatcherPrecompileLimits,
    Initializable,
    Ownable,
    Gauge,
    AddressResolverUtil
{
    // slots 0-49 (50) reserved for gauge
    // slots 50-100 (51) reserved for addr resolver util

    // slots [101-150]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 151: limitDecimals
    /// @notice Number of decimals used in limit calculations
    uint256 public limitDecimals;

    // slot 152: defaultLimit
    /// @notice Default limit value for any app gateway
    uint256 public defaultLimit;

    // slot 153: defaultRatePerSecond
    /// @notice Rate at which limit replenishes per second
    uint256 public defaultRatePerSecond;

    // slot 154: _limitParams
    // appGateway => limitType => receivingLimitParams
    mapping(address => mapping(bytes32 => LimitParams)) internal _limitParams;

    // slot 155: _activeAppGateways
    // Mapping to track active app gateways
    mapping(address => bool) internal _activeAppGateways;

    // slot 156: precompileCount
    // limitType => requestCount => count
    mapping(bytes32 => mapping(uint40 => uint256)) public precompileCount;

    // slot 157: fees
    uint256 public queryFees;
    uint256 public finalizeFees;
    uint256 public scheduleFees;
    uint256 public callBackFees;

    /// @notice Emitted when the default limit and rate per second are set
    event DefaultLimitAndRatePerSecondSet(uint256 defaultLimit, uint256 defaultRatePerSecond);

    error WatcherFeesNotSet(bytes32 limitType);

    /// @notice Initial initialization (version 1)
    function initialize(
        address owner_,
        address addressResolver_,
        uint256 defaultLimit_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
        limitDecimals = 18;

        // limit per day
        defaultLimit = defaultLimit_ * 10 ** limitDecimals;
        // limit per second
        defaultRatePerSecond = defaultLimit / (24 * 60 * 60);
    }

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
     */
    function consumeLimit(
        address appGateway_,
        bytes32 limitType_,
        uint256 consumeLimit_
    ) external override onlyWatcherPrecompile {
        LimitParams storage limitParams = _limitParams[appGateway_][limitType_];

        // Initialize limit if not active, give default limit and rate per second
        if (!_activeAppGateways[appGateway_]) {
            LimitParams memory limitParam = LimitParams({
                maxLimit: defaultLimit,
                ratePerSecond: defaultRatePerSecond,
                lastUpdateTimestamp: block.timestamp,
                lastUpdateLimit: defaultLimit
            });

            _limitParams[appGateway_][QUERY] = limitParam;
            _limitParams[appGateway_][FINALIZE] = limitParam;
            _limitParams[appGateway_][SCHEDULE] = limitParam;

            _activeAppGateways[appGateway_] = true;
            emit AppGatewayActivated(appGateway_, defaultLimit, defaultRatePerSecond);
        }

        // Update the limit
        // precompileCount[limitType_][requestCount_] += consumeLimit_;

        _consumeFullLimit(consumeLimit_ * 10 ** limitDecimals, limitParams);
    }

    /**
     * @notice Set the default limit value
     * @param defaultLimit_ The new default limit value
     */
    function setDefaultLimitAndRatePerSecond(uint256 defaultLimit_) external onlyOwner {
        defaultLimit = defaultLimit_;
        defaultRatePerSecond = defaultLimit / (24 * 60 * 60);

        emit DefaultLimitAndRatePerSecondSet(defaultLimit, defaultRatePerSecond);
    }

    function setQueryFees(uint256 queryFees_) external onlyOwner {
        queryFees = queryFees_;
    }

    function setFinalizeFees(uint256 finalizeFees_) external onlyOwner {
        finalizeFees = finalizeFees_;
    }

    function setScheduleFees(uint256 scheduleFees_) external onlyOwner {
        scheduleFees = scheduleFees_;
    }

    function setCallBackFees(uint256 callBackFees_) external onlyOwner {
        callBackFees = callBackFees_;
    }

    function getTotalFeesRequired(uint40 requestCount_) external view returns (uint256) {
        uint256 totalFees = 0;
        if (queryFees == 0) {
            revert WatcherFeesNotSet(QUERY);
        }
        if (finalizeFees == 0) {
            revert WatcherFeesNotSet(FINALIZE);
        }
        if (scheduleFees == 0) {
            revert WatcherFeesNotSet(SCHEDULE);
        }
        if (callBackFees == 0) {
            revert WatcherFeesNotSet(CALLBACK);
        }

        uint256 totalCallbacks = precompileCount[QUERY][requestCount_] +
            precompileCount[FINALIZE][requestCount_] +
            precompileCount[SCHEDULE][requestCount_];

        totalFees += totalCallbacks * callBackFees;
        totalFees += precompileCount[QUERY][requestCount_] * queryFees;
        totalFees += precompileCount[FINALIZE][requestCount_] * finalizeFees;
        totalFees += precompileCount[SCHEDULE][requestCount_] * scheduleFees;

        return totalFees;
    }
}
