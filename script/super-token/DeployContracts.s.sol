// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenAppGateway} from "../../test/apps/app-gateways/super-token/SuperTokenAppGateway.sol";
import {SuperToken} from "../../test/apps/app-gateways/super-token/SuperToken.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract DeployContracts is Script {
    function run() external {
        vm.startBroadcast();
        SuperTokenAppGateway deployer = SuperTokenAppGateway(
            0x02520426a04D2943d817A60ABa37ab25bA10e630
        );
        deployer.deployContracts(84532);
        deployer.deployContracts(11155111);
    }
}
