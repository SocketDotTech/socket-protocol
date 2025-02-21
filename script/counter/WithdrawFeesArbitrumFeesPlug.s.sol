// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesManager} from "../../contracts/protocol/payload-delivery/app-gateway/FeesManager.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";
import {CounterAppGateway} from "../../contracts/apps/counter/CounterAppGateway.sol";

contract WithdrawFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        FeesManager feesManager = FeesManager(payable(vm.envAddress("FEES_MANAGER")));
        address appGatewayAddress = vm.envAddress("APP_GATEWAY");
        CounterAppGateway appGateway = CounterAppGateway(appGatewayAddress);

        uint256 availableFees = feesManager.getAvailableFees(
            421614,
            appGatewayAddress,
            ETH_ADDRESS
        );
        console.log("Available fees:", availableFees);

        if (availableFees > 0) {
            vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));

            uint256 privateKey = vm.envUint("PRIVATE_KEY");
            address sender = vm.addr(privateKey);
            console.log("Sender address:", sender);
            console.log("Sender balance", sender.balance);

            vm.startBroadcast(privateKey);

            appGateway.withdrawFeeTokens(421614, ETH_ADDRESS, availableFees, sender);
            console.log("Withdrew:", availableFees);
            console.log("Sender balance", sender.balance);
        }
    }
}
