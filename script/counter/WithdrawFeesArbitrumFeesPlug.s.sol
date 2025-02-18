// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {FeesPlug} from "../../contracts/payload-delivery/FeesPlug.sol";
import {ETH_ADDRESS} from "../../contracts/common/Constants.sol";
import {CounterAppGateway} from "../../contracts/apps/counter/CounterAppGateway.sol";

contract WithdrawFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(payable(vm.envAddress("ARBITRUM_FEES_PLUG")));
        address appGatewayAddress = vm.envAddress("APP_GATEWAY");
        CounterAppGateway appGateway = CounterAppGateway(appGatewayAddress);

        address sender = vm.addr(privateKey);
        console.log("Sender address:", sender);
        uint256 balance = sender.balance;
        console.log("Sender balance:", balance);

        uint256 appBalance = feesPlug.balanceOf(appGatewayAddress);
        console.log("AppBalance:", appBalance);
        if (appBalance > 0) {
            appGateway.withdrawFeeTokens(421614, ETH_ADDRESS, appBalance, sender);
            console.log("Withdrew:", appBalance);
        }
    }
}
