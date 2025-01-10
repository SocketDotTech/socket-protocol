// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CronAppGateway} from "../../contracts/apps/cron/CronAppGateway.sol";

contract SetTimeoutScript is Script {
    function run() external {
        string memory socketRPC = vm.envString("OFF_CHAIN_VM_RPC");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork(socketRPC);
        address gatewayAddress = vm.envAddress("CRON_APP_GATEWAY");
        console.log("Gateway address:", gatewayAddress);
        CronAppGateway gateway = CronAppGateway(gatewayAddress);
        vm.startBroadcast(deployerPrivateKey);
        gateway.setTimeout(0);
        // vm.stopBroadcast();
    }
}
