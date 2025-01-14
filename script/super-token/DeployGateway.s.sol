// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {SuperTokenAppGateway} from "../../contracts/apps/super-token/SuperTokenAppGateway.sol";
import {SuperTokenDeployer} from "../../contracts/apps/super-token/SuperTokenDeployer.sol";
import {SuperToken} from "../../contracts/apps/super-token/SuperToken.sol";
import {FeesData} from "../../contracts/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "../../contracts/common/Constants.sol";

contract DeployGateway is Script {
    function run() external {
        vm.startBroadcast();

        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address auctionManager = vm.envAddress("AUCTION_MANAGER");
        address owner = vm.envAddress("OWNER");

        FeesData memory feesData = FeesData({
            feePoolChain: 421614,
            feePoolToken: ETH_ADDRESS,
            maxFees: 0.001 ether
        });

        SuperTokenDeployer deployer = new SuperTokenDeployer(
            addressResolver,
            owner,
            address(auctionManager),
            FAST,
            SuperTokenDeployer.ConstructorParams({
                name_: "SUPER TOKEN",
                symbol_: "SUPER",
                decimals_: 18,
                initialSupplyHolder_: owner,
                initialSupply_: 1000000000 ether
            }),
            feesData
        );

        SuperTokenAppGateway gateway = new SuperTokenAppGateway(
            addressResolver,
            address(deployer),
            feesData,
            address(auctionManager)
        );

        bytes32 superToken = deployer.superToken();

        console.log("Contracts deployed:");
        console.log("SuperTokenApp:", address(gateway));
        console.log("SuperTokenDeployer:", address(deployer));
        console.log("SuperTokenId:");
        console.logBytes32(superToken);
    }
}
