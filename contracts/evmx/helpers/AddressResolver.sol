// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import "./interfaces/IAddressResolver.sol";

abstract contract AddressResolverStorage is IAddressResolver {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    IWatcher public override watcher__;
    IFeesManager public override feesManager;
    IAsyncDeployer public override asyncDeployer;

    address public override defaultAuctionManager;

    // slots [61-110] reserved for gap
    uint256[50] _gap_after;
}

/// @title AddressResolver Contract
/// @notice This contract is responsible for fetching latest core addresses and deploying Forwarder and AsyncPromise contracts.
/// @dev Inherits the Ownable contract and implements the IAddressResolver interface.
contract AddressResolver is AddressResolverStorage, Initializable, Ownable {
    /// @notice Error thrown if AppGateway contract was already set by a different address
    error InvalidAppGateway(address contractAddress_);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @dev it deploys the forwarder and async promise implementations and beacons for them
    /// @dev this contract is owner of the beacons for upgrading later
    /// @param owner_ The address of the contract owner
    function initialize(address owner_) public reinitializer(1) {
        version = 1;
        _initializeOwner(owner_);
    }

    /// @notice Updates the address of the fees manager
    /// @param feesManager_ The address of the fees manager
    function setFeesManager(address feesManager_) external onlyOwner {
        feesManager = IFeesManager(feesManager_);
        emit FeesManagerUpdated(feesManager_);
    }

    /// @notice Updates the address of the default auction manager
    /// @param defaultAuctionManager_ The address of the default auction manager
    function setDefaultAuctionManager(address defaultAuctionManager_) external onlyOwner {
        defaultAuctionManager = defaultAuctionManager_;
        emit DefaultAuctionManagerUpdated(defaultAuctionManager_);
    }

    /// @notice Updates the address of the watcher precompile contract
    /// @param watcher_ The address of the watcher precompile contract
    function setWatcher(address watcher_) external onlyOwner {
        watcher__ = IWatcher(watcher_);
        emit WatcherUpdated(watcher_);
    }

    /// @notice Returns the address of the async deployer
    /// @return The address of the async deployer
    function setAsyncDeployer(address asyncDeployer_) external onlyOwner {
        asyncDeployer = IAsyncDeployer(asyncDeployer_);
        emit AsyncDeployerUpdated(asyncDeployer_);
    }
}
