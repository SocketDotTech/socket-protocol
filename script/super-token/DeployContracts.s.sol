// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenAppGateway} from "../../contracts/apps/super-token/SuperTokenAppGateway.sol";
import {SuperTokenDeployer} from "../../contracts/apps/super-token/SuperTokenDeployer.sol";
import {SuperToken} from "../../contracts/apps/super-token/SuperToken.sol";
import {Fees} from "../../contracts/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/common/Constants.sol";

contract DeployContracts is Script {
    function run() external {
        vm.startBroadcast();
        SuperTokenDeployer deployer = SuperTokenDeployer(
            0x02520426a04D2943d817A60ABa37ab25bA10e630
        );
        deployer.deployContracts(84532);
        deployer.deployContracts(11155111);
    }
}
