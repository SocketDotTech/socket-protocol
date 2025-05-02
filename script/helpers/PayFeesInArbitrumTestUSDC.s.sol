// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "../../contracts/protocol/payload-delivery/FeesPlug.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";
import {TestUSDC} from "../../contracts/helpers/TestUSDC.sol";
// source .env && forge script script/helpers/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation
contract DepositFees is Script {
    function run() external {
        uint256 feesAmount = 100000000;
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));

        uint256 privateKey = vm.envUint("SPONSOR_KEY");
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
        feesPlug.depositToFeeAndNative(address(testUSDCContract), appGateway, feesAmount);
    }
}
