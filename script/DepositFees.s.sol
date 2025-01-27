// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {FeesPlug} from "../contracts/apps/payload-delivery/FeesPlug.sol";
import {FeesData} from "../contracts/common/Structs.sol";
import {ETH_ADDRESS} from "../contracts/common/Constants.sol";

contract DepositFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(payable(0x6c40Fb39B03e32EC4D23e31DdE6D10283F2C7b4F));
        address appGateway = vm.envAddress("APP_GATEWAY");

        address sender = vm.addr(privateKey);
        console.log("Sender address:", sender);
        uint256 balance = sender.balance;
        console.log("Sender balance:", balance);

        uint feesAmount = 0.001 ether;
        feesPlug.deposit{value: feesAmount}(ETH_ADDRESS, appGateway, feesAmount);
    }
}
