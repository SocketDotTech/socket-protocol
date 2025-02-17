// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../base/AppGatewayBase.sol";

contract CronAppGateway is AppGatewayBase {
    event TimeoutResolved(uint256 creationTimestamp, uint256 executionTimestamp);

    constructor(
        address addressResolver_,
        address deployerContract_,
        address auctionManager_,
        Fees memory fees_
    ) AppGatewayBase(addressResolver_, auctionManager_) {
        addressResolver__.setContractsToGateways(deployerContract_);
        _setOverrides(fees_);
    }

    function setTimeout(uint256 delayInSeconds_) public {
        bytes memory payload = abi.encodeWithSelector(
            this.resolveTimeout.selector,
            block.timestamp
        );
        watcherPrecompile__().setTimeout(address(this), payload, delayInSeconds_);
    }

    function resolveTimeout(uint256 creationTimestamp_) external onlyWatcherPrecompile {
        emit TimeoutResolved(creationTimestamp_, block.timestamp);
    }
}
