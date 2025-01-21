// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../utils/Ownable.sol";
import "../../base/PlugBase.sol";

contract Counter is Ownable(msg.sender), PlugBase(msg.sender) {
    uint256 public counter;

    function increase() external onlySocket {
        counter++;
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _claimOwner(socket_);
        _connectSocket(appGateway_, socket_, switchboard_);
    }

    function getCounter() external view returns (uint256) {
        return counter;
    }
}
