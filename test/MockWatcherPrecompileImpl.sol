// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/watcherPrecompile/WatcherPrecompile.sol";

contract MockWatcherPrecompileImpl is WatcherPrecompile {
    // Mock function to test reinitialization with version 2
    function mockReinitialize(
        address owner_,
        address addressResolver_,
        uint256 maxLimit_
    ) external reinitializer(2) {
        _setAddressResolver(addressResolver_);
        _claimOwner(owner_);
        maxTimeoutDelayInSeconds = 24 * 60 * 60; // 24 hours

        LIMIT_DECIMALS = 18;

        // limit per day
        maxLimit = maxLimit_ * 10 ** LIMIT_DECIMALS;
        // limit per second
        ratePerSecond = maxLimit / (24 * 60 * 60);
    }
}
