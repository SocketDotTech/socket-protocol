// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockWatcherPrecompile} from "../../contracts/mock/MockWatcherPrecompile.sol";
import {MockSocket} from "../../contracts/mock/MockSocket.sol";
contract DeployVM is Script {
    function run() external {
        string memory rpc = vm.envString("OFF_CHAIN_VM_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MockWatcherPrecompile watcher = new MockWatcherPrecompile(
            address(0),
            address(0)
        );
        console.log("MockWatcherPrecompile:", address(watcher));
    }
}
