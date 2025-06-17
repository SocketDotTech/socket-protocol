// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../../test/apps/app-gateways/super-token/SuperTokenAppGateway.sol";
import {CCTP} from "../../contracts/utils/common/Constants.sol";
// source .env && forge script script/supertoken/deployEVMxSuperTokenApp.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract SuperTokenDeploy is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Arbitrum Sepolia
        uint256 fees = 1 ether;

        SuperTokenAppGateway gateway = new SuperTokenAppGateway(
            addressResolver,
            vm.addr(deployerPrivateKey),
            fees,
            SuperTokenAppGateway.ConstructorParams({
                name_: "SuperToken",
                symbol_: "SUPER",
                decimals_: 18,
                initialSupplyHolder_: vm.addr(deployerPrivateKey),
                initialSupply_: 1000000000000000000000000000
            })
        );

        console.log("Contracts deployed:");
        console.log("SuperTokenAppGateway:", address(gateway));
        gateway.setSbType(CCTP);
    }
}
