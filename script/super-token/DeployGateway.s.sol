// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenAppGateway} from "../../test/apps/app-gateways/super-token-op/SuperTokenAppGateway.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract DeployTokenGateway is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Arbitrum Sepolia
        Fees memory fees = Fees({
            feePoolChain: 420120000,
            feePoolToken: ETH_ADDRESS,
            amount: 0.00001 ether
        });

        SuperTokenAppGateway gateway = new SuperTokenAppGateway(addressResolver, deployer, fees);

        console.log("Contracts deployed:");
        console.log("SuperTokenAppGateway:", address(gateway));
        console.log("superTokenId:");
        console.logBytes32(gateway.superToken());
    }
}
