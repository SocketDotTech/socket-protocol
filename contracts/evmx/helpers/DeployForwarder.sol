// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {IAppGateway} from "../interfaces/IAppGateway.sol";
import {IContractFactoryPlug} from "../interfaces/IContractFactoryPlug.sol";
import {IDeployForwarder} from "../interfaces/IDeployForwarder.sol";
import "./AddressResolverUtil.sol";
import {AsyncModifierNotSet} from "../../utils/common/Errors.sol";
import {QueueParams, OverrideParams, Transaction} from "../../utils/common/Structs.sol";
import {encodeAppGatewayId} from "../../utils/common/IdUtils.sol";

/// @title DeployerGateway
/// @notice App gateway contract responsible for handling deployment requests
/// @dev Extends AppGatewayBase to provide deployment queueing functionality
contract DeployForwarder is AddressResolverUtil, IDeployForwarder {
    /// @notice The counter for the salt used to generate/deploy the contract address
    uint256 public override saltCounter;

    bytes32 public override deployerSwitchboardType;

    constructor(address addressResolver_, bytes32 deployerSwitchboardType_) {
        _setAddressResolver(addressResolver_);
        deployerSwitchboardType = deployerSwitchboardType_;
    }

    /// @notice Deploys a contract
    /// @param chainSlug_ The chain slug
    function deploy(
        IsPlug isPlug_,
        uint32 chainSlug_,
        bytes memory initCallData_,
        bytes memory payload_
    ) external {
        address msgSender = msg.sender;
        bool isAsyncModifierSet = IAppGateway(msgSender).isAsyncModifierSet();
        if (!isAsyncModifierSet) revert AsyncModifierNotSet();

        // fetch the override params from app gateway
        (OverrideParams memory overrideParams, bytes32 plugSwitchboardType) = IAppGateway(msgSender)
            .getOverrideParams();

        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;
        queueParams.switchboardType = deployerSwitchboardType;
        queueParams.transaction = Transaction({
            chainSlug: chainSlug_,
            target: address(0),
            payload: _createPayload(
                isPlug_,
                plugSwitchboardType,
                msgSender,
                chainSlug_,
                payload_,
                initCallData_
            )
        });

        watcher__().queue(queueParams, msg.sender);
    }

    function _createPayload(
        IsPlug isPlug_,
        bytes32 plugSwitchboardType_,
        address appGateway_,
        uint32 chainSlug_,
        bytes memory payload_,
        bytes memory initCallData_
    ) internal returns (bytes memory payload) {
        bytes32 salt = keccak256(abi.encode(appGateway_, chainSlug_, saltCounter++));

        // app gateway is set in the plug deployed on chain
        payload = abi.encodeWithSelector(
            IContractFactoryPlug.deployContract.selector,
            isPlug_,
            salt,
            encodeAppGatewayId(appGateway_),
            watcher__().configurations__().switchboards(chainSlug_, plugSwitchboardType_),
            payload_,
            initCallData_
        );
    }
}
