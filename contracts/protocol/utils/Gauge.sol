// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {LimitParams} from "../utils/common/Structs.sol";
import {LimitReached} from "../utils/common/Errors.sol";

abstract contract Gauge {
    function _getCurrentLimit(LimitParams storage params_) internal view returns (uint256 _limit) {
        uint256 timeElapsed = block.timestamp - params_.lastUpdateTimestamp;
        uint256 limitIncrease = timeElapsed * params_.ratePerSecond;

        if (limitIncrease + params_.lastUpdateLimit > params_.maxLimit) {
            _limit = params_.maxLimit;
        } else {
            _limit = limitIncrease + params_.lastUpdateLimit;
        }
    }

    function _consumePartLimit(
        uint256 amount_,
        LimitParams storage params_
    ) internal returns (uint256 consumedAmount, uint256 pendingAmount) {
        uint256 currentLimit = _getCurrentLimit(params_);
        params_.lastUpdateTimestamp = block.timestamp;
        if (currentLimit >= amount_) {
            params_.lastUpdateLimit = currentLimit - amount_;
            consumedAmount = amount_;
            pendingAmount = 0;
        } else {
            params_.lastUpdateLimit = 0;
            consumedAmount = currentLimit;
            pendingAmount = amount_ - currentLimit;
        }
    }

    function _consumeFullLimit(uint256 amount_, LimitParams storage params_) internal {
        uint256 currentLimit = _getCurrentLimit(params_);
        if (currentLimit >= amount_) {
            params_.lastUpdateTimestamp = block.timestamp;
            params_.lastUpdateLimit = currentLimit - amount_;
        } else {
            revert LimitReached();
        }
    }
}
