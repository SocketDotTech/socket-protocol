// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./SuperToken.sol";
import "./LimitHook.sol";
import "../../base/AppDeployerBase.sol";
import "../../utils/Ownable.sol";

contract SuperTokenDeployer is AppDeployerBase, Ownable {
    bytes32 public superToken = _createContractId("superToken");
    bytes32 public limitHook = _createContractId("limitHook");

    struct ConstructorParams {
        uint256 _burnLimit;
        uint256 _mintLimit;
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
    )
        AppDeployerBase(addressResolver_, auctionManager_, sbType_)
        Ownable(owner_)
    {
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

        creationCodeWithArgs[limitHook] = abi.encodePacked(
            type(LimitHook).creationCode,
            abi.encode(params._burnLimit, params._mintLimit)
        );

        _setFeesData(feesData_);
    }

    function deployContracts(uint32 chainSlug) external async {
        _deploy(superToken, chainSlug);
        _deploy(limitHook, chainSlug);
    }

    // don't need to call this directly, will be called automatically after all contracts are deployed.
    // check AppDeployerBase.allPayloadsExecuted and AppGateway.queueAndDeploy
    function initialize(uint32 chainSlug) public override async {
        address limitHookContract = getOnChainAddress(limitHook, chainSlug);
        SuperToken(forwarderAddresses[superToken][chainSlug]).setLimitHook(
            limitHookContract
        );
    }
}
