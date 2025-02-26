// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../contracts/apps/counter/CounterAppGateway.sol";

contract CheckGatewayCounter is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        address gatewayAddress = vm.envAddress("APP_GATEWAY");
        CounterAppGateway gateway = CounterAppGateway(gatewayAddress);

        // Log the value of the counter variable on CounterAppGateway
        uint256 counterValue = gateway.counterVal();
        console.log("Counter value on CounterAppGateway:");
        console.log(counterValue);
    }
}
