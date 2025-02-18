// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CronAppGateway} from "../../contracts/apps/cron/CronAppGateway.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract DeployGateway is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address auctionManager = vm.envAddress("AUCTION_MANAGER");

        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Arbitrum Sepolia
        Fees memory fees = Fees({
            feePoolChain: 421614,
            feePoolToken: ETH_ADDRESS,
            amount: 0.01 ether
        });
        CronAppGateway gateway = new CronAppGateway(
            addressResolver,
            address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp))))),
            auctionManager,
            fees
        );

        console.log("Contracts deployed:");
        console.log("CronAppGateway:", address(gateway));
    }
}
