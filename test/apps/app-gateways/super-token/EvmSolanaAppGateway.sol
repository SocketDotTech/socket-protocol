// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "../../../../contracts/evmx/base/AppGatewayBase.sol";
import "./ISuperToken.sol";
import "./SuperToken.sol";
import {SolanaInstruction, SolanaInstructionData, SolanaInstructionDataDescription} from "../../../../contracts/utils/common/Structs.sol";
import {ForwarderSolana} from "../../../../contracts/evmx/helpers/ForwarderSolana.sol";
import {BorshDecoder} from "../../../../contracts/evmx/watcher/BorshDecoder.sol";
import {BorshEncoder} from "../../../../contracts/evmx/watcher/BorshEncoder.sol";

contract EvmSolanaAppGateway is AppGatewayBase, Ownable {

    event Transferred(uint40 requestCount);

    struct SuperTokenEvmConstructorParams {
        string name_;
        string symbol_;
        uint8 decimals_;
        address initialSupplyHolder_;
        uint256 initialSupply_;
    }

    /** Write input structs **/

    struct TransferOrderEvmToSolana {
        address srcEvmToken;
        bytes32 dstSolanaToken;
        address userEvm;
        bytes32 destUserTokenAddress;
        uint256 srcAmount;
        uint256 deadline;
    }

    /** Read output structs **/

    struct SolanaTokenBalance {
        uint64 amount;
        uint64 decimals;
    }

    struct SuperTokenConfigAccount {
        bytes8 accountDiscriminator;
        bytes32 owner;
        bytes32 socket;
        bytes32 mint;
        uint8 bump;
    }

    event SuperTokenConfigAccountRead(SuperTokenConfigAccount superTokenConfigAccount);
    event TokenAccountRead(bytes32 tokenAccountAddress, uint64 amount, uint64 decimals);

    /** Contract data **/

    bytes32 public superTokenEvm = _createContractId("superTokenEvm");
    // solana program address
    bytes32 public solanaProgramId;
    ForwarderSolana public forwarderSolana;

    mapping(bytes32 => SolanaTokenBalance) solanaTokenBalances;
    SuperTokenConfigAccount superTokenConfigAccount;

    constructor(
        address owner_,
        uint256 fees_,
        SuperTokenEvmConstructorParams memory params_,
        bytes32 solanaProgramId_,
        address forwarderSolanaAddress_,
        address addressResolver_
    ) {
        // for evm we use standard mode with contract deployment using EVMx
        creationCodeWithArgs[superTokenEvm] = abi.encodePacked(
            type(SuperToken).creationCode,
            abi.encode(
                params_.name_,
                params_.symbol_,
                params_.decimals_,
                params_.initialSupplyHolder_,
                params_.initialSupply_
            )
        );
        // for Solana we just pass the programId(program address)
        solanaProgramId = solanaProgramId_;
        forwarderSolana = ForwarderSolana(forwarderSolanaAddress_);

        // sets the fees data like max fees, chain and token for all transfers
        // they can be updated for each transfer as well
        _setMaxFees(fees_);
        _initializeOwner(owner_);
        _initializeAppGateway(addressResolver_);
    }

    function deployEvmContract(uint32 chainSlug_) external async {
        bytes memory initData = abi.encodeWithSelector(SuperToken.setOwner.selector, owner());
        _deploy(superTokenEvm, chainSlug_, IsPlug.YES, initData);
    }

    // no need to call this directly, will be called automatically after all contracts are deployed.
    // check AppGatewayBase._deploy and AppGatewayBase.onRequestComplete
    function initializeOnChain(uint32) public pure override {
        return;
    }

    function getForwarderSolanaAddressResolver() external view returns (address) {
        return address(forwarderSolana.addressResolver__());
    }

    function transfer(
        bytes memory order_,
        SolanaInstruction memory solanaInstruction
    ) external async {
        TransferOrderEvmToSolana memory order = abi.decode(order_, (TransferOrderEvmToSolana));
        ISuperToken(order.srcEvmToken).burn(order.userEvm, order.srcAmount);

        // SolanaInstruction memory solanaInstruction = buildSolanaInstruction(order);

        /// we are directly calling the ForwarderSolana
        forwarderSolana.callSolana(abi.encode(solanaInstruction), solanaInstruction.data.programId);

        emit Transferred(_getCurrentRequestCount());
    }

    function mintSuperTokenEvm(bytes memory order_) external async {
        TransferOrderEvmToSolana memory order = abi.decode(order_, (TransferOrderEvmToSolana));
        ISuperToken(order.srcEvmToken).mint(order.userEvm, order.srcAmount);

        emit Transferred(_getCurrentRequestCount());
    }

    function mintSuperTokenSolana(SolanaInstruction memory solanaInstruction) external async {
        // we are directly calling the ForwarderSolana
        forwarderSolana.callSolana(abi.encode(solanaInstruction), solanaInstruction.data.programId);

        emit Transferred(_getCurrentRequestCount());
    }

    function transferForDebug(SolanaInstruction memory solanaInstruction) external async {
        // ISuperToken(order.srcEvmToken).burn(order.userEvm, order.srcAmount);

        // we are directly calling the ForwarderSolana
        
        forwarderSolana.callSolana(abi.encode(solanaInstruction), solanaInstruction.data.programId);

        emit Transferred(_getCurrentRequestCount());
    }

    function readSuperTokenConfigAccount(
        SolanaReadRequest memory solanaReadRequest,
        GenericSchema memory genericSchema
    ) external async {
        _setOverrides(Read.ON);
        forwarderSolana.callSolana(abi.encode(solanaReadRequest), solanaReadRequest.accountToRead);
        then(this.storeAndDecodeSuperTokenConfigAccount.selector, abi.encode(genericSchema));
    }

    function storeAndDecodeSuperTokenConfigAccount(bytes memory data, bytes memory returnData) external async {
        GenericSchema memory genericSchema = abi.decode(data, (GenericSchema));
        bytes[] memory parsedData = BorshDecoder.decodeGenericSchema(genericSchema, returnData);

        uint8[] memory decodedDiscriminatorArray = abi.decode(parsedData[0], (uint8[]));
        bytes8 decodedDiscriminator = bytes8(BorshEncoder.packUint8Array(decodedDiscriminatorArray));
        uint8[] memory decodedOwnerArray = abi.decode(parsedData[1], (uint8[]));
        bytes32 decodedOwner = bytes32(BorshEncoder.packUint8Array(decodedOwnerArray));
        uint8[] memory decodedSocketArray = abi.decode(parsedData[2], (uint8[]));
        bytes32 decodedSocket = bytes32(BorshEncoder.packUint8Array(decodedSocketArray));
        uint8[] memory decodedMintArray = abi.decode(parsedData[3], (uint8[]));
        bytes32 decodedMint = bytes32(BorshEncoder.packUint8Array(decodedMintArray));
        uint8 decodedBump = abi.decode(parsedData[4], (uint8));

        SuperTokenConfigAccount memory decodedSuperTokenConfigAccount = SuperTokenConfigAccount({
            accountDiscriminator: decodedDiscriminator,
            owner: decodedOwner,
            socket: decodedSocket,
            mint: decodedMint,
            bump: decodedBump
        });

        superTokenConfigAccount = decodedSuperTokenConfigAccount;

        emit SuperTokenConfigAccountRead(decodedSuperTokenConfigAccount);
    }

    function readTokenAccount(SolanaReadRequest memory solanaReadRequest) external async {
        _setOverrides(Read.ON);

        forwarderSolana.callSolana(abi.encode(solanaReadRequest), solanaReadRequest.accountToRead);
        then(this.storeTokenAccountData.selector, abi.encode(solanaReadRequest.accountToRead));
    }

    function storeTokenAccountData(bytes memory data, bytes memory returnData) external async {
        bytes32 tokenAccountAddress = abi.decode(data, (bytes32));
        (uint64 amount, uint64 decimals) = abi.decode(returnData, (uint64, uint64));
        solanaTokenBalances[tokenAccountAddress] = SolanaTokenBalance({
            amount: amount,
            decimals: decimals
        });

        emit TokenAccountRead(tokenAccountAddress, amount, decimals);
    }

    /*
    function buildSolanaInstruction(
        TransferOrderEvmToSolana memory order
    ) internal view returns (SolanaInstruction memory) {
        // May be subject to change
        bytes32[] memory accounts = new bytes32[](5);
        // accounts 0 - destination user wallet
        accounts[0] = order.destUserTokenAddress;
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
    */
}
