// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {DeployParams, FeesData, CallType, PayloadBatch} from "../common/Structs.sol";
import {AppGatewayBase} from "./AppGatewayBase.sol";
import {IForwarder} from "../interfaces/IForwarder.sol";
import {IPromise} from "../interfaces/IPromise.sol";
import {IAppDeployer} from "../interfaces/IAppDeployer.sol";
import {IDeliveryHelper} from "../interfaces/IDeliveryHelper.sol";

/// @title AppDeployerBase
/// @notice Abstract contract for deploying applications
abstract contract AppDeployerBase is AppGatewayBase, IAppDeployer {
    mapping(bytes32 => mapping(uint32 => address)) public override forwarderAddresses;
    mapping(bytes32 => bytes) public creationCodeWithArgs;

    constructor(
        address addressResolver_,
        address auctionManager_,
        bytes32 sbType_
    ) AppGatewayBase(addressResolver_, auctionManager_) {
        sbType = sbType_;
    }

    /// @notice Deploys a contract
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    function _deploy(bytes32 contractId_, uint32 chainSlug_) internal {
        address asyncPromise = addressResolver__.deployAsyncPromiseContract(address(this));
        isValidPromise[asyncPromise] = true;
        IPromise(asyncPromise).then(this.setAddress.selector, abi.encode(chainSlug_, contractId_));

        onCompleteData = abi.encode(chainSlug_);
        IDeliveryHelper(deliveryHelper()).queue(
            isCallSequential,
            chainSlug_,
            address(0),
            asyncPromise,
            CallType.DEPLOY,
            creationCodeWithArgs[contractId_]
        );
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

    /// @notice Gets the on-chain address
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    /// @return onChainAddress The on-chain address
    function getOnChainAddress(
        bytes32 contractId_,
        uint32 chainSlug_
    ) public view returns (address onChainAddress) {
        if (forwarderAddresses[contractId_][chainSlug_] == address(0)) {
            return address(0);
        }

        onChainAddress = IForwarder(forwarderAddresses[contractId_][chainSlug_])
            .getOnChainAddress();
    }

    /// @notice Callback in pd promise to be called after all contracts are deployed
    /// @param payloadBatch_ The payload batch
    /// @dev only payload delivery can call this
    /// @dev callback in pd promise to be called after all contracts are deployed
    function onBatchComplete(
        bytes32,
        PayloadBatch memory payloadBatch_
    ) external override onlyDeliveryHelper {
        uint32 chainSlug = abi.decode(payloadBatch_.onCompleteData, (uint32));
        initialize(chainSlug);
    }

    /// @notice Gets the socket address
    /// @param chainSlug_ The chain slug
    /// @return socketAddress_ The socket address
    function getSocketAddress(uint32 chainSlug_) public view returns (address) {
        return
            watcherPrecompile__().appGatewayPlugs(addressResolver__.deliveryHelper(), chainSlug_);
    }

    /// @notice Initializes the contract
    /// @param chainSlug_ The chain slug
    function initialize(uint32 chainSlug_) public virtual {}
}
