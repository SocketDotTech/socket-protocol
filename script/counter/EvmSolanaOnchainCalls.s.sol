// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ETH_ADDRESS} from "../../contracts/utils/common/Constants.sol";
import {EvmSolanaAppGateway} from "../../test/apps/app-gateways/super-token/EvmSolanaAppGateway.sol";
import {SolanaInstruction, SolanaInstructionData, SolanaInstructionDataDescription} from "../../contracts/utils/common/Structs.sol";

// source .env && forge script script/counter/EvmSolanaOnchainCalls.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract EvmSolanaOnchainCalls is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        console.log(rpc);
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        EvmSolanaAppGateway appGateway = EvmSolanaAppGateway(vm.envAddress("APP_GATEWAY"));
        bytes32 switchboardSolana = vm.envBytes32("SWITCHBOARD_SOLANA");

        console.log("EvmSolanaAppGateway:", address(appGateway));
        console.log("Switchboard solana:");
        console.logBytes32(switchboardSolana);

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
            ),
            switchboardSolana
        );
        testSolanaInstructionAsBytes();
    }

    function testSolanaInstructionAsBytes() public {
        EvmSolanaAppGateway.TransferOrderEvmToSolana memory order =
            EvmSolanaAppGateway.TransferOrderEvmToSolana({
                srcEvmToken: 0x4200000000000000000000000000000000000006,
                dstSolanaToken: 0x66619ffe200970bf084fa4713da27d7dff551179adac93fc552787c7555f3482,
                userEvm: 0x4200000000000000000000000000000000000005,
                userSolana: 0x44419ffe200970bf084fa4713da27d7dff551179adac93fc552787c7555f3482,
                srcAmount: 1000000000000000000,
                deadline: 1715702400
            });
        SolanaInstruction memory instruction = buildSolanaInstruction(order);
        bytes memory solanaPayload = abi.encode(instruction);
        console.log("solanaPayload");
        console.logBytes(solanaPayload);
    }

    function buildSolanaInstruction(
        EvmSolanaAppGateway.TransferOrderEvmToSolana memory order
    ) internal view returns (SolanaInstruction memory) {
        // taken from DeployEVMSolanaApps.s.sol
        bytes32 solanaProgramId = 0x666111e742d43eafc1e6509eefca9ceb635a39bd3394041d334203ed35720922;

        // May be subject to change
        bytes32[] memory accounts = new bytes32[](5);
        // accounts 0 - destination user wallet
        accounts[0] = order.userSolana;
        // accounts 1 - mint account
        accounts[1] = order.dstSolanaToken;
        // accounts 2 - user ata account for mint                   // TODO:GW: this is random value
        accounts[2] = 0x66619ffe200970bf084fa4713da27d7dff551179adac93fc552787c7555f3482;
        // accounts 4 - mint authority account (target program PDA) // TODO:GW: this is random value
        accounts[4] = 0xfff2e2d5bdb632266e17b0cdce8b7e3f3a7f1d87c096719f234903b39f84d743;
        // accounts 5,6 - system_program, token_program (those are static and will be added by the transmitter while making a call)

        bytes[] memory functionArguments = new bytes[](1);
        // TODO:GW: in watcher and transmitter we might need to convert this value if on Solana mint has different decimals, for now we assume that both are the same
        functionArguments[0] = abi.encode(order.srcAmount);

        bytes1[] memory accountFlags = new bytes1[](4);
        accountFlags[0] = bytes1(0x00);
        // mint must be is writable
        accountFlags[1] = bytes1(0x01);
        // dst token ata must be is writable
        accountFlags[2] = bytes1(0x01);
        accountFlags[3] = bytes1(0x00);

        // TODO:GW: update when TargetDummy is ready
        bytes8 instructionDiscriminator = bytes8(uint64(123));

        string[] memory functionArgumentTypeNames = new string[](1);
        functionArgumentTypeNames[0] = "u64";

        return
            SolanaInstruction({
                data: SolanaInstructionData({
                    programId: solanaProgramId,
                    instructionDiscriminator: instructionDiscriminator,
                    accounts: accounts,
                    functionArguments: functionArguments
                }),
                description: SolanaInstructionDataDescription({
                    accountFlags: accountFlags,
                    functionArgumentTypeNames: functionArgumentTypeNames
                })
            });
    }
}
