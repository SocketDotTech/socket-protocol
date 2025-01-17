// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ParallelCounterAppGateway} from "../../contracts/apps/parallel-counter/ParallelCounterAppGateway.sol";
import {ParallelCounterDeployer} from "../../contracts/apps/parallel-counter/ParallelCounterDeployer.sol";
import {FeesData} from "../../contracts/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "../../contracts/common/Constants.sol";

contract CounterDeploy is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address auctionManager = vm.envAddress("AUCTION_MANAGER");
        string memory rpc = vm.envString("OFF_CHAIN_VM_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Arbitrum Sepolia
        FeesData memory feesData = FeesData({
            feePoolChain: 421614,
            feePoolToken: ETH_ADDRESS,
            maxFees: 0.01 ether
        });

        ParallelCounterDeployer deployer = new ParallelCounterDeployer(
            addressResolver,
            auctionManager,
            FAST,
            feesData
        );

        ParallelCounterAppGateway gateway = new ParallelCounterAppGateway(
            addressResolver,
            address(deployer),
            auctionManager,
            feesData
        );

        console.log("Contracts deployed:");
        console.log("ParallelCounterDeployer:", address(deployer));
        console.log("ParallelCounterAppGateway:", address(gateway));
    }
}
