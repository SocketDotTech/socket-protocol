// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../base/AppGatewayBase.sol";
import "./Counter.sol";
import "./ICounter.sol";
import "../../interfaces/IForwarder.sol";
import "../../interfaces/IPromise.sol";

contract CounterAppGateway is AppGatewayBase {
    uint256 arbCounter;
    uint256 optCounter;

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
        for (uint256 i = 0; i < instances.length; i++) {
            ICounter(instances[i]).increase();
        }
    }

    function readCounters(address[] memory instances) public async {
        // the increase function is called on given list of instances
        // this
        _readCallOn();
        for (uint256 i = 0; i < instances.length; i++) {

            uint32 chainSlug = IForwarder(instances[i]).getChainSlug();
            ICounter(instances[i]).getCounter();
            IPromise(instances[i]).then(
                this.setCounterValues.selector,
                abi.encode(chainSlug)
            );
        }
        _readCallOff();
        ICounter(instances[0]).increase();
    }

    function setCounterValues(bytes memory data, bytes memory returnData) external onlyPromises {
        uint256 counterValue = abi.decode(returnData, (uint256));
        uint32 chainSlug = abi.decode(data, (uint32));
        if (chainSlug == 421614) {
            arbCounter = counterValue;
        } else if (chainSlug == 11155420) {
            optCounter = counterValue;
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
