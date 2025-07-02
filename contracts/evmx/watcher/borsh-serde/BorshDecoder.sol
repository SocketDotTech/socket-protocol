// SPDX-License-Identifier: GPL-3.0-only
// Based on Aurora bridge repo: https://github.com/aurora-is-near/aurora-contracts-sdk/blob/main/aurora-solidity-sdk
pragma solidity ^0.8.21;

import "../../../utils/common/Structs.sol";
import "./BorshUtils.sol";

library BorshDecoder {
    /// Decodes the borsh schema into abi.encode(value) list of params
    /// Handles decoding of: 
    ///  1. u8/u16/u32/u64 Rust types
    ///  2. "String" Rust type
    ///  3. array/Vec and String numeric Rust types (mentioned in 1) and 2))
    function decodeGenericSchema(
        GenericSchema memory schema,
        bytes memory encodedData 
    ) internal pure returns (bytes[] memory) {
        bytes[] memory decodedParams = new bytes[](schema.valuesTypeNames.length);
        Data memory data = from(encodedData);
        
        for (uint256 i = 0; i < schema.valuesTypeNames.length; i++) {
            string memory typeName = schema.valuesTypeNames[i];
            
            if (keccak256(bytes(typeName)) == keccak256(bytes("u8"))) {
                uint8 value = data.decodeU8();
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u16"))) {
                uint16 value = data.decodeU16();
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u32"))) {
                uint32 value = data.decodeU32();
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u64"))) {
                uint64 value = data.decodeU64();
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u128"))) {
                uint128 value = data.decodeU128();
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("String"))) {
                string memory value = data.decodeString();
                decodedParams[i] = abi.encode(value);
            }
            // Handle Vector types with variable length
            else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u8>"))) {
                uint32 length;
                uint8[] memory value;
                (length, value) = decodeUint8Vec(data);
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u16>"))) {
                uint32 length;
                uint16[] memory value;
                (length, value) = decodeUint16Vec(data);
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u32>"))) {
                uint32 length;
                uint32[] memory value;
                (length, value) = decodeUint32Vec(data);
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u64>"))) {
                uint32 length;
                uint64[] memory value;
                (length, value) = decodeUint64Vec(data);
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<u128>"))) {
                uint32 length;
                uint128[] memory value;
                (length, value) = decodeUint128Vec(data);
                decodedParams[i] = abi.encode(value);
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("Vec<String>"))) {
                uint32 length;
                string[] memory value;
                (length, value) = decodeStringVec(data);
                decodedParams[i] = abi.encode(value);
            }
            // Handle Array types with fixed length
            else if (BorshUtils.startsWith(typeName, "[u8;")) {
                uint256 length = BorshUtils.extractArrayLength(typeName);
                uint8[] memory value = decodeUint8Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (BorshUtils.startsWith(typeName, "[u16;")) {
                uint256 length = BorshUtils.extractArrayLength(typeName);
                uint16[] memory value = decodeUint16Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (BorshUtils.startsWith(typeName, "[u32;")) {
                uint256 length = BorshUtils.extractArrayLength(typeName);
                uint32[] memory value = decodeUint32Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (BorshUtils.startsWith(typeName, "[u64;")) {
                uint256 length = BorshUtils.extractArrayLength(typeName);
                uint64[] memory value = decodeUint64Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (BorshUtils.startsWith(typeName, "[u128;")) {
                uint256 length = BorshUtils.extractArrayLength(typeName);
                uint128[] memory value = decodeUint128Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (BorshUtils.startsWith(typeName, "[String;")) {
                uint256 length = BorshUtils.extractArrayLength(typeName);
                string[] memory value = decodeStringArray(data, length);
                decodedParams[i] = abi.encode(value);
            } else {
                revert("Unsupported type");
            }
        }
        
        return decodedParams;
    }

    /********* Decode primitive types *********/

    using BorshDecoder for Data;

    struct Data {
        uint256 ptr;
        uint256 end;
    }

    /********* Helper to manage data pointer *********/

    function from(bytes memory data) internal pure returns (Data memory res) {
        uint256 ptr;
        assembly {
            ptr := data
        }
        unchecked {
            res.ptr = ptr + 32;
            res.end = res.ptr + BorshUtils.readMemory(ptr);
        }
    }

    // This function assumes that length is reasonably small, so that data.ptr + length will not overflow. In the current code, length is always less than 2^32.
    function requireSpace(Data memory data, uint256 length) internal pure {
        unchecked {
            require(data.ptr + length <= data.end, "Parse error: unexpected EOI");
        }
    }

    function read(Data memory data, uint256 length) internal pure returns (bytes32 res) {
        data.requireSpace(length);
        res = bytes32(BorshUtils.readMemory(data.ptr));
        unchecked {
            data.ptr += length;
        }
        return res;
    }

    function done(Data memory data) internal pure {
        require(data.ptr == data.end, "Parse error: EOI expected");
    }

    /********* Decoders for primitive types *********/

    function decodeU8(Data memory data) internal pure returns (uint8) {
        return uint8(bytes1(data.read(1)));
    }

    function decodeU16(Data memory data) internal pure returns (uint16) {
        return BorshUtils.swapBytes2(uint16(bytes2(data.read(2))));
    }

    function decodeU32(Data memory data) internal pure returns (uint32) {
        return BorshUtils.swapBytes4(uint32(bytes4(data.read(4))));
    }

    function decodeU64(Data memory data) internal pure returns (uint64) {
        return BorshUtils.swapBytes8(uint64(bytes8(data.read(8))));
    }

    function decodeU128(Data memory data) internal pure returns (uint128) {
        return BorshUtils.swapBytes16(uint128(bytes16(data.read(16))));
    }

    function decodeU256(Data memory data) internal pure returns (uint256) {
        return BorshUtils.swapBytes32(uint256(data.read(32)));
    }

    function decodeBytes20(Data memory data) internal pure returns (bytes20) {
        return bytes20(data.read(20));
    }

    function decodeBytes32(Data memory data) internal pure returns (bytes32) {
        return data.read(32);
    }

    function decodeBool(Data memory data) internal pure returns (bool) {
        uint8 res = data.decodeU8();
        require(res <= 1, "Parse error: invalid bool");
        return res != 0;
    }

    function skipBytes(Data memory data) internal pure {
        uint256 length = data.decodeU32();
        data.requireSpace(length);
        unchecked {
            data.ptr += length;
        }
    }

    function decodeBytes(Data memory data) internal pure returns (bytes memory res) {
        uint256 length = data.decodeU32();
        data.requireSpace(length);
        res = BorshUtils.memoryToBytes(data.ptr, length);
        unchecked {
            data.ptr += length;
        }
    }

    function decodeString(Data memory data) internal pure returns (string memory) {
        bytes memory stringBytes = data.decodeBytes();
        return string(stringBytes);
    }

    /********* Decode Vector types with variable length *********/

    function decodeUint8Vec(Data memory data) internal pure returns (uint32, uint8[] memory) {
        uint32 length = data.decodeU32();
        uint8[] memory values = new uint8[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU8();
        }
        
        return (length, values);
    }

    function decodeUint16Vec(Data memory data) internal pure returns (uint32, uint16[] memory) {
        uint32 length = data.decodeU32();
        uint16[] memory values = new uint16[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU16();
        }
        
        return (length, values);
    }

    function decodeUint32Vec(Data memory data) internal pure returns (uint32, uint32[] memory) {
        uint32 length = data.decodeU32();
        uint32[] memory values = new uint32[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU32();
        }
        
        return (length, values);
    }

    function decodeUint64Vec(Data memory data) internal pure returns (uint32, uint64[] memory) {
        uint32 length = data.decodeU32();
        uint64[] memory values = new uint64[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU64();
        }
        
        return (length, values);
    }

    function decodeUint128Vec(Data memory data) internal pure returns (uint32, uint128[] memory) {
        uint32 length = data.decodeU32();
        uint128[] memory values = new uint128[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU128();
        }
        
        return (length, values);
    }

    function decodeStringVec(Data memory data) internal pure returns (uint32, string[] memory) {
        uint32 length = data.decodeU32();
        string[] memory values = new string[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeString();
        }
        
        return (length, values);
    }

    /********* Decode array types with fixed length *********/

    function decodeUint8Array(Data memory data, uint256 length) internal pure returns (uint8[] memory) {
        uint8[] memory values = new uint8[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU8();
        }
        
        return values;
    }

    function decodeUint16Array(Data memory data, uint256 length) internal pure returns (uint16[] memory) {
        uint16[] memory values = new uint16[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU16();
        }
        
        return values;
    }

    function decodeUint32Array(Data memory data, uint256 length) internal pure returns (uint32[] memory) {
        uint32[] memory values = new uint32[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU32();
        }
        
        return values;
    }

    function decodeUint64Array(Data memory data, uint256 length) internal pure returns (uint64[] memory) {
        uint64[] memory values = new uint64[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU64();
        }
        
        return values;
    }

    function decodeUint128Array(Data memory data, uint256 length) internal pure returns (uint128[] memory) {
        uint128[] memory values = new uint128[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeU128();
        }
        
        return values;
    }

    function decodeStringArray(Data memory data, uint256 length) internal pure returns (string[] memory) {
        string[] memory values = new string[](length);
        
        for (uint256 i = 0; i < length; i++) {
            values[i] = data.decodeString();
        }
        
        return values;
    }   
}