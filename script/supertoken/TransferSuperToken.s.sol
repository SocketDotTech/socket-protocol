// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenAppGateway} from "../../test/apps/app-gateways/super-token/SuperTokenAppGateway.sol";

// source .env && forge script script/supertoken/TransferSuperToken.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract TransferSuperToken is Script {
    function run() external {
        string memory socketRPC = vm.envString("EVMX_RPC");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(socketRPC);

        SuperTokenAppGateway gateway = SuperTokenAppGateway(vm.envAddress("APP_GATEWAY"));
        address forwarderArb = gateway.forwarderAddresses(gateway.superToken(), 421614);
        address forwarderOpt = gateway.forwarderAddresses(gateway.superToken(), 11155420);

        SuperTokenAppGateway.TransferOrder memory transferOrder = SuperTokenAppGateway
            .TransferOrder({
                srcToken: forwarderArb,
                dstToken: forwarderOpt,
                user: vm.addr(deployerPrivateKey),
                srcAmount: 100,
                deadline: block.timestamp + 1000000
            });

        bytes memory encodedOrder = abi.encode(transferOrder);
        bytes memory encodedPayload = abi.encodeWithSelector(
            bytes4(keccak256("transfer(bytes)")),
            encodedOrder
        );
        console.logBytes(encodedPayload);
    }
}
