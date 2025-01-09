// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./Counter.sol";
import "../../base/AppDeployerBase.sol";
import "../../utils/Ownable.sol";

contract CounterDeployer is AppDeployerBase, Ownable {
    bytes32 public counter = _createContractId("counter");

    constructor(
        address addressResolver_,
        address auctionManager_,
        bytes32 sbType_,
        FeesData memory feesData_
    )
        AppDeployerBase(addressResolver_, auctionManager_, sbType_)
        Ownable(msg.sender)
    {
        creationCodeWithArgs[counter] = abi.encodePacked(
            type(Counter).creationCode
        );
        _setFeesData(feesData_);
    }

    function deployContracts(uint32 chainSlug) external async {
        _deploy(counter, chainSlug);
    }

    function initialize(uint32) public override {
        return;
    }

    function setFees(FeesData memory feesData_) public {
        feesData = feesData_;
    }
}
