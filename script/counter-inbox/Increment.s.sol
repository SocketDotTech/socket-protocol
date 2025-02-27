// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterInbox} from "../../contracts/apps/counter-inbox/CounterInbox.sol";
import {CounterInboxAppGateway} from "../../contracts/apps/counter-inbox/CounterInboxAppGateway.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "../../contracts/protocol/utils/common/Constants.sol";

contract Increment is Script {
    function run() external {
        string memory arbRpc = vm.envString("ARBITRUM_SEPOLIA_RPC");

        vm.createSelectFork(arbRpc);
        uint256 arbDeployerPrivateKey = vm.envUint("SPONSOR_KEY");
        vm.startBroadcast(arbDeployerPrivateKey);
        address counterInbox = vm.envAddress("COUNTER_INBOX");

        CounterInbox inbox = CounterInbox(counterInbox);
        inbox.increaseOnGateway(100);

        vm.stopBroadcast();
    }
}
