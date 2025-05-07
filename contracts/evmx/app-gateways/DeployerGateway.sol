// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {AppGatewayBase} from "../base/AppGatewayBase.sol";
import {PayloadSubmitParams, QueuePayloadParams} from "../../utils/common/Structs.sol";

/// @title DeployerGateway
/// @notice App gateway contract responsible for handling deployment requests
/// @dev Extends AppGatewayBase to provide deployment queueing functionality
contract DeployerGateway is AppGatewayBase {
    /// @notice Emitted when a new deployment request is queued
    /// @param bytecode The contract bytecode to deploy
    /// @param salt The deployment salt
    event DeploymentQueued(bytes bytecode, bytes32 salt);

    /// @notice Deploys a contract
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    function deploy(
        bytes32 deploymentType_,
        bytes32 contractId_,
        uint32 chainSlug_,
        IsPlug isPlug_,
        bytes memory initCallData_
    ) external {
        if (!isAsyncModifierSet) revert AsyncModifierNotUsed();

        address asyncPromise = addressResolver__.deployAsyncPromiseContract(address(this));
        IPromise(asyncPromise).then(this.setAddress.selector, abi.encode(chainSlug_, contractId_));

        isValidPromise[asyncPromise] = true;
        onCompleteData = abi.encode(chainSlug_, true);

        QueuePayloadParams memory queuePayloadParams = QueuePayloadParams({
            chainSlug: chainSlug_,
            callType: CallType.DEPLOY,
            isParallel: overrideParams.isParallelCall,
            isPlug: isPlug_,
            writeFinality: overrideParams.writeFinality,
            asyncPromise: asyncPromise,
            switchboard: watcherPrecompileConfig().switchboards(chainSlug_, sbType),
            target: address(0),
            appGateway: address(this),
            gasLimit: overrideParams.gasLimit,
            value: overrideParams.value,
            readAt: overrideParams.readAt,
            payload: creationCodeWithArgs[contractId_],
            initCallData: initCallData_
        });

        if (queuePayloadParams.payload.length > PAYLOAD_SIZE_LIMIT) revert PayloadTooLarge();
        IMiddleware(deliveryHelper__()).queue(queuePayloadParams);
    }

    /// @notice Sets the address for a deployed contract
    /// @param data_ The data
    /// @param returnData_ The return data
    function setAddress(bytes memory data_, bytes memory returnData_) external onlyPromises {
        (uint32 chainSlug, bytes32 contractId) = abi.decode(data_, (uint32, bytes32));
        address forwarderContractAddress = addressResolver__.getOrDeployForwarderContract(
            address(this),
            abi.decode(returnData_, (address)),
            chainSlug
        );

        forwarderAddresses[contractId][chainSlug] = forwarderContractAddress;
    }

    function _createDeployPayloadDetails(
        QueuePayloadParams memory queuePayloadParams_
    ) internal returns (bytes memory payload, address target) {
        bytes32 salt = keccak256(
            abi.encode(queuePayloadParams_.appGateway, queuePayloadParams_.chainSlug, saltCounter++)
        );

        // app gateway is set in the plug deployed on chain
        payload = abi.encodeWithSelector(
            IContractFactoryPlug.deployContract.selector,
            queuePayloadParams_.isPlug,
            salt,
            bytes32(uint256(uint160(queuePayloadParams_.appGateway))),
            queuePayloadParams_.switchboard,
            queuePayloadParams_.payload,
            queuePayloadParams_.initCallData
        );

        // getting app gateway for deployer as the plug is connected to the app gateway
        target = getDeliveryHelperPlugAddress(queuePayloadParams_.chainSlug);
    }
}
