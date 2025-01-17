// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockWatcherPrecompile} from "../../contracts/mock/MockWatcherPrecompile.sol";
import {MockSocket} from "../../contracts/mock/MockSocket.sol";
import {CallType, FinalizeParams, PayloadDetails} from "../../contracts/common/Structs.sol";
contract InboxTest is Script {
    function run() external {
        string memory arbRpc = vm.envString("ARBITRUM_SEPOLIA_RPC");
        string memory offChainRpc = vm.envString("OFF_CHAIN_VM_RPC");
        uint256 offChainDeployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 arbDeployerPrivateKey = vm.envUint("SOCKET_SIGNER_KEY");

        vm.createSelectFork(offChainRpc);
        vm.startBroadcast(offChainDeployerPrivateKey);
        address watcher = vm.envAddress("WATCHER_PRECOMPILE");
        MockWatcherPrecompile watcherInstance = MockWatcherPrecompile(watcher);
        PayloadDetails memory payloadDetails = PayloadDetails({
            chainSlug: 421614,
            appGateway: address(0), // usdc contract
            target: 0x6402c4c08C1F752Ac8c91beEAF226018ec1a27f2, // usdc contract
            payload: abi.encodeWithSignature(
                "transfer(address,uint256)",
                address(0),
                1000000000000000000
            ),
            callType: CallType.WRITE,
            executionGasLimit: 1000000,
            next: new address[](0),
            isSequential: true
        });
        FinalizeParams memory finalizeParams = FinalizeParams({
            payloadDetails: payloadDetails,
            transmitter: address(0)
        });
        (bytes32 payloadId, ) = watcherInstance.finalize(finalizeParams);

        vm.stopBroadcast();

        vm.createSelectFork(arbRpc);
        vm.startBroadcast(arbDeployerPrivateKey);
        address socket = vm.envAddress("SOCKET");
        MockSocket socketInstance = MockSocket(socket);
        socketInstance.execute(payloadId, address(0), address(0), 10000000, bytes(""), bytes(""));
        vm.stopBroadcast();
    }
}
