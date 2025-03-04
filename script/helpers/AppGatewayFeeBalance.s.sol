// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesManager} from "../../contracts/protocol/payload-delivery/FeesManager.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract CheckDepositedFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        FeesManager feesManager = FeesManager(payable(vm.envAddress("FEES_MANAGER")));
        address appGateway = vm.envAddress("APP_GATEWAY");

        uint32 chainSlug = 420120000;

        (uint256 deposited, uint256 blocked) = feesManager.appGatewayFeeBalances(
            appGateway,
            chainSlug,
            ETH_ADDRESS
        );
        console.log("App Gateway:", appGateway);
        console.log("Deposited fees:", deposited);
        console.log("Blocked fees:", blocked);

        uint256 availableFees = feesManager.getAvailableFees(chainSlug, appGateway, ETH_ADDRESS);
        console.log("Available fees:", availableFees);
    }
}
