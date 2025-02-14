// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockWatcherPrecompile} from "../../contracts/mock/MockWatcherPrecompile.sol";

contract TimeoutTest is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address watcher = vm.envAddress("WATCHER_PRECOMPILE");
        MockWatcherPrecompile watcherInstance = MockWatcherPrecompile(watcher);
        watcherInstance.setTimeout("", 10);
    }
}
