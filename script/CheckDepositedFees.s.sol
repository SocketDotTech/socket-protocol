// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {FeesManager} from "../contracts/apps/payload-delivery/app-gateway/FeesManager.sol";
import {Fees} from "../contracts/common/Structs.sol";
import {ETH_ADDRESS} from "../contracts/common/Constants.sol";

contract CheckDepositedFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        FeesManager feesManager = FeesManager(payable(vm.envAddress("FEES_MANAGER")));
        address appGateway = vm.envAddress("APP_GATEWAY");

        (uint256 deposited, uint256 blocked) = feesManager.appGatewayFeeBalances(appGateway, 421614, ETH_ADDRESS);
        console.log("App Gateway:", appGateway);
        console.log("Deposited fees:", deposited);
        console.log("Blocked fees:", blocked);

        uint256 availableFees = feesManager.getAvailableFees(421614, appGateway, ETH_ADDRESS);
        console.log("Available fees:", availableFees);
    }
}

