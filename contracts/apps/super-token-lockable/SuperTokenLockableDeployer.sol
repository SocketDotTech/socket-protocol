// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./SuperTokenLockable.sol";
import "./LimitHook.sol";
import "../../base/AppDeployerBase.sol";
import "solady/auth/Ownable.sol";

contract SuperTokenLockableDeployer is AppDeployerBase, Ownable {
    bytes32 public superTokenLockable = _createContractId("superTokenLockable");
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
        Fees memory fees_
    ) AppDeployerBase(addressResolver_, auctionManager_, sbType_) {
        creationCodeWithArgs[superTokenLockable] = abi.encodePacked(
            type(SuperTokenLockable).creationCode,
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

        _setOverrides(fees_);
        _initializeOwner(owner_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(superTokenLockable, chainSlug_, true);
        _deploy(limitHook, chainSlug_, true);
    }

    // don't need to call this directly, will be called automatically after all contracts are deployed.
    // check AppDeployerBase.allPayloadsExecuted and AppGateway.queueAndDeploy
    function initialize(uint32 chainSlug_) public override async {
        address limitHookContract = getOnChainAddress(limitHook, chainSlug_);
        SuperTokenLockable(forwarderAddresses[superTokenLockable][chainSlug_]).setLimitHook(
            limitHookContract
        );
    }
}
