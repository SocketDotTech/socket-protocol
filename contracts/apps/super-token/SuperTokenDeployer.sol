// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./SuperToken.sol";
import "../../base/AppDeployerBase.sol";
import "../../utils/Ownable.sol";

contract SuperTokenDeployer is AppDeployerBase, Ownable {
    bytes32 public superToken = _createContractId("superToken");
    struct ConstructorParams {
        string name_;
        string symbol_;
        uint8 decimals_;
        address initialSupplyHolder_;
        uint256 initialSupply_;
    }

    constructor(
        address addressResolver_,
        address owner_,
        address auctionManager_,
        bytes32 sbType_,
        ConstructorParams memory params_,
        FeesData memory feesData_
    ) AppDeployerBase(addressResolver_, auctionManager_, sbType_) {
        _claimOwner(owner_);
        creationCodeWithArgs[superToken] = abi.encodePacked(
            type(SuperToken).creationCode,
            abi.encode(
                params_.name_,
                params_.symbol_,
                params_.decimals_,
                params_.initialSupplyHolder_,
                params_.initialSupply_
            )
        );
        _setFeesData(feesData_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(superToken, chainSlug_);
    }

    // no need to call this directly, will be called automatically after all contracts are deployed.
    // check AppDeployerBase._deploy and AppDeployerBase.onBatchComplete
    function initialize(uint32) public pure override {
        return;
    }
}
