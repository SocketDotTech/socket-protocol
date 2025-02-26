// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../test/apps/app-gateways/counter/CounterAppGateway.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract CounterDeployOnchain is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        console.log(rpc);
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CounterAppGateway gateway = CounterAppGateway(vm.envAddress("APP_GATEWAY"));

        console.log("Counter Gateway:", address(gateway));
        console.log("Deploying contracts on Arbitrum Sepolia...");

        uint32[] memory chainSlugs = new uint32[](2);
        chainSlugs[0] = 421614;
        chainSlugs[1] = 11155420;
        gateway.deployMultiChainContracts(chainSlugs);
    }
}
