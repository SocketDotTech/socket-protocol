// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../utils/Ownable.sol";
import "../../base/PlugBase.sol";

contract CounterInbox is Ownable(msg.sender), PlugBase(msg.sender) {
    function increaseOnGateway(uint256 value) external returns (bytes32) {
        return _callAppGateway(abi.encode(value), bytes32(0));
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _claimOwner(socket_);
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
