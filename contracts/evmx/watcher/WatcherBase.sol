// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IWatcher.sol";
import "../interfaces/IConfigurations.sol";
import "../interfaces/IPromiseResolver.sol";
import "../interfaces/IRequestHandler.sol";

/// @title WatcherBase
/// @notice Base contract for the Watcher contract
contract WatcherBase {
    // The address of the Watcher contract
    IWatcher public watcher__;

    // Only Watcher can call functions
    modifier onlyWatcher() {
        require(msg.sender == address(watcher__), "Only Watcher can call");
        _;
    }

    modifier onlyRequestHandler() {
        require(msg.sender == address(requestHandler__()), "Only RequestHandler can call");
        _;
    }

    modifier onlyPromiseResolver() {
        require(msg.sender == address(promiseResolver__()), "Only PromiseResolver can call");
        _;
    }

    /// @notice Sets the Watcher address
    /// @param watcher_ The address of the Watcher contract
    constructor(address watcher_) {
        watcher__ = IWatcher(watcher_);
    }

    /// @notice Returns the configurations of the Watcher contract
    /// @return configurations The configurations of the Watcher contract
    function configurations__() internal view returns (IConfigurations) {
        return watcher__.configurations__();
    }

    /// @notice Returns the promise resolver of the Watcher contract
    /// @return promiseResolver The promise resolver of the Watcher contract
    function promiseResolver__() internal view returns (IPromiseResolver) {
        return watcher__.promiseResolver__();
    }

    /// @notice Returns the request handler of the Watcher contract
    /// @return requestHandler The request handler of the Watcher contract
    function requestHandler__() internal view returns (IRequestHandler) {
        return watcher__.requestHandler__();
    }
}
