// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ParallelCounterDeployer} from "../../contracts/apps/parallel-counter/ParallelCounterDeployer.sol";
import {Counter} from "../../contracts/apps/counter/Counter.sol";

contract CheckCounters is Script {
    function run() external {
        ParallelCounterDeployer deployer = ParallelCounterDeployer(vm.envAddress("DEPLOYER"));

        vm.createSelectFork(vm.envString("EVMX_RPC"));
        address counter1InstanceArbitrumSepolia = deployer.getOnChainAddress(
            deployer.counter1(),
            421614
        );
        address counter2InstanceArbitrumSepolia = deployer.getOnChainAddress(
            deployer.counter2(),
            421614
        );
        address counter1InstanceOptimismSepolia = deployer.getOnChainAddress(
            deployer.counter1(),
            11155420
        );
        address counter2InstanceOptimismSepolia = deployer.getOnChainAddress(
            deployer.counter2(),
            11155420
        );

        if (counter1InstanceArbitrumSepolia != address(0)) {
            vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));
            console.log("Counter 1 instance on Arbitrum Sepolia:", counter1InstanceArbitrumSepolia);
            uint256 counterValueArbitrumSepolia = Counter(counter1InstanceArbitrumSepolia)
                .counter();
            console.log("Counter1 value on Arbitrum Sepolia: ", counterValueArbitrumSepolia);
        } else {
            console.log("Counter1 not yet deployed on Arbitrum Sepolia");
        }

        if (counter2InstanceArbitrumSepolia != address(0)) {
            vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));
            console.log("Counter 2 instance on Arbitrum Sepolia:", counter2InstanceArbitrumSepolia);
            uint256 counterValueArbitrumSepolia = Counter(counter2InstanceArbitrumSepolia)
                .counter();
            console.log("Counter2 value on Arbitrum Sepolia: ", counterValueArbitrumSepolia);
        } else {
            console.log("Counter2 not yet deployed on Arbitrum Sepolia");
        }

        if (counter1InstanceOptimismSepolia != address(0)) {
            vm.createSelectFork(vm.envString("OPTIMISM_SEPOLIA_RPC"));
            console.log("Counter 1 instance on Optimism Sepolia:", counter1InstanceOptimismSepolia);
            uint256 counterValueOptimismSepolia = Counter(counter1InstanceOptimismSepolia)
                .counter();
            console.log("Counter1 value on Optimism Sepolia: ", counterValueOptimismSepolia);
        } else {
            console.log("Counter1 not yet deployed on Optimism Sepolia");
        }

        if (counter2InstanceOptimismSepolia != address(0)) {
            vm.createSelectFork(vm.envString("OPTIMISM_SEPOLIA_RPC"));
            console.log("Counter 2 instance on Optimism Sepolia:", counter2InstanceOptimismSepolia);
            uint256 counterValueOptimismSepolia = Counter(counter2InstanceOptimismSepolia)
                .counter();
            console.log("Counter2 value on Optimism Sepolia: ", counterValueOptimismSepolia);
        } else {
            console.log("Counter2 not yet deployed on Optimism Sepolia");
        }

        vm.createSelectFork(vm.envString("EVMX_RPC"));
        address forwarderArb1 = deployer.forwarderAddresses(deployer.counter1(), 421614);
        address forwarderArb2 = deployer.forwarderAddresses(deployer.counter2(), 421614);
        address forwarderOpt1 = deployer.forwarderAddresses(deployer.counter1(), 11155420);
        address forwarderOpt2 = deployer.forwarderAddresses(deployer.counter2(), 11155420);

        console.log("Forwarder 1 on Arbitrum Sepolia:", forwarderArb1);
        console.log("Forwarder 2 on Arbitrum Sepolia:", forwarderArb2);
        console.log("Forwarder 1 on Optimism Sepolia:", forwarderOpt1);
        console.log("Forwarder 2 on Optimism Sepolia:", forwarderOpt2);
    }
}
