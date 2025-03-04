// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";
import {OpInteropSwitchboard} from "../../contracts/protocol/socket/switchboard/OpInteropSwitchboard.sol";

contract SetToken is Script {
    function run() external {
        vm.createSelectFork(vm.envString("INTEROP_ALPHA_1_RPC"));
        uint256 privateKey = vm.envUint("SOCKET_SIGNER_KEY");
        vm.startBroadcast(privateKey);

        OpInteropSwitchboard switchboard = OpInteropSwitchboard(
            0x9EDfb162b725CF6d628D68af200cAe8b624111eD
        );
        // 0: 0x425b451FE96F427Fd7FCD2a1B58fe70573CcdD56
        // 1: 0xcBA03e3Fe32B41B0B90cf2b113Bc4990b22c4c5F
        switchboard.setToken(0xcBA03e3Fe32B41B0B90cf2b113Bc4990b22c4c5F);
    }
}
