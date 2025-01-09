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

        address addressResolver = 0x208dC31cd6042a09bbFDdB31614A337a51b870ba;
        address auctionManager = 0x0000000000000000000000000000000000000000;
        address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

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
                _burnLimit: 10000000000000000000000,
                _mintLimit: 10000000000000000000000,
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
        bytes32 limitHook = deployer.limitHook();

        console.log("Contracts deployed:");
        console.log("SuperTokenApp:", address(gateway));
        console.log("SuperTokenDeployer:", address(deployer));
        console.log("SuperTokenId:");
        console.logBytes32(superToken);
        console.log("LimitHookId:");
        console.logBytes32(limitHook);
    }
}
