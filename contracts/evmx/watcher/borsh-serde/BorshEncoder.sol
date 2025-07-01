// SPDX-License-Identifier: GPL-3.0-only
// Based on Aurora bridge repo: https://github.com/aurora-is-near/aurora-contracts-sdk/blob/main/aurora-solidity-sdk
pragma solidity ^0.8.21;

import "../../../utils/common/Structs.sol";
import "./BorshUtils.sol";

library BorshEncoder {
    function encodeFunctionArgs(
        SolanaInstruction memory instruction
    ) internal pure returns (bytes memory) {
        bytes memory functionArgsPacked;
        for (uint256 i = 0; i < instruction.data.functionArguments.length; i++) {
            string memory typeName = instruction.description.functionArgumentTypeNames[i];
            bytes memory data = instruction.data.functionArguments[i];

            if (keccak256(bytes(typeName)) == keccak256(bytes("u8"))) {
                uint256 abiDecodedArg = abi.decode(data, (uint256));
                uint8 arg = uint8(abiDecodedArg);
                bytes1 borshEncodedArg = encodeU8(arg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u16"))) {
                uint256 abiDecodedArg = abi.decode(data, (uint256));
                uint16 arg = uint16(abiDecodedArg);
                bytes2 borshEncodedArg = encodeU16(arg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u32"))) {
                uint256 abiDecodedArg = abi.decode(data, (uint256));
                uint32 arg = uint32(abiDecodedArg);
                bytes4 borshEncodedArg = encodeU32(arg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u64"))) {
                uint256 abiDecodedArg = abi.decode(data, (uint256));
                uint64 arg = uint64(abiDecodedArg);
                bytes8 borshEncodedArg = encodeU64(arg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u128"))) {
                uint256 abiDecodedArg = abi.decode(data, (uint256));
                uint128 arg = uint128(abiDecodedArg);
                bytes16 borshEncodedArg = encodeU128(arg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("string"))) {
                string memory abiDecodedArg = abi.decode(data, (string));
                bytes memory borshEncodedArg = encodeString(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            }
            // Handle array types with fixed length
            else if (BorshUtils.startsWith(typeName, "[u8;")) {
                uint8[] memory abiDecodedArg = abi.decode(data, (uint8[]));
                bytes memory borshEncodedArg = encodeUint8Array(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u16[]"))) {
                uint16[] memory abiDecodedArg = abi.decode(data, (uint16[]));
                bytes memory borshEncodedArg = encodeUint16Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u32[]"))) {
                uint32[] memory abiDecodedArg = abi.decode(data, (uint32[]));
                bytes memory borshEncodedArg = encodeUint32Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u64[]"))) {
                uint64[] memory abiDecodedArg = abi.decode(data, (uint64[]));
                bytes memory borshEncodedArg = encodeUint64Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u128[]"))) {
                uint128[] memory abiDecodedArg = abi.decode(data, (uint128[]));
                bytes memory borshEncodedArg = encodeUint128Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("string[]"))) {
                string[] memory abiDecodedArg = abi.decode(data, (string[]));
                bytes memory borshEncodedArg = encodeStringArray(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            }
            // Handle Vector types with that can have variable length - length prefix is added
            else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u8>"))) {
                uint8[] memory abiDecodedArg = abi.decode(data, (uint8[]));
                bytes memory borshEncodedArg = encodeUint8Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u16>"))) {
                uint16[] memory abiDecodedArg = abi.decode(data, (uint16[]));
                bytes memory borshEncodedArg = encodeUint16Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u32>"))) {
                uint32[] memory abiDecodedArg = abi.decode(data, (uint32[]));
                bytes memory borshEncodedArg = encodeUint32Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u64>"))) {
                uint64[] memory abiDecodedArg = abi.decode(data, (uint64[]));
                bytes memory borshEncodedArg = encodeUint64Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u128>"))) {
                uint128[] memory abiDecodedArg = abi.decode(data, (uint128[]));
                bytes memory borshEncodedArg = encodeUint128Vec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<String>"))) {
                string[] memory abiDecodedArg = abi.decode(data, (string[]));
                bytes memory borshEncodedArg = encodeStringVec(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            }
            // Handle array types with fixed length - no length prefix, just the bytes
            else if (BorshUtils.startsWith(typeName, "[u8;")) {
                uint8[] memory abiDecodedArg = abi.decode(data, (uint8[]));
                bytes memory borshEncodedArg = encodeUint8Array(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (BorshUtils.startsWith(typeName, "[u16;")) {
                uint16[] memory abiDecodedArg = abi.decode(data, (uint16[]));
                bytes memory borshEncodedArg = encodeUint16Array(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (BorshUtils.startsWith(typeName, "[u32;")) {
                uint32[] memory abiDecodedArg = abi.decode(data, (uint32[]));
                bytes memory borshEncodedArg = encodeUint32Array(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (BorshUtils.startsWith(typeName, "[u64;")) {
                uint64[] memory abiDecodedArg = abi.decode(data, (uint64[]));
                bytes memory borshEncodedArg = encodeUint64Array(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (BorshUtils.startsWith(typeName, "[u128;")) {
                uint128[] memory abiDecodedArg = abi.decode(data, (uint128[]));
                bytes memory borshEncodedArg = encodeUint128Array(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else if (BorshUtils.startsWith(typeName, "[String;")) {
                string[] memory abiDecodedArg = abi.decode(data, (string[]));
                bytes memory borshEncodedArg = encodeStringArray(abiDecodedArg);
                functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
            } else {
                revert("Unsupported type");
            }
        }
        return functionArgsPacked;
    }

    /********* Encode functions *********/

    /** Encode primitive types **/

    function encodeU8(uint8 v) internal pure returns (bytes1) {
        return bytes1(v);
    }

    function encodeU16(uint16 v) internal pure returns (bytes2) {
        return bytes2(BorshUtils.swapBytes2(v));
    }

    function encodeU32(uint32 v) internal pure returns (bytes4) {
        return bytes4(BorshUtils.swapBytes4(v));
    }

    function encodeU64(uint64 v) internal pure returns (bytes8) {
        return bytes8(BorshUtils.swapBytes8(v));
    }

    function encodeU128(uint128 v) internal pure returns (bytes16) {
        return bytes16(BorshUtils.swapBytes16(v));
    }

    /// Encode bytes vector into borsh. Use this method to encode strings as well.
    function encodeBytes(bytes memory value) internal pure returns (bytes memory) {
        return abi.encodePacked(encodeU32(uint32(value.length)), bytes(value));
    }

    function encodeString(string memory value) internal pure returns (bytes memory) {
        bytes memory strBytes = bytes(value);
        return bytes.concat(encodeU32(uint32(strBytes.length)), strBytes);
    }

    /** Encode Vector types with that can have variable length **/

    function encodeUint8Vec(uint8[] memory arr) internal pure returns (bytes memory) {
        bytes memory packed = packUint8Array(arr);
        return bytes.concat(encodeU32(uint32(arr.length)), packed);
    }

    function encodeUint16Vec(uint16[] memory arr) internal pure returns (bytes memory) {
        bytes memory packed = packUint16Array(arr);
        return bytes.concat(encodeU32(uint32(arr.length)), packed);
    }

    function encodeUint32Vec(uint32[] memory arr) internal pure returns (bytes memory) {
        bytes memory packed = packUint32Array(arr);
        return bytes.concat(encodeU32(uint32(arr.length)), packed);
    }

    function encodeUint64Vec(uint64[] memory arr) internal pure returns (bytes memory) {
        bytes memory packed = packUint64Array(arr);
        return bytes.concat(encodeU32(uint32(arr.length)), packed);
    }

    function encodeUint128Vec(uint128[] memory arr) internal pure returns (bytes memory) {
        bytes memory packed = packUint128Array(arr);
        return bytes.concat(encodeU32(uint32(arr.length)), packed);
    }

    function encodeStringVec(string[] memory arr) internal pure returns (bytes memory) {
        bytes memory packed = packStringArray(arr);
        return bytes.concat(encodeU32(uint32(arr.length)), packed);
    }

    /** Encode array types with fixed length - no length prefix, just the bytes **/

    function encodeUint8Array(uint8[] memory arr) internal pure returns (bytes memory) {
        return packUint8Array(arr);
    }

    function encodeUint16Array(uint16[] memory arr) internal pure returns (bytes memory) {
        return packUint16Array(arr);
    }

    function encodeUint32Array(uint32[] memory arr) internal pure returns (bytes memory) {
        return packUint32Array(arr);
    }

    function encodeUint64Array(uint64[] memory arr) internal pure returns (bytes memory) {
        return packUint64Array(arr);
    }

    function encodeUint128Array(uint128[] memory arr) internal pure returns (bytes memory) {
        return packUint128Array(arr);
    }

    function encodeStringArray(string[] memory arr) internal pure returns (bytes memory) {
        return packStringArray(arr);
    }

    /********* Packing functions *********/

    // NOTE:
    // When you use abi.encodePacked() on a dynamic array (uint8[]), Solidity applies ABI encoding rules where each array element gets padded to 32 bytes:
    // this is why when you have:
    //uint8[] memory value = new uint8[](3);
    // value[0] = 1;
    // value[1] = 2;
    // value[2] = 3;
    // bytes memory encoded = abi.encodePacked(value);
    // console.logBytes(encoded);
    // you get:
    // 0x000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003
    // cause each element is padded to 32 bytes

    // --> Below function packs the array into elements without the padding

    function packUint8Array(uint8[] memory arr) internal pure returns (bytes memory) {
        bytes memory out;
        for (uint i = 0; i < arr.length; i++) {
            out = bytes.concat(out, encodeU8(arr[i]));
        }
        return out;
    }

    function packUint16Array(uint16[] memory arr) internal pure returns (bytes memory) {
        bytes memory out;
        for (uint256 i = 0; i < arr.length; i++) {
            out = bytes.concat(out, encodeU16(arr[i]));
        }
        return out;
    }

    function packUint32Array(uint32[] memory arr) internal pure returns (bytes memory) {
        bytes memory out;
        for (uint256 i = 0; i < arr.length; i++) {
            out = bytes.concat(out, encodeU32(arr[i]));
        }
        return out;
    }

    function packUint64Array(uint64[] memory arr) internal pure returns (bytes memory) {
        bytes memory out;
        for (uint256 i = 0; i < arr.length; i++) {
            out = bytes.concat(out, encodeU64(arr[i]));
        }
        return out;
    }

    function packUint128Array(uint128[] memory arr) internal pure returns (bytes memory) {
        bytes memory out;
        for (uint256 i = 0; i < arr.length; i++) {
            out = bytes.concat(out, encodeU128(arr[i]));
        }
        return out;
    }

    function packStringArray(string[] memory arr) internal pure returns (bytes memory) {
        bytes memory out;
        for (uint256 i = 0; i < arr.length; i++) {
            out = bytes.concat(out, encodeString(arr[i]));
        }
        return out;
    }
}
