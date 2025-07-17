// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {GenericSchema} from "../contracts/utils/common/Structs.sol";
import "../contracts/utils/common/Constants.sol";
import {BorshDecoder} from "../contracts/evmx/watcher/borsh-serde/BorshDecoder.sol";
import {BorshEncoder} from "../contracts/evmx/watcher/borsh-serde/BorshEncoder.sol";
import "forge-std/console.sol";

contract ReturnValueSolanaTest is Test {
    function testDecoding() public {
        string[] memory returnDataValuesTypeNames = new string[](2);
        returnDataValuesTypeNames[0] = "[u8; 32]";
        returnDataValuesTypeNames[1] = "Vec<u8>";

        GenericSchema memory returnDataSchema = GenericSchema({
            valuesTypeNames: returnDataValuesTypeNames
        });
        
        bytes memory returnData = hex"0c1a5886fe1093df9fc438c296f9f7275b7718b6bc0e156d8d336c58f083996d0400000001020304";

        // GenericSchema memory genericSchema = abi.decode(data, (GenericSchema));
        bytes[] memory parsedData = BorshDecoder.decodeGenericSchema(returnDataSchema, returnData);

        uint8[] memory transmitterSolanaArray = abi.decode(parsedData[0], (uint8[]));
        bytes memory transmitterSolana = BorshEncoder.packUint8Array(transmitterSolanaArray);

        uint8[] memory returnValueArray = abi.decode(parsedData[1], (uint8[]));
        bytes memory returnValue = BorshEncoder.packUint8Array(returnValueArray);

        console.logBytes(transmitterSolana);
        console.logBytes(returnValue);

        // bytes32 hexadecimal representation of solana transmitter address
        assertEq(transmitterSolana, hex"0c1a5886fe1093df9fc438c296f9f7275b7718b6bc0e156d8d336c58f083996d");
        // 4 bytes with values: 1, 2, 3, 4
        assertEq(returnValue, hex"01020304");
    }
}