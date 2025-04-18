// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../contracts/protocol/watcherPrecompile/core/WatcherPrecompile.sol";

contract MockWatcherPrecompileImpl is WatcherPrecompile {
    // Mock function to test reinitialization with version 2
    function mockReinitialize(address owner_, address addressResolver_) external reinitializer(2) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
        maxTimeoutDelayInSeconds = 24 * 60 * 60; // 24 hours
    }
}
