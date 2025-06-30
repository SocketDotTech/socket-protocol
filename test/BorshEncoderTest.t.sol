// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {BorshEncoder} from "../contracts/evmx/watcher/BorshEncoder.sol";

contract BorshEncoderTest is Test {
    /** Encode primitive types **/

    function testEncodeU8() public pure {
        uint8 value = 1;
        bytes1 encoded = BorshEncoder.encodeU8(value);
        console.logBytes1(encoded);
        console.logBytes1(bytes1(value));
        assertEq(encoded, bytes1(value));
    }

    function testEncodeU16() public pure {
        uint16 value = 0x0102;
        bytes2 encoded = BorshEncoder.encodeU16(value);
        assertEq(encoded, bytes2(0x0201));
    }

    function testEncodeU32() public pure {
        uint32 value = 0x01020304;
        bytes4 encoded = BorshEncoder.encodeU32(value);
        // console.logBytes4(encoded);
        // console.logBytes4(bytes4(value));
        assertEq(encoded, bytes4(0x04030201));
    }

    function testEncodeU64() public pure {
        uint64 value = 0x0102030405060708;
        bytes8 encoded = BorshEncoder.encodeU64(value);
        assertEq(encoded, bytes8(0x0807060504030201));
    }

    function testEncodeU128() public pure {
        uint128 value = 0x0102030405060708090a0b0c0d0e0f10;
        bytes16 encoded = BorshEncoder.encodeU128(value);
        assertEq(encoded, bytes16(0x100f0e0d0c0b0a090807060504030201));
    }

    function testEncodeString() public pure {
        string memory value = "hello";
        bytes memory encoded = BorshEncoder.encodeString(value);
        console.logBytes(encoded);
        console.logBytes(bytes("hello"));
        console.logBytes(hex"0500000068656c6c6f");
        // first 4 bytes are the length of the string which is 5 in LE : 0x05000000
        // rest is the string as bytes with no changes
        assertEq(encoded, hex"0500000068656c6c6f");
    }

    /** Encode array types with fixed length - no length prefix, just the bytes **/

    function testEncodeUint8Array() public pure {
        bytes memory expectedEncoded = hex"010203";

        uint8[] memory value = new uint8[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint8Array(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeUint16Array() public pure {
        bytes memory expectedEncoded = hex"010002000300";

        uint16[] memory value = new uint16[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint16Array(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeUint32Array() public pure {
        bytes memory expectedEncoded = hex"010000000200000003000000";

        uint32[] memory value = new uint32[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint32Array(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeUint64Array() public pure {
        bytes memory expectedEncoded = hex"010000000000000002000000000000000300000000000000";

        uint64[] memory value = new uint64[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint64Array(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeUint128Array() public pure {
        bytes
            memory expectedEncoded = hex"010000000000000000000000000000000200000000000000000000000000000003000000000000000000000000000000";

        uint128[] memory value = new uint128[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint128Array(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeStringArray() public pure {
        // "hello" (5 bytes): 0x0500000068656c6c6f
        // "world" (5 bytes): 0x05000000776f726c64
        bytes memory expectedEncoded = hex"0500000068656c6c6f05000000776f726c64";

        string[] memory value = new string[](2);
        value[0] = "hello";
        value[1] = "world";
        bytes memory encoded = BorshEncoder.encodeStringArray(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeStringArrayEmpty() public pure {
        // Empty string (0 bytes): 0x00000000
        bytes memory expectedEncoded = hex"0000000000000000";

        string[] memory value = new string[](2);
        value[0] = "";
        value[1] = "";
        bytes memory encoded = BorshEncoder.encodeStringArray(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeStringArraySingleChar() public pure {
        bytes memory expectedEncoded = hex"0500000068656c6c6f05000000776f726c64";

        string[] memory value = new string[](2);
        value[0] = "hello";
        value[1] = "world";
        bytes memory encoded = BorshEncoder.encodeStringArray(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    /** Encode Vector types with that can have variable length - length prefix is added **/

    function testEncodeUint8Vec() public pure {
        // Length: 3 as u32 (0x03000000) + elements (0x010203)
        bytes memory expectedEncoded = hex"03000000010203";

        uint8[] memory value = new uint8[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint8Vec(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeUint16Vec() public pure {
        // Length: 3 as u32 (0x03000000) + elements (0x010002000300)
        bytes memory expectedEncoded = hex"03000000010002000300";

        uint16[] memory value = new uint16[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint16Vec(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeUint32Vec() public pure {
        // Length: 3 as u32 (0x03000000) + elements (0x010000000200000003000000)
        bytes memory expectedEncoded = hex"03000000010000000200000003000000";

        uint32[] memory value = new uint32[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint32Vec(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeUint64Vec() public pure {
        // Length: 3 as u32 (0x03000000) + elements (0x010000000000000002000000000000000300000000000000)
        bytes
            memory expectedEncoded = hex"03000000010000000000000002000000000000000300000000000000";

        uint64[] memory value = new uint64[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint64Vec(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeUint128Vec() public pure {
        // Length: 3 as u32 (0x03000000) + elements
        bytes
            memory expectedEncoded = hex"03000000010000000000000000000000000000000200000000000000000000000000000003000000000000000000000000000000";

        uint128[] memory value = new uint128[](3);
        value[0] = 1;
        value[1] = 2;
        value[2] = 3;
        bytes memory encoded = BorshEncoder.encodeUint128Vec(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }

    function testEncodeStringVec() public pure {
        // Length: 2 as u32 (0x02000000) + string elements
        bytes memory expectedEncoded = hex"020000000500000068656c6c6f05000000776f726c64";

        string[] memory value = new string[](2);
        value[0] = "hello";
        value[1] = "world";
        bytes memory encoded = BorshEncoder.encodeStringVec(value);

        console.logBytes(encoded);
        assertEq(encoded, expectedEncoded);
    }
}
