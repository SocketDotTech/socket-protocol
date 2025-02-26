// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenLockableAppGateway} from "../../contracts/apps/super-token-lockable/SuperTokenLockableAppGateway.sol";
import {SuperTokenLockable} from "../../contracts/apps/super-token-lockable/SuperTokenLockable.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract DeployContracts is Script {
    function run() external {
        SuperTokenLockableAppGateway gateway = SuperTokenLockableAppGateway(
            vm.envAddress("APP_GATEWAY")
        );
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        gateway.deployContracts(84532);
        gateway.deployContracts(11155111);
    }
}
