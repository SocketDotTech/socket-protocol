// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockWatcherPrecompile} from "../../contracts/mock/MockWatcherPrecompile.sol";
import {MockSocket} from "../../contracts/mock/MockSocket.sol";

contract InboxTest is Script {
    function run() external {
        string memory rpc = vm.envString("ARBITRUM_SEPOLIA_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("SOCKET_SIGNER_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address socket = vm.envAddress("SOCKET");
        MockSocket socketInstance = MockSocket(socket);
        bytes memory payload = hex"00010203";
        bytes32 params = bytes32(0);
        socketInstance.callAppGateway(payload, params);
    }
}
