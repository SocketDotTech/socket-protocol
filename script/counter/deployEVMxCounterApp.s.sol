// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterAppGateway} from "../../contracts/apps//counter/CounterAppGateway.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "../../contracts/protocol/utils/common/Constants.sol";

contract CounterDeploy is Script {
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
            amount: 0.001 ether
        });

        CounterAppGateway gateway = new CounterAppGateway(
            addressResolver,
            auctionManager,
            FAST,
            fees
        );

        console.log("Contracts deployed:");
        console.log("CounterAppGateway:", address(gateway));
        console.log("counterId:");
        console.logBytes32(gateway.counter());
    }
}
