// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ParallelCounterDeployer} from "../../contracts/apps/parallel-counter/ParallelCounterDeployer.sol";
import {ETH_ADDRESS} from "../../contracts/common/Constants.sol";

contract CounterDeployOnchain is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        console.log(rpc);
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ParallelCounterDeployer deployer = ParallelCounterDeployer(vm.envAddress("DEPLOYER"));

        console.log("Counter Deployer:", address(deployer));

        console.log("Deploying contracts on Arbitrum Sepolia...");

        uint32[] memory chainSlugs = new uint32[](2);
        chainSlugs[0] = 421614;
        chainSlugs[1] = 11155420;
        deployer.deployMultiChainContracts(chainSlugs);
    }
}
