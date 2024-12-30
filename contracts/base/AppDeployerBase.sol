// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {DeployParams, FeesData, CallType} from "../common/Structs.sol";
import {AppGatewayBase} from "./AppGatewayBase.sol";
import {IForwarder} from "../interfaces/IForwarder.sol";
import {IAppDeployer} from "../interfaces/IAppDeployer.sol";
import {IAuctionHouse} from "../interfaces/IAuctionHouse.sol";

/// @title AppDeployerBase
/// @notice Abstract contract for deploying applications
abstract contract AppDeployerBase is AppGatewayBase, IAppDeployer {
    mapping(bytes32 => mapping(uint32 => address)) public forwarderAddresses;
    mapping(bytes32 => bytes) public creationCodeWithArgs;

    constructor(address _addressResolver) AppGatewayBase(_addressResolver) {}

    /// @notice Deploys a contract
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    function _deploy(bytes32 contractId_, uint32 chainSlug_) internal {
        address asyncPromise = IAddressResolver(addressResolver)
            .deployAsyncPromiseContract(address(this));

        isValidPromise[asyncPromise] = true;
        IPromise(asyncPromise).then(
            this.setAddress.selector,
            abi.encode(chainSlug_, contractId_)
        );

        IAuctionHouse(auctionHouse()).queue(
            chainSlug_,
            address(0),
            // hacked for contract addr, need to revisit
            asyncPromise,
            CallType.DEPLOY,
            creationCodeWithArgs[contractId_]
        );
    }

    /// @notice Sets the address for a deployed contract
    /// @param data_ The data
    /// @param returnData_ The return data
    function setAddress(
        bytes memory data_,
        bytes memory returnData_
    ) external onlyPromises {
        (uint32 chainSlug, bytes32 contractId) = abi.decode(
            data_,
            (uint32, bytes32)
        );

        address forwarderContractAddress = addressResolver
            .getOrDeployForwarderContract(
                abi.decode(returnData_, (address)),
                chainSlug
            );

        forwarderAddresses[contractId][chainSlug] = forwarderContractAddress;
    }

    /// @notice Gets the on-chain address
    /// @param contractId The contract ID
    /// @param chainSlug The chain slug
    /// @return onChainAddress The on-chain address
    function getOnChainAddress(
        bytes32 contractId,
        uint32 chainSlug
    ) public view returns (address onChainAddress) {
        if (forwarderAddresses[contractId][chainSlug] == address(0)) {
            return address(0);
        }

        onChainAddress = IForwarder(forwarderAddresses[contractId][chainSlug])
            .getOnChainAddress();
    }

    /// @notice Callback in pd promise to be called after all contracts are deployed
    /// @param chainSlug The chain slug
    /// @dev only payload delivery can call this
    /// @dev callback in pd promise to be called after all contracts are deployed
    function allContractsDeployed(
        uint32 chainSlug
    ) external override onlyPayloadDelivery {
        initialize(chainSlug);
    }

    /// @notice Gets the socket address
    /// @param chainSlug The chain slug
    /// @return socketAddress The socket address
    function getSocketAddress(uint32 chainSlug) public view returns (address) {
        return
            watcherPrecompile().appGatewayPlugs(
                addressResolver.auctionHouse(),
                chainSlug
            );
    }

    /// @notice Initializes the contract
    /// @param chainSlug The chain slug
    function initialize(uint32 chainSlug) public virtual {}
}
