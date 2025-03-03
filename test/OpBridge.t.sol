pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import "../contracts/protocol/socket/switchboard/OpInteropSwitchboard.sol";

// import "./mocks/MockSocket.sol";

// contract OpInteropSwitchboardTest is Test {
//     OpInteropSwitchboard public switchboard;
//     MockSocket public mockSocket;
//     address public owner;
//     address public watcher;
//     bytes32 constant WATCHER_ROLE = keccak256("WATCHER_ROLE");

//     function setUp() public {
//         owner = address(this); // Test contract is the owner
//         mockSocket = new MockSocket();
//         switchboard = new OpInteropSwitchboard(1, address(mockSocket), owner);

//         // Setup roles
//         watcher = address(0x1);
//         switchboard.grantRole(WATCHER_ROLE, watcher);
//     }

//     function testAttest() public {
//         // Mock data
//         bytes32 payloadId = keccak256("payload1");
//         bytes32 digest = keccak256("digest1");
//         bytes memory proof = abi.encodePacked(watcher);

//         // Simulate calling the attest function
//         switchboard.attest(payloadId, digest, proof);

//         // Check if the digest is marked as attested
//         assertTrue(switchboard.isAttested(digest));

//         // Check if the payloadId to digest mapping is correct
//         assertEq(switchboard.payloadIdToDigest(payloadId), digest);

//         // Check for event emission, assuming an event Attested is emitted
//         // This part requires event handling setup in ds-test, which is not shown here
//     }
// }
