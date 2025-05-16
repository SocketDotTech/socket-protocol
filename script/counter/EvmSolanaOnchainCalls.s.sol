// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ETH_ADDRESS} from "../../contracts/utils/common/Constants.sol";
import {EvmSolanaAppGateway} from "../../test/apps/app-gateways/super-token/EvmSolanaAppGateway.sol";

// source .env && forge script script/counter/EvmSolanaOnchainCalls.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract EvmSolanaOnchainCalls is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        console.log(rpc);
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        EvmSolanaAppGateway appGateway = EvmSolanaAppGateway(vm.envAddress("APP_GATEWAY"));

        console.log("EvmSolanaAppGateway:", address(appGateway));

        // console.log("Deploying SuperToken on Optimism Sepolia...");
        // appGateway.deployEvmContract(11155420);

        appGateway.transfer(
            abi.encode(
                EvmSolanaAppGateway.TransferOrderEvmToSolana({
                    srcEvmToken: 0x4200000000000000000000000000000000000006,
                    dstSolanaToken: 0x66619ffe200970bf084fa4713da27d7dff551179adac93fc552787c7555f3482,
                    userEvm: 0x4200000000000000000000000000000000000005,
                    userSolana: 0x44419ffe200970bf084fa4713da27d7dff551179adac93fc552787c7555f3482,
                    srcAmount: 1000000000000000000,
                    deadline: 1715702400
                })
            )
        );
    }
}
