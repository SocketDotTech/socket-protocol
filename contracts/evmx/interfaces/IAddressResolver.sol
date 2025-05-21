// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;
import "./IWatcher.sol";
import "./IFeesManager.sol";
import "./IAsyncDeployer.sol";

/// @title IAddressResolver
/// @notice Interface for resolving system contract addresses
/// @dev Provides address lookup functionality for core system components
interface IAddressResolver {
    /// @notice Event emitted when the fees manager is updated
    event FeesManagerUpdated(address feesManager_);
    /// @notice Event emitted when the watcher precompile is updated
    event WatcherUpdated(address watcher_);

    // any other address resolution
    function getAddress(bytes32 name) external view returns (address);

    function setAddress(bytes32 name, address addr) external;

    // System component addresses
    function watcher__() external view returns (IWatcher);

    function feesManager__() external view returns (IFeesManager);

    function asyncDeployer__() external view returns (IAsyncDeployer);

    function defaultAuctionManager() external view returns (address);

    function setFeesManager(address feesManager_) external;

    function setDefaultAuctionManager(address defaultAuctionManager_) external;

    function setWatcher(address watcher_) external;

    function setAsyncDeployer(address asyncDeployer_) external;
}
