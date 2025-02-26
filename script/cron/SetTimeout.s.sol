// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../contracts/apps/counter/CounterAppGateway.sol";

contract SetTimeoutScript is Script {
    function run() external {
        string memory socketRPC = vm.envString("EVMX_RPC");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork(socketRPC);
        address gatewayAddress = vm.envAddress("APP_GATEWAY");
        console.log("Gateway address:", gatewayAddress);
        CounterAppGateway gateway = CounterAppGateway(gatewayAddress);
        vm.startBroadcast(deployerPrivateKey);
        gateway.setTimeout(0);
        // vm.stopBroadcast();
    }
}
