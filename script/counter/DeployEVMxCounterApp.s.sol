// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../test/apps/app-gateways/counter/CounterAppGateway.sol";
import {ETH_ADDRESS} from "../../contracts/utils/common/Constants.sol";

// source .env && forge script script/counter/deployEVMxCounterApp.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract CounterDeploy is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Arbitrum Sepolia
        uint256 fees = 10 ether;

        CounterAppGateway gateway = new CounterAppGateway(addressResolver, fees);

        console.log("Contracts deployed:");
        console.log("CounterAppGateway:", address(gateway));
        console.log("counterId:");
        console.logBytes32(gateway.counter());
    }
}
