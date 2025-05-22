// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {QueueParams, OverrideParams, Transaction} from "../../utils/common/Structs.sol";
import "./AddressResolverUtil.sol";

/// @title DeployerGateway
/// @notice App gateway contract responsible for handling deployment requests
/// @dev Extends AppGatewayBase to provide deployment queueing functionality
contract DeployForwarder is AddressResolverUtil {
    /// @notice The counter for the salt used to generate/deploy the contract address
    uint256 public saltCounter;

    /// @notice Deploys a contract
    /// @param chainSlug_ The chain slug
    function deploy(
        IsPlug isPlug_,
        uint32 chainSlug_,
        bytes memory initCallData_,
        bytes memory payload_
    ) external {
        bool isAsyncModifierSet = IAppGateway(msg.sender).isAsyncModifierSet();
        if (!isAsyncModifierSet) revert AsyncModifierNotUsed();

        // fetch the override params from app gateway
        (OverrideParams overrideParams, bytes32 sbType) = IAppGateway(msg.sender)
            .getOverrideParams();

        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;
        queueParams.switchboardType = sbType;
        queueParams.transaction = Transaction({
            chainSlug: chainSlug_,
            target: configurations__.contractFactoryPlug(chainSlug_),
            payload: _createPayload(isPlug_, msg.sender, chainSlug_, payload_, initCallData_)
        });

        watcher__().queue(queueParams, msg.sender);
    }

    function _createPayload(
        IsPlug isPlug_,
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
            bytes32(uint256(uint160(appGateway_))),
            switchboardType_,
            payload_,
            initCallData_
        );
    }
}
