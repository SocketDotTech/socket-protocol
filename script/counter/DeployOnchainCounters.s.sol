// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";
import {CounterAppGateway} from "../../test/apps/app-gateways/counter/CounterAppGateway.sol";

contract CounterDeployOnchain is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        console.log(rpc);
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CounterAppGateway appGateway = CounterAppGateway(vm.envAddress("APP_GATEWAY"));

        console.log("Counter Gateway:", address(appGateway));

        console.log("Deploying contracts on Arbitrum Sepolia...");
        appGateway.deployContracts(421614);
    }
}
