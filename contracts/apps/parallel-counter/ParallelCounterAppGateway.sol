// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../base/AppGatewayBase.sol";
import "../counter/Counter.sol";

contract ParallelCounterAppGateway is AppGatewayBase {
    constructor(
        address _addressResolver,
        address deployerContract_,
        address auctionManager_,
        FeesData memory feesData_
    ) AppGatewayBase(_addressResolver, auctionManager_) {
        addressResolver.setContractsToGateways(deployerContract_);
        _setFeesData(feesData_);
        _setIsCallSequential(false);
    }

    function incrementCounters(address[] memory instances) public async {
        // the increase function is called on given list of instances
        // this
        for (uint256 i = 0; i < instances.length; i++) {
            Counter(instances[i]).increase();
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
