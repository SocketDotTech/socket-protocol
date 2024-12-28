// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterDeployer} from "../../contracts/apps/counter/CounterDeployer.sol";
import {Counter} from "../../contracts/apps//counter/Counter.sol";

contract CheckCounters is Script {
    function run() external {
        CounterDeployer deployer = CounterDeployer(vm.envAddress("COUNTER_DEPLOYER"));

        vm.createSelectFork(vm.envString("OFF_CHAIN_VM_RPC"));
        address counterInstanceArbitrumSepolia = deployer.getOnChainAddress(deployer.counter(), 421614);
        address counterInstanceOptimismSepolia = deployer.getOnChainAddress(deployer.counter(), 11155420);
        address counterInstanceBaseSepolia = deployer.getOnChainAddress(deployer.counter(), 84532);
        //address counterInstanceSepolia = deployer.getOnChainAddress(
        //    deployer.counter(),
        //    11155111
        //);

        if (counterInstanceArbitrumSepolia != address(0)) {
            vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));
            uint256 counterValueArbitrumSepolia = Counter(counterInstanceArbitrumSepolia).counter();
            console.log("Counter value on Arbitrum Sepolia: ", counterValueArbitrumSepolia);
        } else {
            console.log("Counter not yet deployed on Arbitrum Sepolia");
        }

        if (counterInstanceOptimismSepolia != address(0)) {
            vm.createSelectFork(vm.envString("OPTIMISM_SEPOLIA_RPC"));
            uint256 counterValueOptimismSepolia = Counter(counterInstanceOptimismSepolia).counter();
            console.log("Counter value on Optimism Sepolia: ", counterValueOptimismSepolia);
        } else {
            console.log("Counter not yet deployed on Optimism Sepolia");
        }

        if (counterInstanceBaseSepolia != address(0)) {
            vm.createSelectFork(vm.envString("BASE_SEPOLIA_RPC"));
            uint256 counterValueBaseSepolia = Counter(counterInstanceBaseSepolia).counter();
            console.log("Counter value on Base Sepolia: ", counterValueBaseSepolia);
        } else {
            console.log("Counter not yet deployed on Base Sepolia");
        }

        //if (counterInstanceSepolia != address(0)) {
        //    vm.createSelectFork(vm.envString("SEPOLIA_RPC"));
        //    uint256 counterValueOptimismSepolia = Counter(
        //        counterInstanceOptimismSepolia
        //    ).counter();
        //    console.log(
        //        "Counter value on Ethereum Sepolia: ",
        //        counterValueOptimismSepolia
        //    );
        //} else {
        //    console.log("Counter not yet deployed on Ethereum Sepolia");
        //}
    }
}
