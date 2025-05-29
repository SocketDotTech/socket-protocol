// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import "../interfaces/IAddressResolver.sol";

abstract contract AddressResolverStorage is IAddressResolver {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    IWatcher public override watcher__;

    // slot 51
    IFeesManager public override feesManager__;

    // slot 52
    IAsyncDeployer public override asyncDeployer__;

    // slot 53
    IDeployForwarder public override deployForwarder__;

    // slot 54
    address public override defaultAuctionManager;

    // slot 55
    mapping(bytes32 => address) public override contractAddresses;

    // slots [56-105] reserved for gap
    uint256[50] _gap_after;
}

/// @title AddressResolver Contract
/// @notice This contract is responsible for fetching latest core addresses and deploying Forwarder and AsyncPromise contracts.
/// @dev Inherits the Ownable contract and implements the IAddressResolver interface.
contract AddressResolver is AddressResolverStorage, Initializable, Ownable {
    /// @notice Constructor to initialize the contract
    /// @dev it deploys the forwarder and async promise implementations and beacons for them
    /// @dev this contract is owner of the beacons for upgrading later
    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @dev it deploys the forwarder and async promise implementations and beacons for them
    /// @dev this contract is owner of the beacons for upgrading later
    /// @param owner_ The address of the contract owner
    function initialize(address owner_) public reinitializer(1) {
        _initializeOwner(owner_);
    }

    /// @notice Updates the address of the watcher contract
    /// @param watcher_ The address of the watcher contract
    function setWatcher(address watcher_) external override onlyOwner {
        watcher__ = IWatcher(watcher_);
        emit WatcherUpdated(watcher_);
    }

    /// @notice Updates the address of the fees manager
    /// @param feesManager_ The address of the fees manager
    function setFeesManager(address feesManager_) external override onlyOwner {
        feesManager__ = IFeesManager(feesManager_);
        emit FeesManagerUpdated(feesManager_);
    }

    /// @notice Updates the address of the async deployer
    /// @param asyncDeployer_ The address of the async deployer
    function setAsyncDeployer(address asyncDeployer_) external override onlyOwner {
        asyncDeployer__ = IAsyncDeployer(asyncDeployer_);
        emit AsyncDeployerUpdated(asyncDeployer_);
    }

    /// @notice Updates the address of the default auction manager
    /// @param defaultAuctionManager_ The address of the default auction manager
    function setDefaultAuctionManager(address defaultAuctionManager_) external override onlyOwner {
        defaultAuctionManager = defaultAuctionManager_;
        emit DefaultAuctionManagerUpdated(defaultAuctionManager_);
    }

    /// @notice Updates the address of the deploy forwarder
    /// @param deployForwarder_ The address of the deploy forwarder
    function setDeployForwarder(address deployForwarder_) external override onlyOwner {
        deployForwarder__ = IDeployForwarder(deployForwarder_);
        emit DeployForwarderUpdated(deployForwarder_);
    }

    /// @notice Updates the address of a contract
    /// @param contractId_ The id of the contract
    /// @param contractAddress_ The address of the contract
    function setContractAddress(
        bytes32 contractId_,
        address contractAddress_
    ) external override onlyOwner {
        contractAddresses[contractId_] = contractAddress_;
        emit ContractAddressUpdated(contractId_, contractAddress_);
    }
}
