// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesManager} from "../../contracts/protocol/payload-delivery/FeesManager.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract CheckDepositedFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        FeesManager feesManager = FeesManager(payable(vm.envAddress("FEES_MANAGER")));
        address appGateway = vm.envAddress("APP_GATEWAY");

        (uint256 totalCredits, uint256 blockedCredits) = feesManager.userCredits(appGateway);
        console.log("App Gateway:", appGateway);
        console.log("Fees Manager:", address(feesManager));
        console.log("totalCredits fees:", totalCredits);
        console.log("blockedCredits fees:", blockedCredits);

        uint256 availableFees = feesManager.getAvailableFees(appGateway);
        console.log("Available fees:", availableFees);
    }
}
