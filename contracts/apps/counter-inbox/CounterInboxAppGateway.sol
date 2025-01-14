// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../base/AppGatewayBase.sol";

contract CounterInboxAppGateway is AppGatewayBase {
    uint256 public counter;

    constructor(
        address _addressResolver,
        address auctionManager_,
        address counterInbox_,
        uint32 chainSlug_,
        FeesData memory feesData_
    ) AppGatewayBase(_addressResolver, auctionManager_) {
        watcherPrecompile().setIsValidInboxCaller(chainSlug_, address(counterInbox_), true);
        _setFeesData(feesData_);
    }

    function callFromInbox(
        uint32,
        address,
        bytes calldata payload_,
        bytes32
    ) external override onlyWatcherPrecompile {
        uint256 value = abi.decode(payload_, (uint256));
        counter += value;
    }
}
