// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "../../contracts/evmx/plugs/FeesPlug.sol";
import {TestUSDC} from "../../contracts/evmx/mocks/TestUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// source .env && forge script script/helpers/DepositCreditAndNative.s.sol --broadcast --skip-simulation
contract DepositCredit is Script {
    function run() external {
        uint256 feesAmount = 1000000; // 1 USDC
        vm.createSelectFork(vm.envString("ARBITRUM_RPC"));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(payable(vm.envAddress("ARBITRUM_FEES_PLUG")));
        address appGateway = vm.envAddress("APP_GATEWAY");
        IERC20 USDCContract = IERC20(vm.envAddress("ARBITRUM_USDC"));

        // approve fees plug to spend test USDC
        USDCContract.approve(address(feesPlug), feesAmount);

        address sender = vm.addr(privateKey);
        console.log("Sender address:", sender);
        uint256 balance = USDCContract.balanceOf(sender);
        console.log("Sender USDC balance:", balance);
        if (balance < feesAmount) {
            revert("Sender does not have enough USDC");
        }
        console.log("App Gateway:", appGateway);
        console.log("Fees Plug:", address(feesPlug));
        console.log("Fees Amount:", feesAmount);
        feesPlug.depositCredit(address(USDCContract), appGateway, feesAmount);
    }
}
