// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../../base/AppGatewayBase.sol";
import "../../../utils/Ownable.sol";
import "../Counter.sol";

contract CounterComposer is AppGatewayBase, Ownable {
    constructor(
        address _addressResolver,
        address deployerContract_,
        FeesData memory feesData_,
        address _auctionManager
    ) AppGatewayBase(_addressResolver, _auctionManager) Ownable(msg.sender) {
        addressResolver.setContractsToGateways(deployerContract_);
        _setFeesData(feesData_);
    }

    function incrementCounter(
        address _instance,
        uint256 _counter
    ) public async {
        Counter(_instance).setCounter(_counter);
    }
}
