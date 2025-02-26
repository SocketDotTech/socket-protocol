// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenAppGateway} from "../../contracts/apps/super-token/SuperTokenAppGateway.sol";
import {SuperToken} from "../../contracts/apps/super-token/SuperToken.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "../../contracts/protocol/utils/common/Constants.sol";

contract DeployGateway is Script {
    function run() external {
        vm.startBroadcast();

        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address auctionManager = vm.envAddress("AUCTION_MANAGER");
        address owner = vm.envAddress("OWNER");

        Fees memory fees = Fees({
            feePoolChain: 421614,
            feePoolToken: ETH_ADDRESS,
            amount: 0.001 ether
        });

        SuperTokenAppGateway gateway = new SuperTokenAppGateway(
            addressResolver,
            address(auctionManager),
            FAST,
            fees,
            SuperTokenAppGateway.ConstructorParams({
                name_: "SuperToken",
                symbol_: "SUPER",
                decimals_: 18,
                initialSupplyHolder_: owner,
                initialSupply_: 1000000000000000000000000
            })
        );

        bytes32 superToken = gateway.superToken();

        console.log("Contracts deployed:");
        console.log("SuperTokenAppGateway:", address(gateway));
        console.log("SuperTokenId:");
        console.logBytes32(superToken);
    }
}
