// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {BorshEncoder} from "../contracts/evmx/watcher/BorshEncoder.sol";
import {BorshDecoder} from "../contracts/evmx/watcher/BorshDecdoer.sol";
import "../contracts/utils/common/Structs.sol";
import "forge-std/console.sol";

contract BorshDecoderTest is Test {
    using BorshDecoder for BorshDecoder.Data;

    /** Test primitive type decoding **/

    function testDecodeU8() public pure {
        uint8 originalValue = 42;
        bytes1 encoded = BorshEncoder.encodeU8(originalValue);
        
        BorshDecoder.Data memory data = BorshDecoder.from(abi.encodePacked(encoded));
        uint8 decoded = data.decodeU8();
        
        assertEq(decoded, originalValue);
    }

    function testDecodeU16() public pure {
        uint16 originalValue = 0x1234;
        bytes2 encoded = BorshEncoder.encodeU16(originalValue);
        
        BorshDecoder.Data memory data = BorshDecoder.from(abi.encodePacked(encoded));
        uint16 decoded = data.decodeU16();
        
        assertEq(decoded, originalValue);
    }

    function testDecodeU32() public pure {
        uint32 originalValue = 0x12345678;
        bytes4 encoded = BorshEncoder.encodeU32(originalValue);
        
        BorshDecoder.Data memory data = BorshDecoder.from(abi.encodePacked(encoded));
        uint32 decoded = data.decodeU32();
        
        assertEq(decoded, originalValue);
    }

    function testDecodeU64() public pure {
        uint64 originalValue = 0x123456789abcdef0;
        bytes8 encoded = BorshEncoder.encodeU64(originalValue);
        
        BorshDecoder.Data memory data = BorshDecoder.from(abi.encodePacked(encoded));
        uint64 decoded = data.decodeU64();
        
        assertEq(decoded, originalValue);
    }

    function testDecodeU128() public pure {
        uint128 originalValue = 0x123456789abcdef0fedcba9876543210;
        bytes16 encoded = BorshEncoder.encodeU128(originalValue);
        
        BorshDecoder.Data memory data = BorshDecoder.from(abi.encodePacked(encoded));
        uint128 decoded = data.decodeU128();
        
        assertEq(decoded, originalValue);
    }

    function testDecodeString() public pure {
        string memory originalValue = "hello world";
        bytes memory encoded = BorshEncoder.encodeString(originalValue);
        
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        string memory decoded = data.decodeString();
        
        assertEq(decoded, originalValue);
    }

    function testDecodeStringEmpty() public pure {
        string memory originalValue = "";
        bytes memory encoded = BorshEncoder.encodeString(originalValue);
        
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        string memory decoded = data.decodeString();
        
        assertEq(decoded, originalValue);
    }

    function testDecodeStringSpecialChars() public pure {
        string memory originalValue = "0.1.0";
        bytes memory encoded = BorshEncoder.encodeString(originalValue);

        console.log("encoded 0.1.0");
        console.logBytes(encoded);
        
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        string memory decoded = data.decodeString();
        
        assertEq(decoded, originalValue);
    }

    /** Test Vector type decoding **/

    function testDecodeUint8Vec() public pure {
        uint8[] memory originalValues = new uint8[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint8Vec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, uint8[] memory decoded) = data.decodeUint8Vec();
        
        assertEq(length, originalValues.length);
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint8VecEmpty() public pure {
        uint8[] memory originalValues = new uint8[](0);
        
        bytes memory encoded = BorshEncoder.encodeUint8Vec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, uint8[] memory decoded) = data.decodeUint8Vec();
        
        assertEq(length, 0);
        assertEq(decoded.length, 0);
    }

    function testDecodeUint8VecLarge() public pure {
        uint8[] memory originalValues = new uint8[](255);
        for (uint256 i = 0; i < 255; i++) {
            originalValues[i] = uint8(i);
        }
        
        bytes memory encoded = BorshEncoder.encodeUint8Vec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, uint8[] memory decoded) = data.decodeUint8Vec();
        
        assertEq(length, originalValues.length);
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint16Vec() public pure {
        uint16[] memory originalValues = new uint16[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint16Vec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, uint16[] memory decoded) = data.decodeUint16Vec();
        
        assertEq(length, originalValues.length);
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint32Vec() public pure {
        uint32[] memory originalValues = new uint32[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint32Vec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, uint32[] memory decoded) = data.decodeUint32Vec();
        
        assertEq(length, originalValues.length);
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint64Vec() public pure {
        uint64[] memory originalValues = new uint64[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint64Vec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, uint64[] memory decoded) = data.decodeUint64Vec();
        
        assertEq(length, originalValues.length);
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint128Vec() public pure {
        uint128[] memory originalValues = new uint128[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint128Vec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, uint128[] memory decoded) = data.decodeUint128Vec();
        
        assertEq(length, originalValues.length);
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeStringVec() public pure {
        string[] memory originalValues = new string[](3);
        originalValues[0] = "hello";
        originalValues[1] = "world";
        originalValues[2] = "test";
        
        bytes memory encoded = BorshEncoder.encodeStringVec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, string[] memory decoded) = data.decodeStringVec();
        
        assertEq(length, originalValues.length);
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeStringVecEmpty() public pure {
        string[] memory originalValues = new string[](0);
        
        bytes memory encoded = BorshEncoder.encodeStringVec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, string[] memory decoded) = data.decodeStringVec();
        
        assertEq(length, 0);
        assertEq(decoded.length, 0);
    }

    function testDecodeStringVecWithEmptyStrings() public pure {
        string[] memory originalValues = new string[](3);
        originalValues[0] = "";
        originalValues[1] = "hello";
        originalValues[2] = "";
        
        bytes memory encoded = BorshEncoder.encodeStringVec(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        (uint32 length, string[] memory decoded) = data.decodeStringVec();
        
        assertEq(length, originalValues.length);
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    /** Test Array type decoding **/

    function testDecodeUint8Array() public pure {
        uint8[] memory originalValues = new uint8[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint8Array(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        uint8[] memory decoded = data.decodeUint8Array(3);
        
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint8ArrayEmpty() public pure {
        uint8[] memory originalValues = new uint8[](0);
        
        bytes memory encoded = BorshEncoder.encodeUint8Array(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        uint8[] memory decoded = data.decodeUint8Array(0);
        
        assertEq(decoded.length, 0);
    }

    function testDecodeUint8ArrayLarge() public pure {
        uint8[] memory originalValues = new uint8[](100);
        for (uint256 i = 0; i < 100; i++) {
            originalValues[i] = uint8(i % 256);
        }
        
        bytes memory encoded = BorshEncoder.encodeUint8Array(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        uint8[] memory decoded = data.decodeUint8Array(100);
        
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint16Array() public pure {
        uint16[] memory originalValues = new uint16[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint16Array(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        uint16[] memory decoded = data.decodeUint16Array(3);
        
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint32Array() public pure {
        uint32[] memory originalValues = new uint32[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint32Array(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        uint32[] memory decoded = data.decodeUint32Array(3);
        
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint64Array() public pure {
        uint64[] memory originalValues = new uint64[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint64Array(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        uint64[] memory decoded = data.decodeUint64Array(3);
        
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeUint128Array() public pure {
        uint128[] memory originalValues = new uint128[](3);
        originalValues[0] = 1;
        originalValues[1] = 2;
        originalValues[2] = 3;
        
        bytes memory encoded = BorshEncoder.encodeUint128Array(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        uint128[] memory decoded = data.decodeUint128Array(3);
        
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeStringArray() public pure {
        string[] memory originalValues = new string[](3);
        originalValues[0] = "hello";
        originalValues[1] = "world";
        originalValues[2] = "test";
        
        bytes memory encoded = BorshEncoder.encodeStringArray(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        string[] memory decoded = data.decodeStringArray(3);
        
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    function testDecodeStringArrayEmpty() public pure {
        string[] memory originalValues = new string[](0);
        
        bytes memory encoded = BorshEncoder.encodeStringArray(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        string[] memory decoded = data.decodeStringArray(0);
        
        assertEq(decoded.length, 0);
    }

    function testDecodeStringArrayWithEmptyStrings() public pure {
        string[] memory originalValues = new string[](2);
        originalValues[0] = "";
        originalValues[1] = "test";
        
        bytes memory encoded = BorshEncoder.encodeStringArray(originalValues);
        BorshDecoder.Data memory data = BorshDecoder.from(encoded);
        string[] memory decoded = data.decodeStringArray(2);
        
        assertEq(decoded.length, originalValues.length);
        for (uint256 i = 0; i < decoded.length; i++) {
            assertEq(decoded[i], originalValues[i]);
        }
    }

    /** Test GenericSchema decoding **/

    function testDecodeGenericSchemaPrimitives() public pure {
        GenericSchema memory schema;
        schema.valuesTypeNames = new string[](5);
        schema.valuesTypeNames[0] = "u8";
        schema.valuesTypeNames[1] = "u16";
        schema.valuesTypeNames[2] = "u32";
        schema.valuesTypeNames[3] = "u64";
        schema.valuesTypeNames[4] = "u128";
        
        // Encode test data
        bytes memory encodedData = abi.encodePacked(
            BorshEncoder.encodeU8(42),
            BorshEncoder.encodeU16(1234),
            BorshEncoder.encodeU32(0x12345678),
            BorshEncoder.encodeU64(0x123456789abcdef0),
            BorshEncoder.encodeU128(0x123456789abcdef0fedcba9876543210)
        );
        
        bytes[] memory decodedParams = BorshDecoder.decodeGenericSchema(schema, encodedData);
        
        assertEq(decodedParams.length, 5);
        
        // Check decoded values
        uint8 decodedU8 = abi.decode(decodedParams[0], (uint8));
        assertEq(decodedU8, 42);
        
        uint16 decodedU16 = abi.decode(decodedParams[1], (uint16));
        assertEq(decodedU16, 1234);
        
        uint32 decodedU32 = abi.decode(decodedParams[2], (uint32));
        assertEq(decodedU32, 0x12345678);
        
        uint64 decodedU64 = abi.decode(decodedParams[3], (uint64));
        assertEq(decodedU64, 0x123456789abcdef0);
        
        uint128 decodedU128 = abi.decode(decodedParams[4], (uint128));
        assertEq(decodedU128, 0x123456789abcdef0fedcba9876543210);
    }

    function testDecodeGenericSchemaVectors() public pure {
        GenericSchema memory schema;
        schema.valuesTypeNames = new string[](1);
        schema.valuesTypeNames[0] = "Vec<u8>";
        
        // Prepare test data
        uint8[] memory u8Values = new uint8[](3);
        u8Values[0] = 1;
        u8Values[1] = 2;
        u8Values[2] = 3;
        
        // Encode test data
        bytes memory encodedData = BorshEncoder.encodeUint8Vec(u8Values);
        
        bytes[] memory decodedParams = BorshDecoder.decodeGenericSchema(schema, encodedData);
        
        assertEq(decodedParams.length, 1);
        
        // Check decoded u8 vector
        uint8[] memory decodedU8Vec = abi.decode(decodedParams[0], (uint8[]));
        assertEq(decodedU8Vec.length, 3);
        assertEq(decodedU8Vec[0], 1);
        assertEq(decodedU8Vec[1], 2);
        assertEq(decodedU8Vec[2], 3);
    }

    function testDecodeGenericSchemaArrays() public pure {
        GenericSchema memory schema;
        schema.valuesTypeNames = new string[](2);
        schema.valuesTypeNames[0] = "[u8; 3]";
        schema.valuesTypeNames[1] = "[u16; 2]";
        
        // Prepare test data
        uint8[] memory u8Values = new uint8[](3);
        u8Values[0] = 1;
        u8Values[1] = 2;
        u8Values[2] = 3;
        
        uint16[] memory u16Values = new uint16[](2);
        u16Values[0] = 1000;
        u16Values[1] = 2000;

        // console.log("u8Values");
        // console.logBytes(BorshEncoder.encodeUint8Array(u8Values));

        // console.log("u16Values");
        // console.logBytes(BorshEncoder.encodeUint16Array(u16Values));
        
        // Encode test data
        bytes memory encodedData = abi.encodePacked(
            BorshEncoder.encodeUint8Array(u8Values),
            BorshEncoder.encodeUint16Array(u16Values)
        );

        // console.log("encodedData");
        // console.logBytes(encodedData);

        // console.log("decode data");
        
        bytes[] memory decodedParams = BorshDecoder.decodeGenericSchema(schema, encodedData);
        
        assertEq(decodedParams.length, 2);

        // console.log("decodedParams[0]");
        // console.logBytes(decodedParams[0]);
        
        // Check decoded u8 array
        uint8[] memory decodedU8Array = abi.decode(decodedParams[0], (uint8[]));
        assertEq(decodedU8Array.length, 3);
        assertEq(decodedU8Array[0], 1);
        assertEq(decodedU8Array[1], 2);
        assertEq(decodedU8Array[2], 3);

        // console.log("decodedParams[1]");
        // console.logBytes(decodedParams[1]);
        
        // Check decoded u16 array
        uint16[] memory decodedU16Array = abi.decode(decodedParams[1], (uint16[]));
        assertEq(decodedU16Array.length, 2);
        assertEq(decodedU16Array[0], 1000);
        assertEq(decodedU16Array[1], 2000);
    }

    function testDecodeGenericSchemaComplex() public pure {
        GenericSchema memory schema;
        schema.valuesTypeNames = new string[](6);
        schema.valuesTypeNames[0] = "u8";
        schema.valuesTypeNames[1] = "u32";
        schema.valuesTypeNames[2] = "u64";
        schema.valuesTypeNames[3] = "u64";
        schema.valuesTypeNames[4] = "[u8; 4]";
        schema.valuesTypeNames[5] = "[u32; 10]";
        
        // Prepare test data
        uint8 u8Value = 42;
        uint32 u32Value = 0x12345678;
        uint64 u64Value1 = 0x123456789abcdef0;
        uint64 u64Value2 = 0xfedcba9876543210;
        
        uint8[] memory u8Array = new uint8[](4);
        u8Array[0] = 10;
        u8Array[1] = 20;
        u8Array[2] = 30;
        u8Array[3] = 40;
        
        uint32[] memory u32Array = new uint32[](10);
        for (uint256 i = 0; i < 10; i++) {
            u32Array[i] = uint32(1000 + i * 100); // 1000, 1100, 1200, ..., 1900
        }
        
        // Encode test data
        bytes memory encodedData = abi.encodePacked(
            BorshEncoder.encodeU8(u8Value),
            BorshEncoder.encodeU32(u32Value),
            BorshEncoder.encodeU64(u64Value1),
            BorshEncoder.encodeU64(u64Value2),
            BorshEncoder.encodeUint8Array(u8Array),
            BorshEncoder.encodeUint32Array(u32Array)
        );
        
        // Decode using GenericSchema
        bytes[] memory decodedParams = BorshDecoder.decodeGenericSchema(schema, encodedData);
        
        assertEq(decodedParams.length, 6);
        
        // Check decoded u8
        uint8 decodedU8 = abi.decode(decodedParams[0], (uint8));
        assertEq(decodedU8, u8Value);
        
        // Check decoded u32
        uint32 decodedU32 = abi.decode(decodedParams[1], (uint32));
        assertEq(decodedU32, u32Value);
        
        // Check decoded u64 (first)
        uint64 decodedU64_1 = abi.decode(decodedParams[2], (uint64));
        assertEq(decodedU64_1, u64Value1);
        
        // Check decoded u64 (second)
        uint64 decodedU64_2 = abi.decode(decodedParams[3], (uint64));
        assertEq(decodedU64_2, u64Value2);
        
        // Check decoded u8 array [u8; 4]
        uint8[] memory decodedU8Array = abi.decode(decodedParams[4], (uint8[]));
        assertEq(decodedU8Array.length, 4);
        assertEq(decodedU8Array[0], 10);
        assertEq(decodedU8Array[1], 20);
        assertEq(decodedU8Array[2], 30);
        assertEq(decodedU8Array[3], 40);
        
        // Check decoded u32 array [u32; 10]
        uint32[] memory decodedU32Array = abi.decode(decodedParams[5], (uint32[]));
        assertEq(decodedU32Array.length, 10);
        for (uint256 i = 0; i < 10; i++) {
            assertEq(decodedU32Array[i], uint32(1000 + i * 100));
        }
    }

    function testDecodeGenericSchemaWithStrings() public pure {
        GenericSchema memory schema;
        schema.valuesTypeNames = new string[](4);
        schema.valuesTypeNames[0] = "String";
        schema.valuesTypeNames[1] = "u32";
        schema.valuesTypeNames[2] = "Vec<String>";
        schema.valuesTypeNames[3] = "[String; 2]";
        
        // Prepare test data
        string memory singleString = "hello world";
        uint32 numberValue = 42;
        
        string[] memory stringVec = new string[](2);
        stringVec[0] = "vec1";
        stringVec[1] = "vec2";
        
        string[] memory stringArray = new string[](2);
        stringArray[0] = "array1";
        stringArray[1] = "array2";
        
        // Encode test data
        bytes memory encodedData = abi.encodePacked(
            BorshEncoder.encodeString(singleString),
            BorshEncoder.encodeU32(numberValue),
            BorshEncoder.encodeStringVec(stringVec),
            BorshEncoder.encodeStringArray(stringArray)
        );
        
        // Decode using GenericSchema
        bytes[] memory decodedParams = BorshDecoder.decodeGenericSchema(schema, encodedData);
        
        assertEq(decodedParams.length, 4);
        
        // Check decoded string
        string memory decodedString = abi.decode(decodedParams[0], (string));
        assertEq(decodedString, singleString);
        
        // Check decoded u32
        uint32 decodedU32 = abi.decode(decodedParams[1], (uint32));
        assertEq(decodedU32, numberValue);
        
        // Check decoded string vector
        string[] memory decodedStringVec = abi.decode(decodedParams[2], (string[]));
        assertEq(decodedStringVec.length, 2);
        assertEq(decodedStringVec[0], "vec1");
        assertEq(decodedStringVec[1], "vec2");
        
        // Check decoded string array
        string[] memory decodedStringArray = abi.decode(decodedParams[3], (string[]));
        assertEq(decodedStringArray.length, 2);
        assertEq(decodedStringArray[0], "array1");
        assertEq(decodedStringArray[1], "array2");
    }

    /** Real-life Solana accounts decoding **/

    function testDecodeSolanaSocketConfigAccount() public {
        GenericSchema memory schema;
        schema.valuesTypeNames = new string[](5);
        schema.valuesTypeNames[0] = "[u8;8]"; // account discriminator
        schema.valuesTypeNames[1] = "[u8;32]";
        schema.valuesTypeNames[2] = "u32";
        schema.valuesTypeNames[3] = "String";
        schema.valuesTypeNames[4] = "u8";

        bytes8 discriminator = 0x9b0caae01efacc82;
        bytes32 owner = 0x0c1a5886fe1093df9fc438c296f9f7275b7718b6bc0e156d8d336c58f083996d;
        uint32 chain_slug = 10000002;
        string memory version = "0.1.0";
        uint8 bump = 255;

        bytes memory solanaEncodedData = hex"9b0caae01efacc820c1a5886fe1093df9fc438c296f9f7275b7718b6bc0e156d8d336c58f083996d8296980005000000302e312e30ff0000000000";

        bytes[] memory decodedParams = BorshDecoder.decodeGenericSchema(schema, solanaEncodedData);

        assertEq(decodedParams.length, 5);

        console.log("decoded discriminator");
        // console.logBytes(decodedParams[0]);
        uint8[] memory decodedDiscriminator = abi.decode(decodedParams[0], (uint8[]));
        bytes memory packedUint8Array = BorshEncoder.packUint8Array(decodedDiscriminator);
        assertEq(packedUint8Array, abi.encodePacked(discriminator));

        console.log("decoded owner");
        uint8[] memory decodedOwner = abi.decode(decodedParams[1], (uint8[]));
        packedUint8Array = BorshEncoder.packUint8Array(decodedOwner);
        assertEq(packedUint8Array, abi.encodePacked(owner));

        console.log("decoded chain_slug");
        uint32 decodedChainSlug = abi.decode(decodedParams[2], (uint32));
        assertEq(decodedChainSlug, chain_slug);

        console.log("decoded version");
        string memory decodedVersion = abi.decode(decodedParams[3], (string));
        console.log("decodedVersion");
        console.log(decodedVersion);
        assertEq(decodedVersion, version);

        console.log("decoded bump");
        uint8 decodedBump = abi.decode(decodedParams[4], (uint8));
        assertEq(decodedBump, bump);
    }

    function testDecodeSuperTokenConfigGenericSchema() public pure {
        GenericSchema memory schema;
        schema.valuesTypeNames = new string[](5);
        schema.valuesTypeNames[0] = "[u8;8]";   // account discriminator
        schema.valuesTypeNames[1] = "[u8;32]";
        schema.valuesTypeNames[2] = "[u8;32]";
        schema.valuesTypeNames[3] = "[u8;32]";
        schema.valuesTypeNames[4] = "u8";

        bytes8 discriminator = 0x9b0caae01efacc82;
        bytes32 owner = 0x0c1a5886fe1093df9fc438c296f9f7275b7718b6bc0e156d8d336c58f083996d;
        bytes32 socket = 0x0000000000000000000000000000000000000000000000000000000000000000;
        bytes32 mint = 0x9ded6d20f1f5b9c56cb90ef89fc52d355aaaa868c42738eff11f50d1f81f522a;
        uint8 bump = 255;

        bytes memory solanaEncodedData = hex"9b0caae01efacc820c1a5886fe1093df9fc438c296f9f7275b7718b6bc0e156d8d336c58f083996d00000000000000000000000000000000000000000000000000000000000000009ded6d20f1f5b9c56cb90ef89fc52d355aaaa868c42738eff11f50d1f81f522aff";

        bytes[] memory decodedParams = BorshDecoder.decodeGenericSchema(schema, solanaEncodedData);

        assertEq(decodedParams.length, 5);

        console.log("decoded discriminator");
        // console.logBytes(decodedParams[0]);
        uint8[] memory decodedDiscriminator = abi.decode(decodedParams[0], (uint8[]));
        console.log("decodedDiscriminator");
        console.log(decodedDiscriminator.length);
        bytes memory packedUint8Array = BorshEncoder.packUint8Array(decodedDiscriminator);
        console.logBytes(packedUint8Array);
        assertEq(packedUint8Array, abi.encodePacked(discriminator));

        console.log("decodedOwner");
        // console.logBytes(decodedParams[1]);
        uint8[] memory decodedOwner = abi.decode(decodedParams[1], (uint8[]));
        packedUint8Array = BorshEncoder.packUint8Array(decodedOwner);
        console.logBytes(packedUint8Array);
        assertEq(packedUint8Array, abi.encodePacked(owner));
        console.log("decodedSocket");
        // console.logBytes(decodedParams[2]);
        uint8[] memory decodedSocket = abi.decode(decodedParams[2], (uint8[]));
        packedUint8Array = BorshEncoder.packUint8Array(decodedSocket);
        console.logBytes(packedUint8Array);
        assertEq(packedUint8Array, abi.encodePacked(socket));
        console.log("decodedMint");
        // console.logBytes(decodedParams[3]);
        uint8[] memory decodedMint = abi.decode(decodedParams[3], (uint8[]));
        packedUint8Array = BorshEncoder.packUint8Array(decodedMint);
        console.logBytes(packedUint8Array);
        assertEq(packedUint8Array, abi.encodePacked(mint));
        console.log("decodedBump");
        // console.logBytes(decodedParams[4]);
        uint8 decodedBump = abi.decode(decodedParams[4], (uint8));
        console.log("decodedBump: ", decodedBump);
        assertEq(decodedBump, bump);
    }

    /** Test edge cases **/

    function testDecodeInsufficientData() public {
        bytes memory shortData = hex"01";
        
        // Should revert when trying to decode u16 from 1-byte data
        BorshDecoder.Data memory data = BorshDecoder.from(shortData);
        vm.expectRevert("Parse error: unexpected EOI");
        data.decodeU16();
    }

    function testDecodeOutOfBounds() public {
        bytes memory data = hex"0102";
        
        // Should revert when trying to decode u32 from 2-byte data
        BorshDecoder.Data memory decoderData = BorshDecoder.from(data);
        vm.expectRevert("Parse error: unexpected EOI");
        decoderData.decodeU32();
    }

    function testDecodeVecInsufficientLength() public {
        // Length says 10 but only 5 bytes follow
        bytes memory invalidVecData = hex"0a000000010203";
        
        BorshDecoder.Data memory data = BorshDecoder.from(invalidVecData);
        vm.expectRevert("Parse error: unexpected EOI");
        data.decodeUint8Vec();
    }

    /** Test complex scenarios **/

    function testDecodeMultipleConsecutive() public pure {
        // Encode multiple values consecutively
        bytes memory data = abi.encodePacked(
            BorshEncoder.encodeU8(42),
            BorshEncoder.encodeU16(1234),
            BorshEncoder.encodeUint8Vec(_createU8Array())
        );
        
        // Decode them one by one
        BorshDecoder.Data memory decoderData = BorshDecoder.from(data);
        
        uint8 u8Val = decoderData.decodeU8();
        assertEq(u8Val, 42);
        
        uint16 u16Val = decoderData.decodeU16();
        assertEq(u16Val, 1234);
        
        (uint32 length, uint8[] memory vecVal) = decoderData.decodeUint8Vec();
        assertEq(length, 2);
        assertEq(vecVal.length, 2);
        assertEq(vecVal[0], 1);
        assertEq(vecVal[1], 2);
        
        // Verify all data consumed
        decoderData.done();
    }

    function _createU8Array() private pure returns (uint8[] memory) {
        uint8[] memory arr = new uint8[](2);
        arr[0] = 1;
        arr[1] = 2;
        return arr;
    }
} 