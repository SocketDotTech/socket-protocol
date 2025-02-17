// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../counter/Counter.sol";
import "../../base/AppDeployerBase.sol";
import "../../utils/OwnableTwoStep.sol";

contract ParallelCounterDeployer is AppDeployerBase, OwnableTwoStep {
    bytes32 public counter1 = _createContractId("counter1");
    bytes32 public counter2 = _createContractId("counter2");

    constructor(
        address addressResolver_,
        address auctionManager_,
        bytes32 sbType_,
        Fees memory fees_
    ) AppDeployerBase(addressResolver_, auctionManager_, sbType_) {
        creationCodeWithArgs[counter1] = abi.encodePacked(type(Counter).creationCode);
        creationCodeWithArgs[counter2] = abi.encodePacked(type(Counter).creationCode);
        _setOverrides(Read.OFF, Sequential.FALSE, 1000000, fees_);
        _claimOwner(msg.sender);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(counter1, chainSlug_);
        _deploy(counter2, chainSlug_);
    }

    function deployMultiChainContracts(uint32[] memory chainSlugs_) external async {
        for (uint32 i = 0; i < chainSlugs_.length; i++) {
            _deploy(counter1, chainSlugs_[i]);
            _deploy(counter2, chainSlugs_[i]);
        }
    }

    function initialize(uint32) public pure override {
        return;
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }
}
