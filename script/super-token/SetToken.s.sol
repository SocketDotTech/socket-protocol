// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";
import {OpInteropSwitchboard} from "../../contracts/protocol/socket/switchboard/OpInteropSwitchboard.sol";

contract SetToken is Script {
    function run() external {
        vm.createSelectFork(vm.envString("INTEROP_ALPHA_0_RPC"));
        uint256 privateKey = vm.envUint("SOCKET_SIGNER_KEY");
        vm.startBroadcast(privateKey);

        OpInteropSwitchboard switchboard = OpInteropSwitchboard(
            0x9EDfb162b725CF6d628D68af200cAe8b624111eD
        );
        // Op 0 address: 0x46fc6C778E8F69fB97538530D1f4eCe674719604
        // Op 1 address: 0x897f6507bFE6C365394377b86C158Df05e3DD12b
        switchboard.setToken(0x46fc6C778E8F69fB97538530D1f4eCe674719604);
    }
}
