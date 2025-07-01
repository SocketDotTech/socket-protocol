// SPDX-License-Identifier: GPL-3.0-only
// Based on Aurora bridge repo: https://github.com/aurora-is-near/aurora-contracts-sdk/blob/main/aurora-solidity-sdk
pragma solidity ^0.8.21;


library BorshUtils {

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