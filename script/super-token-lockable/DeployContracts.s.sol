// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenLockableAppGateway} from "../../contracts/apps/super-token-lockable/SuperTokenLockableAppGateway.sol";
import {SuperTokenLockableDeployer} from "../../contracts/apps/super-token-lockable/SuperTokenLockableDeployer.sol";
import {SuperTokenLockable} from "../../contracts/apps/super-token-lockable/SuperTokenLockable.sol";
import {Fees} from "../../contracts/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/common/Constants.sol";

contract DeployContracts is Script {
    function run() external {
        SuperTokenLockableDeployer deployer = SuperTokenLockableDeployer(
            vm.envAddress("SUPERTOKEN_DEPLOYER")
        );
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        deployer.deployContracts(84532);
        deployer.deployContracts(11155111);
    }
}
