// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../contracts/apps/counter/CounterAppGateway.sol";
import {Counter} from "../../contracts/apps/counter/Counter.sol";

contract CheckCounters is Script {
    function run() external {
        CounterAppGateway gateway = CounterAppGateway(vm.envAddress("APP_GATEWAY"));

        vm.createSelectFork(vm.envString("EVMX_RPC"));
        address counterInstanceArbitrumSepolia = gateway.getOnChainAddress(
            gateway.counter(),
            421614
        );
        address counter1InstanceArbitrumSepolia = gateway.getOnChainAddress(
            gateway.counter1(),
            421614
        );
        address counterInstanceOptimismSepolia = gateway.getOnChainAddress(
            gateway.counter(),
            11155420
        );
        address counter1InstanceOptimismSepolia = gateway.getOnChainAddress(
            gateway.counter1(),
            11155420
        );

        if (counterInstanceArbitrumSepolia != address(0)) {
            vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));
            console.log("Counter 1 instance on Arbitrum Sepolia:", counterInstanceArbitrumSepolia);
            uint256 counterValueArbitrumSepolia = Counter(counterInstanceArbitrumSepolia).counter();
            console.log("Counter1 value on Arbitrum Sepolia: ", counterValueArbitrumSepolia);
        } else {
            console.log("Counter1 not yet deployed on Arbitrum Sepolia");
        }

        if (counter1InstanceArbitrumSepolia != address(0)) {
            vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));
            console.log("Counter 2 instance on Arbitrum Sepolia:", counter1InstanceArbitrumSepolia);
            uint256 counterValueArbitrumSepolia = Counter(counter1InstanceArbitrumSepolia)
                .counter();
            console.log("Counter2 value on Arbitrum Sepolia: ", counterValueArbitrumSepolia);
        } else {
            console.log("Counter2 not yet deployed on Arbitrum Sepolia");
        }

        if (counterInstanceOptimismSepolia != address(0)) {
            vm.createSelectFork(vm.envString("OPTIMISM_SEPOLIA_RPC"));
            console.log("Counter 1 instance on Optimism Sepolia:", counterInstanceOptimismSepolia);
            uint256 counterValueOptimismSepolia = Counter(counterInstanceOptimismSepolia).counter();
            console.log("Counter1 value on Optimism Sepolia: ", counterValueOptimismSepolia);
        } else {
            console.log("Counter1 not yet deployed on Optimism Sepolia");
        }

        if (counter1InstanceOptimismSepolia != address(0)) {
            vm.createSelectFork(vm.envString("OPTIMISM_SEPOLIA_RPC"));
            console.log("Counter 2 instance on Optimism Sepolia:", counter1InstanceOptimismSepolia);
            uint256 counterValueOptimismSepolia = Counter(counter1InstanceOptimismSepolia)
                .counter();
            console.log("Counter2 value on Optimism Sepolia: ", counterValueOptimismSepolia);
        } else {
            console.log("Counter2 not yet deployed on Optimism Sepolia");
        }

        vm.createSelectFork(vm.envString("EVMX_RPC"));
        address forwarderArb1 = gateway.forwarderAddresses(gateway.counter(), 421614);
        address forwarderArb2 = gateway.forwarderAddresses(gateway.counter1(), 421614);
        address forwarderOpt1 = gateway.forwarderAddresses(gateway.counter(), 11155420);
        address forwarderOpt2 = gateway.forwarderAddresses(gateway.counter1(), 11155420);

        console.log("Forwarder 1 on Arbitrum Sepolia:", forwarderArb1);
        console.log("Forwarder 2 on Arbitrum Sepolia:", forwarderArb2);
        console.log("Forwarder 1 on Optimism Sepolia:", forwarderOpt1);
        console.log("Forwarder 2 on Optimism Sepolia:", forwarderOpt2);
    }
}
