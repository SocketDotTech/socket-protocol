// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "../../contracts/evmx/plugs/FeesPlug.sol";
import {TestUSDC} from "../../contracts/evmx/mocks/TestUSDC.sol";

// source .env && forge script script/helpers/DepositCreditAndNative.s.sol --broadcast --skip-simulation
contract DepositCredit is Script {
    function run() external {
        uint256 feesAmount = 2000000; // 2 USDC
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(payable(vm.envAddress("ARBITRUM_FEES_PLUG")));
        address appGateway = vm.envAddress("APP_GATEWAY");
        TestUSDC testUSDCContract = TestUSDC(vm.envAddress("ARBITRUM_TEST_USDC"));

        // mint test USDC to sender
        testUSDCContract.mint(vm.addr(privateKey), feesAmount);
        // approve fees plug to spend test USDC
        testUSDCContract.approve(address(feesPlug), feesAmount);

        address sender = vm.addr(privateKey);
        console.log("Sender address:", sender);
        uint256 balance = testUSDCContract.balanceOf(sender);
        console.log("Sender balance in wei:", balance);
        console.log("App Gateway:", appGateway);
        console.log("Fees Plug:", address(feesPlug));
        console.log("Fees Amount:", feesAmount);
        feesPlug.depositCredit(address(testUSDCContract), appGateway, feesAmount);
    }
}
