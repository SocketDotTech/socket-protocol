// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "../../contracts/evmx/plugs/FeesPlug.sol";
import {TestUSDC} from "../../contracts/evmx/mocks/TestUSDC.sol";

// source .env && forge script script/helpers/DepositCredit.s.sol --broadcast --skip-simulation
contract DepositCredit is Script {
    function run() external {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(payable(vm.envAddress("ARBITRUM_FEES_PLUG")));
        TestUSDC token = TestUSDC(vm.envAddress("USDC"));
        address appGateway = vm.envAddress("APP_GATEWAY");

        address sender = vm.addr(privateKey);
        console.log("Sender address:", sender);
        uint256 balance = sender.balance;
        console.log("Sender balance in wei:", balance);
        console.log("App Gateway:", appGateway);
        console.log("Fees Plug:", address(feesPlug));
        uint feesAmount = 0.001 ether;
        feesPlug.depositCredit(address(token), appGateway, feesAmount);
    }
}
