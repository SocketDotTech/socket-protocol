// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "solady/auth/Ownable.sol";
import "../../../../contracts/base/PlugBase.sol";

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
        // can set inbox params here: _setInboxParams(params_);
        return ICounterAppGateway(address(socket__)).increase(value_);
    }
}
