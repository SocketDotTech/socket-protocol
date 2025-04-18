// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockWatcherPrecompile} from "../../../test/mock/MockWatcherPrecompile.sol";

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
