// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesManager} from "../../contracts/evmx/fees/FeesManager.sol";
import {IAppGateway} from "../../contracts/evmx/interfaces/IAppGateway.sol";

contract TransferRemainingCredits is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        FeesManager feesManager = FeesManager(payable(vm.envAddress("FEES_MANAGER")));
        address appGateway = vm.envAddress("APP_GATEWAY");
        address newAppGateway = vm.envAddress("NEW_APP_GATEWAY");

        (uint256 totalCredits, uint256 blockedCredits) = feesManager.userCredits(appGateway);
        console.log("App Gateway:", appGateway);
        console.log("New App Gateway:", newAppGateway);
        console.log("Fees Manager:", address(feesManager));
        console.log("totalCredits fees:", totalCredits);
        console.log("blockedCredits fees:", blockedCredits);

        uint256 availableFees = feesManager.getAvailableCredits(appGateway);
        console.log("Available fees:", availableFees);
        bytes memory data = abi.encodeWithSignature(
            "transferCredits(address,uint256)",
            newAppGateway,
            availableFees
        );
        (bool success, ) = appGateway.call(data);
        require(success, "Transfer failed");
        vm.stopBroadcast();
    }
}
