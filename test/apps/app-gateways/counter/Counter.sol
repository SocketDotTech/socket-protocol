// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "../../../../contracts/protocol/base/PlugBase.sol";

interface ICounterAppGateway {
    function increase(uint256 value_) external returns (bytes32);
}

contract Counter is Ownable, PlugBase {
    uint256 public counter;
    event CounterIncreased(uint256 value);

    function increase() external onlySocket {
        counter++;
        emit CounterIncreased(counter);
    }

    function getCounter() external view returns (uint256) {
        return counter;
    }

    function increaseOnGateway(uint256 value_) external returns (bytes32) {
        // can set overrides here: _setOverrides(params_);
        return ICounterAppGateway(address(socket__)).increase(value_);
    }
}
