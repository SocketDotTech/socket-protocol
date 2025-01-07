// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../contracts/apps//counter/CounterAppGateway.sol";
import {CounterDeployer} from "../../contracts/apps//counter/CounterDeployer.sol";
import {FeesData} from "../../contracts/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/common/Constants.sol";

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

        CounterDeployer deployer = new CounterDeployer(
            addressResolver,
            auctionManager,
            feesData
        );

        CounterAppGateway gateway = new CounterAppGateway(
            addressResolver,
            address(deployer),
            auctionManager,
            feesData
        );

        console.log("Contracts deployed:");
        console.log("CounterDeployer:", address(deployer));
        console.log("CounterAppGateway:", address(gateway));
    }
}
