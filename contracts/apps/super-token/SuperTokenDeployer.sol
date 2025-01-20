// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

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
        ConstructorParams memory params,
        FeesData memory feesData_
    ) AppDeployerBase(addressResolver_, auctionManager_, sbType_) {
        _claimOwner(owner_);
        creationCodeWithArgs[superToken] = abi.encodePacked(
            type(SuperToken).creationCode,
            abi.encode(
                params.name_,
                params.symbol_,
                params.decimals_,
                params.initialSupplyHolder_,
                params.initialSupply_
            )
        );
        _setFeesData(feesData_);
    }

    function deployContracts(uint32 chainSlug) external async {
        _deploy(superToken, chainSlug);
    }

    // no need to call this directly, will be called automatically after all contracts are deployed.
    // check AppDeployerBase._deploy and AppDeployerBase.onBatchComplete
    function initialize(uint32) public pure override {
        return;
    }
}
