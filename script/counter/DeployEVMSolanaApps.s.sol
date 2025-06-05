// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {EvmSolanaAppGateway} from "../../test/apps/app-gateways/super-token/EvmSolanaAppGateway.sol";
import {SuperTokenAppGateway} from "../../test/apps/app-gateways/super-token/SuperTokenAppGateway.sol";
import {ETH_ADDRESS} from "../../contracts/utils/common/Constants.sol";
import {ForwarderSolana} from "../../contracts/evmx/ForwarderSolana.sol";
import {AddressResolver} from "../../contracts/evmx/AddressResolver.sol";


// source .env && forge script script/counter/deployEVMxCounterApp.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract DeployEVMSolanaApps is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        // address owner = vm.envAddress("OWNER");
        address owner = vm.envAddress("SENDER_ADDRESS"); // TODO: what address should be used here?–
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // fill with correct values after deployment
        bytes32 solanaProgramId = vm.envBytes32("SOLANA_TARGET_PROGRAM");
        address forwarderSolanaAddress = 0x96438E01A933d50f6803481453E8426ED6c39Eb2;

        // Setting fee payment on Arbitrum Sepolia
        uint256 fees = 10 ether;

        EvmSolanaAppGateway gateway = new EvmSolanaAppGateway(
            addressResolver,
            owner,
            fees,
            EvmSolanaAppGateway.SuperTokenEvmConstructorParams({
                name_: "SuperToken-Evm",
                symbol_: "SUPER",
                decimals_: 18,
                initialSupplyHolder_: owner,
                initialSupply_: 1000000000000000000000000
            }),
            solanaProgramId,
            forwarderSolanaAddress
        );

        // TODO: deploy super token on evm
        // TODO: callSolana() on gateway

        console.log("Contracts deployed:");
        console.log("EvmSolanaAppGateway:", address(gateway));
        console.log("solanaProgramId:");
        console.logBytes32(solanaProgramId);
        console.log("forwarderSolanaAddress:");
        console.logAddress(forwarderSolanaAddress);

        console.log("Forwarder Solana address resolver:");
        console.log(address(ForwarderSolana(forwarderSolanaAddress).addressResolver__()));
        console.log("ForwarderSolana chain slug:");
        console.log(ForwarderSolana(forwarderSolanaAddress).chainSlug());
        console.log("ForwarderSolana onChainAddress:");
        console.logBytes32(ForwarderSolana(forwarderSolanaAddress).onChainAddress());

        console.log("Address resolver from vars:");
        console.log(addressResolver);

        address addressResolverFromLogs = 0x7FC254EA88B06FA31E26ACAeF1E190A9c925948F;
        console.log("Address resolver owner:");
        // console.log(AddressResolver(address(ForwarderSolana(forwarderSolanaAddress).addressResolver__())).owner());
        console.log(AddressResolver(addressResolverFromLogs).owner());
    }
}
