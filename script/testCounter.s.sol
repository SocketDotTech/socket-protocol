// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TestCounter} from "../contracts/TestCounter.sol";
import {MultiCall} from "../contracts/MultiCall.sol";
import {console} from "forge-std/console.sol";
contract TestCounterScript is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        console.log(rpc);
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TestCounter testCounter = new TestCounter();

        console.log("Test Counter:", address(testCounter));

        MultiCall multiCall = new MultiCall();
        console.log("Multi Call:", address(multiCall));

        console.logBytes(abi.encodeCall(TestCounter.switchOn, ()));
        console.logBytes(abi.encodeCall(TestCounter.switchOff, ()));
    }
}
