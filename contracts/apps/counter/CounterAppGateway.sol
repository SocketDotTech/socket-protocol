// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../base/AppGatewayBase.sol";
import "./Counter.sol";

contract CounterAppGateway is AppGatewayBase {
    constructor(
        address addressResolver_,
        address deployerContract_,
        address auctionManager_,
        FeesData memory feesData_
    ) AppGatewayBase(addressResolver_, auctionManager_) {
        addressResolver__.setContractsToGateways(deployerContract_);
        _setFeesData(feesData_);
    }

    function incrementCounters(address[] memory instances_) public async {
        // the increase function is called on given list of instances
        // this
        for (uint256 i = 0; i < instances_.length; i++) {
            Counter(instances_[i]).increase();
        }
    }

    function setFees(FeesData memory feesData_) public {
        feesData = feesData_;
    }

    function withdrawFeeTokens(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
