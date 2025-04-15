// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

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
        uint32 chain = 421614;
        address token = ETH_ADDRESS;
        (uint256 deposited, uint256 blocked) = feesManager.appGatewayFeeBalances(
            appGateway,
            chain,
            token
        );
        console.log("App Gateway:", appGateway);
        console.log("Fees Manager:", address(feesManager));
        console.logUint(chain);
        console.log("Token:", token);
        console.log("Deposited fees:", deposited);
        console.log("Blocked fees:", blocked);

        uint256 availableFees = feesManager.getAvailableFees(chain, appGateway, token);
        console.log("Available fees:", availableFees);
    }
}
