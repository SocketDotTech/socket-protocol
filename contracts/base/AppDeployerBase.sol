// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {DeployParams, Fees, CallType, PayloadBatch} from "../common/Structs.sol";
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
    bytes32 public constant implementationType = keccak256("IMPLEMENTATION_DEPLOYMENT");
    bytes32 public constant proxyType = keccak256("PROXY_DEPLOYMENT");

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
    function _deploy(bytes32 contractId_, uint32 chainSlug_, bytes32 deploymentType_) internal {
        address asyncPromise = addressResolver__.deployAsyncPromiseContract(address(this));
        isValidPromise[asyncPromise] = true;
        IPromise(asyncPromise).then(this.setAddress.selector, abi.encode(chainSlug_, contractId_));

        onCompleteData = abi.encode(deploymentType_, chainSlug_);
        IDeliveryHelper(deliveryHelper()).queue(
            isCallSequential,
            chainSlug_,
            address(0),
            asyncPromise,
            CallType.DEPLOY,
            creationCodeWithArgs[contractId_]
        );
    }

    function _deployProxy(bytes32 contractId_, uint32 chainSlug_) internal {
        _deploy(contractId_, chainSlug_, proxyType);
    }

    function _deployImplementation(bytes32 contractId_, uint32 chainSlug_) internal {
        _deploy(contractId_, chainSlug_, implementationType);
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
        (bytes32 deploymentType, uint32 chainSlug) = abi.decode(payloadBatch_.onCompleteData, (bytes32, uint32));
        if (deploymentType == implementationType) {
            deployProxies(chainSlug);
        } else if (deploymentType == proxyType) {
            initialize(chainSlug);
        }
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
    function deployProxies(uint32 chainSlug_) public virtual {}
}
    