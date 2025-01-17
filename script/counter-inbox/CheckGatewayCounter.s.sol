// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterInboxAppGateway} from "../../contracts/apps/counter-inbox/CounterInboxAppGateway.sol";

contract CheckGatewayCounter is Script {
    function run() external {
        string memory rpc = vm.envString("OFF_CHAIN_VM_RPC");
        vm.createSelectFork(rpc);

        address gatewayAddress = vm.envAddress("APP_GATEWAY");
        CounterInboxAppGateway gateway = CounterInboxAppGateway(gatewayAddress);

        // Log the value of the counter variable on CounterInboxAppGateway
        uint256 counterValue = gateway.counter();
        console.log("Counter value on CounterInboxAppGateway:");
        console.log(counterValue);
    }
}
