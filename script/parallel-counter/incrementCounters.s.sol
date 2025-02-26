// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterDeployer} from "../../contracts/apps//counter/CounterDeployer.sol";
import {CounterAppGateway} from "../../contracts/apps//counter/CounterAppGateway.sol";

contract IncrementCounters is Script {
    function run() external {
        string memory socketRPC = vm.envString("EVMX_RPC");

        vm.createSelectFork(socketRPC);

        CounterDeployer deployer = CounterDeployer(vm.envAddress("COUNTER_DEPLOYER"));
        CounterAppGateway gateway = CounterAppGateway(vm.envAddress("COUNTER_APP_GATEWAY"));

        address counterForwarderArbitrumSepolia = deployer.forwarderAddresses(
            deployer.counter(),
            421614
        );
        address counterForwarderOptimismSepolia = deployer.forwarderAddresses(
            deployer.counter(),
            11155420
        );
        address counterForwarderBaseSepolia = deployer.forwarderAddresses(
            deployer.counter(),
            84532
        );
        //address counterForwarderSepolia = deployer.forwarderAddresses(
        //    deployer.counter(),
        //    11155111
        //);

        // Count non-zero addresses
        uint256 nonZeroCount = 0;
        if (counterForwarderArbitrumSepolia != address(0)) nonZeroCount++;
        if (counterForwarderOptimismSepolia != address(0)) nonZeroCount++;
        if (counterForwarderBaseSepolia != address(0)) nonZeroCount++;
        //if (counterForwarderSepolia != address(0)) nonZeroCount++;

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
        //if (counterForwarderSepolia != address(0)) {
        //    instances[index] = counterForwarderSepolia;
        //    index++;
        //} else {
        //    console.log("Ethereum Sepolia forwarder not yet deployed");
        //}

        // vm.startBroadcast(deployerPrivateKey);
        bytes memory data = abi.encodeWithSelector(
            CounterAppGateway.incrementCounters.selector,
            instances
        );
        console.log("to");
        console.log(address(gateway));
        console.log("data");
        console.logBytes(data);
        // gateway.incrementCounters(instances);
    }
}
