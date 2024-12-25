// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Gauge} from "../utils/Gauge.sol";
import {LimitParams, UpdateLimitParams} from "../common/Structs.sol";
import {AmountOutsideLimit} from "../common/Errors.sol";
import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
abstract contract WatcherPrecompileLimits is Gauge, AddressResolverUtil {
    // appGateway => receivingLimitParams
    mapping(address => mapping(bytes32 => LimitParams)) _limitParams;
    error ActionNotSupported(address appGateway_, bytes32 limitType_);

    ////////////////////////////////////////////////////////
    ////////////////////// EVENTS //////////////////////////
    ////////////////////////////////////////////////////////

    // Emitted when limit parameters are updated
    event LimitParamsUpdated(UpdateLimitParams[] updates);

    constructor(
        address addressResolver_
    ) AddressResolverUtil(addressResolver_) {}
    /**
     * @notice This function is used to set bridge limits.
     * @dev It can only be updated by the owner.
     * @param updates An array of structs containing update parameters.
     */
    function _updateLimitParams(UpdateLimitParams[] calldata updates) internal {
        for (uint256 i = 0; i < updates.length; i++) {
            _consumePartLimit(
                0,
                _limitParams[updates[i].appGateway][updates[i].limitType]
            ); // To keep the current limit in sync
            _limitParams[updates[i].appGateway][updates[i].limitType]
                .maxLimit = updates[i].maxLimit;
            _limitParams[updates[i].appGateway][updates[i].limitType]
                .ratePerSecond = updates[i].ratePerSecond;
        }

        emit LimitParamsUpdated(updates);
    }

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

    function _consumeLimit(address sender_, bytes32 limitType_) internal {
        address appGateway_ = addressResolver.contractsToGateways(sender_);
        if (_limitParams[appGateway_][limitType_].maxLimit == 0)
            revert ActionNotSupported(appGateway_, limitType_);

        _consumeFullLimit(uint256(1), _limitParams[appGateway_][limitType_]); // Reverts on limit hit
    }
}
