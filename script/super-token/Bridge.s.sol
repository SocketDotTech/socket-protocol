// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";
import {SuperTokenAppGateway} from "../../test/apps/app-gateways/super-token-op/SuperTokenAppGateway.sol";

contract Bridge is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        uint256 privateKey = vm.envUint("SOCKET_SIGNER_KEY");
        vm.startBroadcast(privateKey);

        SuperTokenAppGateway.TransferOrder memory order = SuperTokenAppGateway.TransferOrder({
            srcToken: 0x9C79440aD7e70b895d88433D7B268BA4482E406F,
            dstToken: 0xD6CE61B9BE8C8aD07b043e61079d66FB10f2E405,
            user: 0xb62505feacC486e809392c65614Ce4d7b051923b,
            amount: 100000,
            deadline: block.timestamp + 1 days
        });

        SuperTokenAppGateway gateway = SuperTokenAppGateway(vm.envAddress("APP_GATEWAY"));
        bytes memory payload = abi.encode(order);
        console.logBytes(payload);
        gateway.transfer(payload);
    }
}
