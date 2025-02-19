// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./Counter.sol";
import "../../base/AppDeployerBase.sol";
import "solady/auth/Ownable.sol";

contract CounterDeployer is AppDeployerBase, Ownable {
    bytes32 public counter = _createContractId("counter");

    constructor(
        address addressResolver_,
        address auctionManager_,
        bytes32 sbType_,
        Fees memory fees_
    ) AppDeployerBase(addressResolver_, auctionManager_, sbType_) {
        creationCodeWithArgs[counter] = abi.encodePacked(type(Counter).creationCode);
        _setOverrides(fees_);
        _initializeOwner(msg.sender);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(counter, chainSlug_, true);
    }

    function initialize(uint32) public pure override {
        return;
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }
}
