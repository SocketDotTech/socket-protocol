// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Counter} from "../../test/apps/app-gateways/counter/Counter.sol";
import {CounterAppGateway} from "../../test/apps/app-gateways/counter/CounterAppGateway.sol";
import {fromBytes32Format} from "../../contracts/utils/common/Converters.sol";

contract CheckCounters is Script {
    function run() external {
        CounterAppGateway gateway = CounterAppGateway(vm.envAddress("APP_GATEWAY"));

        vm.createSelectFork(vm.envString("EVMX_RPC"));
        address counterInstanceArbitrumSepolia = fromBytes32Format(
            gateway.getOnChainAddress(gateway.counter(), 421614)
        );
        address counterInstanceOptimismSepolia = fromBytes32Format(
            gateway.getOnChainAddress(gateway.counter(), 11155420)
        );
        address counterInstanceBaseSepolia = fromBytes32Format(
            gateway.getOnChainAddress(gateway.counter(), 84532)
        );

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
    }
}
