// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CounterInbox} from "../../contracts/apps/counter-inbox/CounterInbox.sol";
import {CounterInboxAppGateway} from "../../contracts/apps/counter-inbox/CounterInboxAppGateway.sol";
import {Fees} from "../../contracts/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "../../contracts/common/Constants.sol";

contract Increment is Script {
    function run() external {
        address gateway = vm.envAddress("APP_GATEWAY");
        address socket = vm.envAddress("SOCKET");
        address switchboard = vm.envAddress("SWITCHBOARD");
        string memory arbRpc = vm.envString("ARBITRUM_SEPOLIA_RPC");
        vm.createSelectFork(arbRpc);
        uint256 arbDeployerPrivateKey = vm.envUint("SPONSOR_KEY");
        vm.startBroadcast(arbDeployerPrivateKey);
        address counterInbox = vm.envAddress("COUNTER_INBOX");

        CounterInbox inbox = CounterInbox(counterInbox);
        inbox.connectSocket(address(gateway), socket, switchboard);
        inbox.increaseOnGateway(100);

        vm.stopBroadcast();
    }
}
