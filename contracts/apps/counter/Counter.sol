// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "solady/auth/Ownable.sol";
import "../../base/PlugBase.sol";

contract Counter is Ownable, PlugBase {
    uint256 public counter;

    function increase() external onlySocket {
        counter++;
    }

    function getCounter() external view returns (uint256) {
        return counter;
    }
}
