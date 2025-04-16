// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Gauge} from "../utils/Gauge.sol";
import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
import "../../interfaces/IWatcherPrecompileLimits.sol";
import {SCHEDULE, QUERY, FINALIZE} from "../utils/common/Constants.sol";

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

    // token => fee amount
    mapping(address => uint256) public queryFees;
    mapping(address => uint256) public finalizeFees;
    mapping(address => uint256) public scheduleFees;

    /// @notice Emitted when the default limit and rate per second are set
    event DefaultLimitAndRatePerSecondSet(uint256 defaultLimit, uint256 defaultRatePerSecond);
    event WatcherFeesNotSetForToken(address token_);
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

    function setQueryFees(
        address[] calldata tokens_,
        uint256[] calldata amounts_
    ) external onlyOwner {
        require(tokens_.length == amounts_.length, "Length mismatch");
        for (uint256 i = 0; i < tokens_.length; i++) {
            queryFees[tokens_[i]] = amounts_[i];
        }
    }

    function setFinalizeFees(
        address[] calldata tokens_,
        uint256[] calldata amounts_
    ) external onlyOwner {
        require(tokens_.length == amounts_.length, "Length mismatch");
        for (uint256 i = 0; i < tokens_.length; i++) {
            finalizeFees[tokens_[i]] = amounts_[i];
        }
    }

    function setScheduleFees(
        address[] calldata tokens_,
        uint256[] calldata amounts_
    ) external onlyOwner {
        require(tokens_.length == amounts_.length, "Length mismatch");
        for (uint256 i = 0; i < tokens_.length; i++) {
            scheduleFees[tokens_[i]] = amounts_[i];
        }
    }

    function getTotalFeesRequired(
        address token_,
        uint queryCount,
        uint finalizeCount,
        uint scheduleCount
    ) external view returns (uint256) {
        uint256 totalFees = 0;
        if (queryFees[token_] == 0 || finalizeFees[token_] == 0 || scheduleFees[token_] == 0) {
            revert WatcherFeesNotSetForToken(token_);
        }
        totalFees += queryCount * queryFees[token_];
        totalFees += finalizeCount * finalizeFees[token_];
        totalFees += scheduleCount * scheduleFees[token_];
        return totalFees;
    }
}
