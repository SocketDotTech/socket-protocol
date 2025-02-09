// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Gauge} from "../utils/Gauge.sol";
import {LimitParams, UpdateLimitParams} from "../common/Structs.sol";
import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";

abstract contract WatcherPrecompileLimits is Gauge, AddressResolverUtil {
    // appGateway => receivingLimitParams
    mapping(address => mapping(bytes32 => LimitParams)) internal _limitParams;

    ////////////////////////////////////////////////////////
    ////////////////////// EVENTS //////////////////////////
    ////////////////////////////////////////////////////////

    // Emitted when limit parameters are updated
    event LimitParamsUpdated(UpdateLimitParams[] updates);
    error ActionNotSupported(address appGateway_, bytes32 limitType_);

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
        bytes32 limitType_
    ) internal returns (address appGateway) {
        appGateway = _getAppGateway(appGateway_);
        if (_limitParams[appGateway][limitType_].maxLimit == 0)
            revert ActionNotSupported(appGateway, limitType_);

        // Reverts on limit hit
        _consumeFullLimit(1, _limitParams[appGateway][limitType_]);
    }

    function _getAppGateway(address appGateway_) internal view returns (address appGateway) {
        address resolverAddress = msg.sender == addressResolver__.deliveryHelper() ||
            msg.sender == addressResolver__.feesManager()
            ? appGateway_
            : msg.sender;

        appGateway = _getCoreAppGateway(resolverAddress);
    }

    uint256[49] __gap;
}
