// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../base/AppGatewayBase.sol";

contract CronAppGateway is AppGatewayBase {
    event TimeoutResolved(
        uint256 creationTimestamp,
        uint256 executionTimestamp
    );

    constructor(
        address _addressResolver,
        address deployerContract_,
        address auctionManager_,
        FeesData memory feesData_
    ) AppGatewayBase(_addressResolver, auctionManager_) {
        addressResolver.setContractsToGateways(deployerContract_);
        _setFeesData(feesData_);
    }

    function setTimeout(uint256 delayInSeconds) public {
        bytes memory payload = abi.encodeWithSelector(
            this.resolveTimeout.selector,
            block.timestamp
        );
        watcherPrecompile().setTimeout(address(this), payload, delayInSeconds);
    }

    function resolveTimeout(
        uint256 creationTimestamp
    ) external onlyWatcherPrecompile {
        emit TimeoutResolved(creationTimestamp, block.timestamp);
    }
}
