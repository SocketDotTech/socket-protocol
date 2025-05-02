// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "../../contracts/protocol/payload-delivery/FeesPlug.sol";

contract RescueFundsScript is Script {
    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    struct ChainConfig {
        address feesPlug;
        string rpc;
        string name;
    }

    function rescueFromChain(
        ChainConfig memory config,
        address sender,
        uint256 deployerKey
    ) internal {
        uint256 fork = vm.createFork(config.rpc);
        vm.selectFork(fork);
        uint256 balance = address(config.feesPlug).balance;

        if (balance > 0) {
            console.log("%s Fees Plug Balance:", config.name);
            console.log(balance);

            vm.startBroadcast(deployerKey);
            FeesPlug(config.feesPlug).rescueFunds(NATIVE_TOKEN, sender, balance);
            vm.stopBroadcast();
        }
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SPONSOR_KEY");
        address sender = vm.envAddress("SENDER_ADDRESS");

        ChainConfig[] memory chains = new ChainConfig[](4);

        chains[0] = ChainConfig({
            feesPlug: vm.envAddress("ARBITRUM_FEES_PLUG"),
            rpc: vm.envString("ARBITRUM_SEPOLIA_RPC"),
            name: "Arbitrum"
        });

        chains[1] = ChainConfig({
            feesPlug: vm.envAddress("BASE_FEES_PLUG"),
            rpc: vm.envString("BASE_SEPOLIA_RPC"),
            name: "Base"
        });

        chains[2] = ChainConfig({
            feesPlug: vm.envAddress("OPTIMISM_FEES_PLUG"),
            rpc: vm.envString("OPTIMISM_SEPOLIA_RPC"),
            name: "Optimism"
        });

        chains[3] = ChainConfig({
            feesPlug: vm.envAddress("SEPOLIA_FEES_PLUG"),
            rpc: vm.envString("SEPOLIA_RPC"),
            name: "Sepolia"
        });

        for (uint i = 0; i < chains.length; i++) {
            rescueFromChain(chains[i], sender, deployerPrivateKey);
        }
    }
}
