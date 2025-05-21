// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IWatcher.sol";

/// @title WatcherBase
contract WatcherBase {
    // The address of the WatcherPrecompileStorage contract
    address public watcher;

    // Only WatcherPrecompileStorage can call functions
    modifier onlyWatcher() {
        require(msg.sender == watcher, "Only Watcher can call");
        _;
    }

    /// @notice Sets the WatcherPrecompileStorage address
    /// @param watcher_ The address of the WatcherPrecompileStorage contract
    constructor(address watcher_) {
        watcher = watcher_;
    }

    /// @notice Updates the WatcherPrecompileStorage address
    /// @param watcher_ The new address of the WatcherPrecompileStorage contract
    function setWatcher(address watcher_) external onlyWatcher {
        watcher = watcher_;
    }

    /// @notice Returns the configurations of the WatcherPrecompileStorage contract
    /// @return configurations The configurations of the WatcherPrecompileStorage contract
    function configurations__() external view returns (IConfigurations) {
        return IWatcher(watcher).configurations__();
    }
}
