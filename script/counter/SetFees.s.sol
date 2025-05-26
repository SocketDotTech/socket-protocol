// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../test/apps/app-gateways/counter/CounterAppGateway.sol";

// source .env && forge script script/counter/DeployCounterOnchain.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract CounterSetFees is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        console.log(rpc);
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CounterAppGateway appGateway = CounterAppGateway(vm.envAddress("APP_GATEWAY"));
        console.log("Counter Gateway:", address(appGateway));

        console.log("Setting fees...");
        // Setting fee payment on Arbitrum Sepolia
        uint256 fees = 0.00001 ether;
        // appGateway.setFees(fees);
    }
}
