// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "solady/auth/Ownable.sol";
import "../../base/PlugBase.sol";

contract CounterInbox is Ownable, PlugBase {
    function increaseOnGateway(uint256 value_) external returns (bytes32) {
        return _callAppGateway(abi.encode(value_), bytes32(0));
    }
}
