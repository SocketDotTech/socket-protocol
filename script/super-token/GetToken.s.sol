// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenAppGateway} from "../../test/apps/app-gateways/super-token-op/SuperTokenAppGateway.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract GetToken is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);
        // Setting fee payment on Arbitrum Sepolia
        SuperTokenAppGateway gateway = SuperTokenAppGateway(vm.envAddress("APP_GATEWAY"));
        bytes32 superTokenId = gateway.superToken();

        address op0Token = gateway.getOnChainAddress(superTokenId, 420120000);
        address op1Token = gateway.getOnChainAddress(superTokenId, 420120001);

        address op0TokenForwarder = gateway.forwarderAddresses(superTokenId, 420120000);
        address op1TokenForwarder = gateway.forwarderAddresses(superTokenId, 420120001);

        console.log("Contracts deployed:");
        console.log("Op 0 address:", op0Token);
        console.log("Op 1 address:", op1Token);
        console.log("Op 0 forwarder:", op0TokenForwarder);
        console.log("Op 1 forwarder:", op1TokenForwarder);
    }
}
