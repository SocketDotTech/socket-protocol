// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;
import "./IWatcher.sol";
import "./IFeesManager.sol";
import "./IAsyncDeployer.sol";
import "./IDeployForwarder.sol";

/// @title IAddressResolver
/// @notice Interface for resolving system contract addresses
/// @dev Provides address lookup functionality for core system components
interface IAddressResolver {
    /// @notice Event emitted when the fees manager is updated
    event FeesManagerUpdated(address feesManager_);
    /// @notice Event emitted when the watcher precompile is updated
    event WatcherUpdated(address watcher_);
    /// @notice Event emitted when the async deployer is updated
    event AsyncDeployerUpdated(address asyncDeployer_);
    /// @notice Event emitted when the default auction manager is updated
    event DefaultAuctionManagerUpdated(address defaultAuctionManager_);
    /// @notice Event emitted when the deploy forwarder is updated
    event DeployForwarderUpdated(address deployForwarder_);
    /// @notice Event emitted when the contract address is updated
    event ContractAddressUpdated(bytes32 contractId_, address contractAddress_);

    // System component addresses
    function watcher__() external view returns (IWatcher);

    function feesManager__() external view returns (IFeesManager);

    function asyncDeployer__() external view returns (IAsyncDeployer);

    function defaultAuctionManager() external view returns (address);

    function deployForwarder__() external view returns (IDeployForwarder);

    function contractAddresses(bytes32 contractId_) external view returns (address);

    function setWatcher(address watcher_) external;

    function setFeesManager(address feesManager_) external;

    function setAsyncDeployer(address asyncDeployer_) external;

    function setDefaultAuctionManager(address defaultAuctionManager_) external;

    function setDeployForwarder(address deployForwarder_) external;

    function setContractAddress(bytes32 contractId_, address contractAddress_) external;
}
