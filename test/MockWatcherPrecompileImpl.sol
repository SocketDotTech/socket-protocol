// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/protocol/watcherPrecompile/WatcherPrecompile.sol";

contract MockWatcherPrecompileImpl is WatcherPrecompile {
    // Mock function to test reinitialization with version 2
    function mockReinitialize(
        address owner_,
        address addressResolver_,
        uint256 defaultLimit_
    ) external reinitializer(2) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
        maxTimeoutDelayInSeconds = 24 * 60 * 60; // 24 hours

        LIMIT_DECIMALS = 18;

        // limit per day
        defaultLimit = defaultLimit_ * 10 ** LIMIT_DECIMALS;
        // limit per second
        defaultRatePerSecond = defaultLimit / (24 * 60 * 60);
    }
}
