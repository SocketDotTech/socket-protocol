// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../utils/common/Structs.sol";

library BorshDecoder {
    // decodes the borsh schema into abi.encode(value) list of params
    // all numeric u8/u16/u32/u64 borsh types are decoded and abi encoded as uint256
    // borsh "String" is decoded and abi encoded as string
    // all array/Vec numeric borsh types are decoded and abi encoded as uint256[]
    // array/Vec of String borsh type is decoded and encoded string[]
    // finally all abi encoded params are returned as bytes[] preserving the same order as in GenericSchema
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
                decodedParams[i] = abi.encode(uint256(value));
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u16"))) {
                uint16 value = data.decodeU16();
                decodedParams[i] = abi.encode(uint256(value));
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u32"))) {
                uint32 value = data.decodeU32();
                decodedParams[i] = abi.encode(uint256(value));
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u64"))) {
                uint64 value = data.decodeU64();
                decodedParams[i] = abi.encode(uint256(value));
            } else if (keccak256(bytes(typeName)) == keccak256(bytes("u128"))) {
                uint128 value = data.decodeU128();
                decodedParams[i] = abi.encode(uint256(value));
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
            else if (startsWith(typeName, "[u8;")) {
                uint256 length = extractArrayLength(typeName);
                uint8[] memory value = decodeUint8Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (startsWith(typeName, "[u16;")) {
                uint256 length = extractArrayLength(typeName);
                uint16[] memory value = decodeUint16Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (startsWith(typeName, "[u32;")) {
                uint256 length = extractArrayLength(typeName);
                uint32[] memory value = decodeUint32Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (startsWith(typeName, "[u64;")) {
                uint256 length = extractArrayLength(typeName);
                uint64[] memory value = decodeUint64Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (startsWith(typeName, "[u128;")) {
                uint256 length = extractArrayLength(typeName);
                uint128[] memory value = decodeUint128Array(data, length);
                decodedParams[i] = abi.encode(value);
            } else if (startsWith(typeName, "[String;")) {
                uint256 length = extractArrayLength(typeName);
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

    function from(bytes memory data) internal pure returns (Data memory res) {
        uint256 ptr;
        assembly {
            ptr := data
        }
        unchecked {
            res.ptr = ptr + 32;
            res.end = res.ptr + readMemory(ptr);
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
        res = bytes32(readMemory(data.ptr));
        unchecked {
            data.ptr += length;
        }
        return res;
    }

    function done(Data memory data) internal pure {
        require(data.ptr == data.end, "Parse error: EOI expected");
    }

    function decodeU8(Data memory data) internal pure returns (uint8) {
        return uint8(bytes1(data.read(1)));
    }

    function decodeU16(Data memory data) internal pure returns (uint16) {
        return swapBytes2(uint16(bytes2(data.read(2))));
    }

    function decodeU32(Data memory data) internal pure returns (uint32) {
        return swapBytes4(uint32(bytes4(data.read(4))));
    }

    function decodeU64(Data memory data) internal pure returns (uint64) {
        return swapBytes8(uint64(bytes8(data.read(8))));
    }

    function decodeU128(Data memory data) internal pure returns (uint128) {
        return swapBytes16(uint128(bytes16(data.read(16))));
    }

    function decodeU256(Data memory data) internal pure returns (uint256) {
        return swapBytes32(uint256(data.read(32)));
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
        res = memoryToBytes(data.ptr, length);
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

 
    /********* Helper byte-swap functions *********/
    // TODO:GW: move to Utils.sol - can we just like that copy Aurora code ??????

    function readMemory(uint256 ptr) internal pure returns (uint256 res) {
        assembly {
            res := mload(ptr)
        }
    }

    function writeMemory(uint256 ptr, uint256 value) internal pure {
        assembly {
            mstore(ptr, value)
        }
    }

    function memoryToBytes(uint256 ptr, uint256 length) internal pure returns (bytes memory res) {
        if (length != 0) {
            assembly {
                // 0x40 is the address of free memory pointer.
                res := mload(0x40)
                let end :=
                    add(res, and(add(length, 63), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0))
                // end = res + 32 + 32 * ceil(length / 32).
                mstore(0x40, end)
                mstore(res, length)
                let destPtr := add(res, 32)
                // prettier-ignore
                for {} 1 {} {
                    mstore(destPtr, mload(ptr))
                    destPtr := add(destPtr, 32)
                    if eq(destPtr, end) { break }
                    ptr := add(ptr, 32)
                }
            }
        }
    }

    function swapBytes2(uint16 v) internal pure returns (uint16) {
        return (v << 8) | (v >> 8);
    }

    function swapBytes4(uint32 v) internal pure returns (uint32) {
        v = ((v & 0x00ff00ff) << 8) | ((v & 0xff00ff00) >> 8);
        return (v << 16) | (v >> 16);
    }

    function swapBytes8(uint64 v) internal pure returns (uint64) {
        v = ((v & 0x00ff00ff00ff00ff) << 8) | ((v & 0xff00ff00ff00ff00) >> 8);
        v = ((v & 0x0000ffff0000ffff) << 16) | ((v & 0xffff0000ffff0000) >> 16);
        return (v << 32) | (v >> 32);
    }

    function swapBytes16(uint128 v) internal pure returns (uint128) {
        v =
            ((v & 0x00ff00ff00ff00ff00ff00ff00ff00ff) << 8) |
            ((v & 0xff00ff00ff00ff00ff00ff00ff00ff00) >> 8);
        v =
            ((v & 0x0000ffff0000ffff0000ffff0000ffff) << 16) |
            ((v & 0xffff0000ffff0000ffff0000ffff0000) >> 16);
        v =
            ((v & 0x00000000ffffffff00000000ffffffff) << 32) |
            ((v & 0xffffffff00000000ffffffff00000000) >> 32);
        return (v << 64) | (v >> 64);
    }

    function swapBytes32(uint256 v) internal pure returns (uint256) {
        v =
            ((v & 0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff) << 8) |
            ((v & 0xff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00) >> 8);
        v =
            ((v & 0x0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff) << 16) |
            ((v & 0xffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000) >> 16);
        v =
            ((v & 0x00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff) << 32) |
            ((v & 0xffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000) >> 32);
        v =
            ((v & 0x0000000000000000ffffffffffffffff0000000000000000ffffffffffffffff) << 64) |
            ((v & 0xffffffffffffffff0000000000000000ffffffffffffffff0000000000000000) >> 64);
        return (v << 128) | (v >> 128);
    }

    function startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (prefixBytes.length > strBytes.length) return false;

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }

    function extractArrayLength(string memory typeName) internal pure returns (uint256) {
        bytes memory typeBytes = bytes(typeName);
        uint256 length = 0;
        bool foundSemicolon = false;
        bool foundDigit = false;
        
        // Parse patterns like "[u8; 32]"
        for (uint256 i = 0; i < typeBytes.length; i++) {
            bytes1 char = typeBytes[i];
            
            if (char == 0x3B) { // ';'
                foundSemicolon = true;
            } else if (foundSemicolon && char >= 0x30 && char <= 0x39) { // '0' to '9'
                foundDigit = true;
                length = length * 10 + uint256(uint8(char)) - 48; // Convert ASCII to number
            } else if (foundSemicolon && foundDigit && char == 0x5D) { // ']'
                break; // End of array type declaration
            } else if (foundSemicolon && foundDigit && char != 0x20) { // Not a space
                // If we found digits but hit a non-digit non-space, invalid format
                revert("Invalid array length format");
            }
            // Skip spaces and other characters before semicolon
        }
        
        require(foundSemicolon && foundDigit && length > 0, "Could not extract array length");
        return length;
    }
}