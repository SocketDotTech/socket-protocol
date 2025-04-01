// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../test/apps/app-gateways/counter/CounterAppGateway.sol";

// source .env && forge script script/counter/IncrementCountersFromApp.s.sol --broadcast --skip-simulation --legacy --gas-price 0
// source .env && cast send $APP_GATEWAY "incrementCounters(address[])" '[0xdA908E7491499d64944Ea5Dc967135a0F22d2057]' --private-key $PRIVATE_KEY --legacy --gas-price 0
contract IncrementCounters is Script {
    function run() external {
        string memory socketRPC = vm.envString("EVMX_RPC");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(socketRPC);

        CounterAppGateway gateway = CounterAppGateway(vm.envAddress("APP_GATEWAY"));

        address counterForwarderArbitrumSepolia = gateway.forwarderAddresses(
            gateway.counter(),
            421614
        );
        address counterForwarderOptimismSepolia = gateway.forwarderAddresses(
            gateway.counter(),
            11155420
        );
        address counterForwarderBaseSepolia = gateway.forwarderAddresses(gateway.counter(), 84532);

        // Count non-zero addresses
        uint256 nonZeroCount = 0;
        if (counterForwarderArbitrumSepolia != address(0)) nonZeroCount++;
        if (counterForwarderOptimismSepolia != address(0)) nonZeroCount++;
        if (counterForwarderBaseSepolia != address(0)) nonZeroCount++;

        address[] memory instances = new address[](nonZeroCount);
        uint256 index = 0;
        if (counterForwarderArbitrumSepolia != address(0)) {
            instances[index] = counterForwarderArbitrumSepolia;
            index++;
        } else {
            console.log("Arbitrum Sepolia forwarder not yet deployed");
        }
        if (counterForwarderOptimismSepolia != address(0)) {
            instances[index] = counterForwarderOptimismSepolia;
            index++;
        } else {
            console.log("Optimism Sepolia forwarder not yet deployed");
        }
        if (counterForwarderBaseSepolia != address(0)) {
            instances[index] = counterForwarderBaseSepolia;
            index++;
        } else {
            console.log("Base Sepolia forwarder not yet deployed");
        }

        vm.startBroadcast(deployerPrivateKey);
        gateway.incrementCounters(instances);
    }
}
