// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockWatcherPrecompile} from "../../test/mock/MockWatcherPrecompile.sol";
import {MockSocket} from "../../test/mock/MockSocket.sol";

contract DeployEVMx is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MockWatcherPrecompile watcher = new MockWatcherPrecompile(address(0), address(0));
        console.log("MockWatcherPrecompile:", address(watcher));
    }
}
