// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "solady/auth/Ownable.sol";
import "../../base/PlugBase.sol";

contract Counter is Ownable, PlugBase {
    uint256 public counter;

    constructor() PlugBase(msg.sender) {
        _initializeOwner(msg.sender);
    }

    function increase() external onlySocket {
        counter++;
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _initializeOwner(socket_);
        _connectSocket(appGateway_, socket_, switchboard_);
    }

    function getCounter() external view returns (uint256) {
        return counter;
    }
}
