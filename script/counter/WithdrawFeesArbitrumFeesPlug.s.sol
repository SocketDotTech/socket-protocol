// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesManager} from "../../contracts/evmx/payload-delivery/FeesManager.sol";
import {ETH_ADDRESS} from "../../contracts/utils/common/Constants.sol";
import {CounterAppGateway} from "../../test/apps/app-gateways/counter/CounterAppGateway.sol";

// @notice This script is used to withdraw fees from EVMX to Arbitrum Sepolia
// @dev Make sure your app has withdrawFeeTokens() function implemented. You can check its implementation in CounterAppGateway.sol
contract WithdrawFees is Script {
    function run() external {
        // EVMX Check available fees
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        FeesManager feesManager = FeesManager(payable(vm.envAddress("FEES_MANAGER")));
        address appGatewayAddress = vm.envAddress("APP_GATEWAY");

        CounterAppGateway appGateway = CounterAppGateway(appGatewayAddress);
        uint256 availableFees = feesManager.getMaxCreditsAvailableForWithdraw(appGatewayAddress);
        console.log("Available fees:", availableFees);

        if (availableFees > 0) {
            // Switch to Arbitrum Sepolia to get gas price
            vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));
            uint256 privateKey = vm.envUint("PRIVATE_KEY");
            address sender = vm.addr(privateKey);

            // Gas price from Arbitrum
            uint256 arbitrumGasPrice = block.basefee + 0.1 gwei; // With buffer
            uint256 gasLimit = 5_000_000; // Estimate
            uint256 estimatedGasCost = gasLimit * arbitrumGasPrice;

            console.log("Arbitrum gas price (wei):", arbitrumGasPrice);
            console.log("Gas limit:", gasLimit);
            console.log("Estimated gas cost:", estimatedGasCost);

            // Calculate amount to withdraw
            uint256 amountToWithdraw = availableFees > estimatedGasCost
                ? availableFees - estimatedGasCost
                : 0;

            if (amountToWithdraw > 0) {
                // Switch back to EVMX to perform withdrawal
                vm.createSelectFork(vm.envString("EVMX_RPC"));
                vm.startBroadcast(privateKey);
                console.log("Withdrawing amount:", amountToWithdraw);
                appGateway.withdrawFeeTokens(421614, ETH_ADDRESS, amountToWithdraw, sender);
                vm.stopBroadcast();

                // Switch back to Arbitrum Sepolia to check final balance
                vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));
                console.log("Final sender balance:", sender.balance);
            } else {
                console.log("Available fees less than estimated gas cost");
            }
        }
    }
}
