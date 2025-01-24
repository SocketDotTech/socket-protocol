// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../counter/Counter.sol";
import "../../base/AppDeployerBase.sol";
import "../../utils/Ownable.sol";

contract ParallelCounterDeployer is AppDeployerBase, Ownable {
    bytes32 public counter1 = _createContractId("counter1");
    bytes32 public counter2 = _createContractId("counter2");

    constructor(
        address addressResolver_,
        address auctionManager_,
        bytes32 sbType_,
        FeesData memory feesData_
    ) AppDeployerBase(addressResolver_, auctionManager_, sbType_) {
        creationCodeWithArgs[counter1] = abi.encodePacked(type(Counter).creationCode);
        creationCodeWithArgs[counter2] = abi.encodePacked(type(Counter).creationCode);
        _setFeesData(feesData_);
        _setIsCallSequential(false);
        _claimOwner(msg.sender);
    }

    function deployContracts(uint32 chainSlug) external async {
        _deploy(counter1, chainSlug);
        _deploy(counter2, chainSlug);
    }

    function deployMultiChainContracts(uint32[] memory chainSlugs) external async {
        for (uint32 i = 0; i < chainSlugs.length; i++) {
            _deploy(counter1, chainSlugs[i]);
            _deploy(counter2, chainSlugs[i]);
        }
    }

    function initialize(uint32) public pure override {
        return;
    }

    function setFees(FeesData memory feesData_) public {
        feesData = feesData_;
    }
}
