// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../utils/Ownable.sol";
import "../../base/PlugBase.sol";

contract Counter is Ownable(msg.sender), PlugBase(msg.sender) {
    uint256 public counter;

    function increase() external onlySocket {
        counter++;
    }

    function initialize(
        address switchboard_,
        address socket_,
        address appGateway_
    ) external onlyOwner {
        socket__ = ISocket(socket_);
        appGateway = appGateway_;
        _claimOwner(socket_);
        _connectSocket(appGateway_, switchboard_);
    }
}
