// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockSocket} from "../../../test/mock/MockSocket.sol";

contract DeploySocket is Script {
    function run() external {
        string memory rpc = vm.envString("ARBITRUM_SEPOLIA_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("SOCKET_SIGNER_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MockSocket socket = new MockSocket(421614, address(0), address(0), address(0), "1.0.0");
        console.log("MockSocket:", address(socket));
    }
}
