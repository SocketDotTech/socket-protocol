// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterInbox} from "../../contracts/apps/counter-inbox/CounterInbox.sol";
import {CounterInboxAppGateway} from "../../contracts/apps/counter-inbox/CounterInboxAppGateway.sol";
import {Fees} from "../../contracts/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "../../contracts/common/Constants.sol";

contract DeployCounterAndGateway is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address auctionManager = vm.envAddress("AUCTION_MANAGER");

        string memory arbRpc = vm.envString("ARBITRUM_SEPOLIA_RPC");
        vm.createSelectFork(arbRpc);
        uint256 arbDeployerPrivateKey = vm.envUint("SPONSOR_KEY");
        vm.startBroadcast(arbDeployerPrivateKey);

        CounterInbox inbox = new CounterInbox();
        console.log("CounterInbox:", address(inbox));

        vm.stopBroadcast();

        string memory offChainRpc = vm.envString("OFF_CHAIN_VM_RPC");
        vm.createSelectFork(offChainRpc);
        uint256 offChainDeployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(offChainDeployerPrivateKey);

        Fees memory fees = Fees({
            feePoolChain: 421614,
            feePoolToken: ETH_ADDRESS,
            amount: 0.001 ether
        });

        CounterInboxAppGateway gateway = new CounterInboxAppGateway(
            addressResolver,
            auctionManager,
            address(inbox),
            421614,
            fees
        );

        console.log("CounterInboxAppGateway:", address(gateway));

        vm.stopBroadcast();
    }
}
