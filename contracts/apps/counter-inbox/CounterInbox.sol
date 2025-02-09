// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../utils/OwnableTwoStep.sol";
import "../../base/PlugBase.sol";

contract CounterInbox is OwnableTwoStep, PlugBase {
    constructor() PlugBase(msg.sender) {
        _claimOwner(msg.sender);
    }

    function increaseOnGateway(uint256 value_) external returns (bytes32) {
        return _callAppGateway(abi.encode(value_), bytes32(0));
    }

    function connectSocket(address appGateway_, address socket_, address switchboard_) external {
        _claimOwner(socket_);
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
