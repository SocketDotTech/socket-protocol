// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenAppGateway} from "../../test/apps/app-gateways/super-token-op/SuperTokenAppGateway.sol";

contract SuperTokenDeploy is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        address appGatewayAddress = vm.envAddress("APP_GATEWAY");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Arbitrum Sepolia
        SuperTokenAppGateway gateway = SuperTokenAppGateway(appGatewayAddress);

        gateway.deployContracts(420120000);
        gateway.deployContracts(420120001);

        console.log("Tokens deployed");
    }
}
