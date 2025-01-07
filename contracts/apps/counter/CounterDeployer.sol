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
        FeesData memory feesData_
    ) AppDeployerBase(addressResolver_, auctionManager_) Ownable(msg.sender) {
        creationCodeWithArgs[counter] = abi.encodePacked(
            type(Counter).creationCode,
            abi.encode(address(this))
        );
        _setFeesData(feesData_);
    }

    function deployContracts(uint32 chainSlug) external async {
        _deploy(counter, chainSlug);
    }

    function initialize(uint32 chainSlug) public override async {
        return;
    }

    function setFees(FeesData memory feesData_) public {
        feesData = feesData_;
    }
}
