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
        address userEvmAddress = vm.envAddress("EVM_TEST_ACCOUNT");

        console.log("EvmSolanaAppGateway:", address(appGateway));
        console.log("Switchboard solana:");
        console.logBytes32(switchboardSolana);
        console.log("User address: ", userEvmAddress);

        // console.log("Deploying SuperToken on Optimism Sepolia...");
        // appGateway.deployEvmContract(11155420);

        // appGateway.transfer(
        //     abi.encode(
        //         EvmSolanaAppGateway.TransferOrderEvmToSolana({
        //             srcEvmToken: 0x4200000000000000000000000000000000000006,
        //             dstSolanaToken: 0x66619ffe200970bf084fa4713da27d7dff551179adac93fc552787c7555f3482,
        //             userEvm: 0x4200000000000000000000000000000000000005,
        //             destUserTokenAddress: 0x44419ffe200970bf084fa4713da27d7dff551179adac93fc552787c7555f3482,
        //             srcAmount: 1000000000000000000,
        //             deadline: 1715702400
        //         })
        //     ),
        //     switchboardSolana
        // );

        uint256 srcAmount = 1000000;
        // mintOnEvm(srcAmount, userEvmAddress, appGateway);
        // mintOnSolana(srcAmount, userEvmAddress, appGateway);
        transferEvmToSolana(srcAmount, userEvmAddress, appGateway);

        // This works:
        // appGateway.transferForDebug(
        //     buildSolanaInstruction(
        //         EvmSolanaAppGateway.TransferOrderEvmToSolana({
        //             srcEvmToken: 0x4200000000000000000000000000000000000006,
        //             // mint on local-testnet: BdUzPsaAicEWinR7b14YLtvavwM8zYn8BaHKqGQ8by2q
        //             dstSolanaToken: 0x9ded6d20f1f5b9c56cb90ef89fc52d355aaaa868c42738eff11f50d1f81f522a,
        //             userEvm: 0x4200000000000000000000000000000000000005,
        //             // alice super token ata: LVuCmGaoHjAGu54dFppzujS1Ti61CBac57taeQbokUr
        //             destUserTokenAddress: 0x04feb6778939c89983aac734e237dc22f49d7b4418d378a516df15a255d084cb,
        //             srcAmount: 1000000,
        //             deadline: 1715702400
        //         })
        //     ),
        //     switchboardSolana
        // );
    }

    function transferEvmToSolana(
        uint256 srcAmount,
        address userEvmAddress,
        EvmSolanaAppGateway appGateway
    ) public {
        console.log("Transfer EVM to Solana");

        EvmSolanaAppGateway.TransferOrderEvmToSolana memory order = EvmSolanaAppGateway
            .TransferOrderEvmToSolana({
                srcEvmToken: 0x817fe2ED9c6EE7507C30D1feea417d728546efA1, // Forwarder(!!) for Super-token contract on given chain
                // mint on local-testnet: BdUzPsaAicEWinR7b14YLtvavwM8zYn8BaHKqGQ8by2q
                dstSolanaToken: 0x9ded6d20f1f5b9c56cb90ef89fc52d355aaaa868c42738eff11f50d1f81f522a,
                userEvm: userEvmAddress,
                // alice super token ata: LVuCmGaoHjAGu54dFppzujS1Ti61CBac57taeQbokUr
                destUserTokenAddress: 0x04feb6778939c89983aac734e237dc22f49d7b4418d378a516df15a255d084cb,
                srcAmount: srcAmount,
                deadline: 1715702400
            });

        SolanaInstruction memory solanaInstruction = buildSolanaInstruction(order);

        bytes memory orderEncoded = abi.encode(order);

        appGateway.transfer(orderEncoded, solanaInstruction);
    }

    function mintOnEvm(
        uint256 srcAmount,
        address userEvmAddress,
        EvmSolanaAppGateway appGateway
    ) public {
        console.log("Mint on EVM");

        bytes memory order = abi.encode(
            EvmSolanaAppGateway.TransferOrderEvmToSolana({
                srcEvmToken: 0x817fe2ED9c6EE7507C30D1feea417d728546efA1, // Forwarder(!!) for Super-token contract on given chain
                dstSolanaToken: 0x9ded6d20f1f5b9c56cb90ef89fc52d355aaaa868c42738eff11f50d1f81f522a, // irrelevant for EVM minting
                userEvm: userEvmAddress,
                destUserTokenAddress: 0x04feb6778939c89983aac734e237dc22f49d7b4418d378a516df15a255d084cb, // irrelevant for EVM minting
                srcAmount: srcAmount,
                deadline: 1715702400
            })
        );

        EvmSolanaAppGateway.TransferOrderEvmToSolana memory orderObj = abi.decode(
            order,
            (EvmSolanaAppGateway.TransferOrderEvmToSolana)
        );
        console.log("Order srcEvmToken:", orderObj.srcEvmToken);
        console.log("Order userEvm:", orderObj.userEvm);
        console.log("Order srcAmount:", orderObj.srcAmount);

        appGateway.mintSuperTokenEvm(order);
    }

    function mintOnSolana(
        uint256 srcAmount,
        address userEvmAddress,
        EvmSolanaAppGateway appGateway
    ) public {
        console.log("Mint on Solana");

        SolanaInstruction memory solanaInstruction = buildSolanaInstruction(
            EvmSolanaAppGateway.TransferOrderEvmToSolana({
                srcEvmToken: 0xD4a20b34D0dE11e3382Aaa7E0839844f154B6191,
                // mint on local-testnet: BdUzPsaAicEWinR7b14YLtvavwM8zYn8BaHKqGQ8by2q
                dstSolanaToken: 0x9ded6d20f1f5b9c56cb90ef89fc52d355aaaa868c42738eff11f50d1f81f522a,
                userEvm: userEvmAddress,
                // alice super token ata: LVuCmGaoHjAGu54dFppzujS1Ti61CBac57taeQbokUr
                destUserTokenAddress: 0x04feb6778939c89983aac734e237dc22f49d7b4418d378a516df15a255d084cb,
                srcAmount: srcAmount,
                deadline: 1715702400
            })
        );

        appGateway.mintSuperTokenSolana(solanaInstruction);
    }

    function buildSolanaInstruction(
        EvmSolanaAppGateway.TransferOrderEvmToSolana memory order
    ) internal view returns (SolanaInstruction memory) {
        bytes32 solanaTargetProgramId = vm.envBytes32("SOLANA_TARGET_PROGRAM");

        // May be subject to change
        bytes32[] memory accounts = new bytes32[](5);
        // accounts 0 - superTokenConfigPda : jox6eY2gcjaKneNv96TKpjN7f3Rjcpn9dN9ZLNt3Krs
        accounts[0] = 0x0af77affb0a5db632e9bafb98525232515d440861c9942e447c20eefd8883d34;
        // accounts 1 - mint account
        accounts[1] = order.dstSolanaToken;
        // accounts 2 - destination user ata
        accounts[2] = order.destUserTokenAddress;
        // accounts 3 - system programId: 11111111111111111111111111111111
        accounts[3] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        // accounts 4 - token programId: TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
        accounts[4] = 0x06ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a9;

        bytes[] memory functionArguments = new bytes[](1);
        // TODO:GW: in watcher and transmitter we might need to convert this value if on Solana mint has different decimals, for now we assume that both are the same
        functionArguments[0] = abi.encode(order.srcAmount);

        bytes1[] memory accountFlags = new bytes1[](5);
        // superTokenConfigPda is not writable
        accountFlags[0] = bytes1(0x00); // false
        // mint is writable
        accountFlags[1] = bytes1(0x01); // true
        // destination user ata is writable
        accountFlags[2] = bytes1(0x01); // true
        // system programId is not writable
        accountFlags[3] = bytes1(0x00); // false
        // token programId is not writable
        accountFlags[4] = bytes1(0x00); // false

        // mint instruction discriminator
        bytes8 instructionDiscriminator = 0x3339e12fb69289a6;

        string[] memory functionArgumentTypeNames = new string[](1);
        functionArgumentTypeNames[0] = "u64";

        return
            SolanaInstruction({
                data: SolanaInstructionData({
                    programId: solanaTargetProgramId,
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


    function buildSolanaInstructionTest(
        EvmSolanaAppGateway.TransferOrderEvmToSolana memory order
    ) internal view returns (SolanaInstruction memory) {
        bytes32 solanaTargetProgramId = vm.envBytes32("SOLANA_TARGET_PROGRAM");

        // May be subject to change
        bytes32[] memory accounts = new bytes32[](5);
        // accounts 0 - superTokenConfigPda : jox6eY2gcjaKneNv96TKpjN7f3Rjcpn9dN9ZLNt3Krs
        accounts[0] = 0x0af77affb0a5db632e9bafb98525232515d440861c9942e447c20eefd8883d34;
        // accounts 1 - mint account
        accounts[1] = order.dstSolanaToken;
        // accounts 2 - destination user ata
        accounts[2] = order.destUserTokenAddress;
        // accounts 3 - system programId: 11111111111111111111111111111111
        accounts[3] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        // accounts 4 - token programId: TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
        accounts[4] = 0x06ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a9;

        bytes[] memory functionArguments = new bytes[](1);
        functionArguments[0] = abi.encode(order.srcAmount);
        uint256[] memory array = new uint256[](100);
        functionArguments[1] = abi.encode(array);
        ComplexTestStruct memory complexTestStruct = ComplexTestStruct({
            name: "test",
            addr: 0x1234567890123456789012345678901234567890123456789012345678901234,
            isActive: true,
            value: 100
        });
        functionArguments[2] = abi.encode(complexTestStruct);


        string[] memory functionArgumentTypeNames = new string[](1);
        functionArgumentTypeNames[0] = "u64";
        functionArgumentTypeNames[1] = "[u64;100]";
        functionArgumentTypeNames[2] = "{\"ComplexTestStruct\": {\"name\": \"string\",\"addr\": \"[u8;32]\",\"isActive\": \"boolean\",\"value\": \"u64\"}}";

        bytes1[] memory accountFlags = new bytes1[](5);
        // superTokenConfigPda is not writable
        accountFlags[0] = bytes1(0x00); // false
        // mint is writable
        accountFlags[1] = bytes1(0x01); // true
        // destination user ata is writable
        accountFlags[2] = bytes1(0x01); // true
        // system programId is not writable
        accountFlags[3] = bytes1(0x00); // false
        // token programId is not writable
        accountFlags[4] = bytes1(0x00); // false

        // mint instruction discriminator
        bytes8 instructionDiscriminator = 0x3339e12fb69289a6;

        

        return
            SolanaInstruction({
                data: SolanaInstructionData({
                    programId: solanaTargetProgramId,
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

    struct ComplexTestStruct {
        string name;
        bytes32 addr;
        bool isActive;
        uint256 value;
    }
}


