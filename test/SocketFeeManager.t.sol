// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SocketFeeManager} from "../contracts/protocol/SocketFeeManager.sol";
import {MockFastSwitchboard} from "./mock/MockFastSwitchboard.sol";
import "./SetupTest.t.sol";
import "./apps/Counter.t.sol";

contract SocketFeeManagerTest is AppGatewayBaseSetup {
    Counter public counter;

    address public owner = address(uint160(c++));
    address public gateway = address(uint160(c++));

    MockFastSwitchboard public mockSwitchboard;
    Socket public socket;
    SocketFeeManager public socketFeeManager;

    function setUp() public {
        socketFees = 0.001 ether;

        socket = new Socket(arbChainSlug, owner, "test");
        socketFeeManager = new SocketFeeManager(owner, socketFees);
        mockSwitchboard = new MockFastSwitchboard(arbChainSlug, address(socket), owner);
        counter = new Counter();

        mockSwitchboard.registerSwitchboard();
        counter.initSocket(encodeAppGatewayId(gateway), address(socket), address(mockSwitchboard));

        vm.prank(owner);
        socket.grantRole(GOVERNANCE_ROLE, address(owner));
    }

    function testSuccessfulExecutionWithFeeManagerNotSet() public {
        // Create execute params
        (
            ExecuteParams memory executeParams,
            TransmissionParams memory transmissionParams
        ) = _getExecutionParams(abi.encodeWithSelector(Counter.increase.selector));

        // Fund the contract with enough ETH for fees
        vm.deal(address(this), socketFees);

        // Execute with fees
        socket.execute{value: socketFees}(executeParams, transmissionParams);

        // Check counter was incremented
        assertEq(counter.counter(), 1, "Counter should be incremented");
        assertEq(
            address(socketFeeManager).balance,
            0,
            "Socket fee manager should have 0 balance when fees manager not set"
        );
    }

    function testSuccessfulExecutionWithFeeManagerSet() public {
        // Set the fee manager in socket
        vm.prank(owner);
        socket.setSocketFeeManager(address(socketFeeManager));

        // Create execute params
        (
            ExecuteParams memory executeParams,
            TransmissionParams memory transmissionParams
        ) = _getExecutionParams(abi.encodeWithSelector(Counter.increase.selector));

        // Fund the contract with enough ETH for fees
        vm.deal(address(this), socketFees);

        // Execute with fees
        socket.execute{value: socketFees}(executeParams, transmissionParams);

        // Check counter was incremented
        assertEq(counter.counter(), 1, "Counter should be incremented");
        assertEq(
            address(socketFeeManager).balance,
            socketFees,
            "Socket fee manager should have received the fees"
        );
    }

    function testSuccessfulExecutionWithInsufficientFees() public {
        // Set the fee manager in socket
        vm.prank(owner);
        socket.setSocketFeeManager(address(socketFeeManager));

        // Create execute params
        (
            ExecuteParams memory executeParams,
            TransmissionParams memory transmissionParams
        ) = _getExecutionParams(abi.encodeWithSelector(Counter.increase.selector));

        // Fund with insufficient ETH
        vm.deal(address(this), socketFees - 1);

        // Should revert with InsufficientMsgValue
        vm.expectRevert(Socket.InsufficientMsgValue.selector);
        socket.execute{value: socketFees - 1}(executeParams, transmissionParams);
    }

    function testExecutionFailed() public {
        // Set the fee manager in socket
        vm.prank(owner);
        socket.setSocketFeeManager(address(socketFeeManager));

        // Create execute params with invalid payload to force failure
        (
            ExecuteParams memory executeParams,
            TransmissionParams memory transmissionParams
        ) = _getExecutionParams(abi.encodeWithSelector(bytes4(keccak256("invalid()"))));

        // Fund the contract with enough ETH for fees
        vm.deal(address(this), socketFees);

        // Execute with fees
        socket.execute{value: socketFees}(executeParams, transmissionParams);

        // Check counter was not incremented
        assertEq(counter.counter(), 0, "Counter should not be incremented");
        assertEq(
            address(socketFeeManager).balance,
            0,
            "Socket fee manager should not receive fees on failed execution"
        );
    }

    function _getExecutionParams(
        bytes memory payload
    ) internal view returns (ExecuteParams memory, TransmissionParams memory) {
        ExecuteParams memory executeParams = ExecuteParams({
            callType: WRITE,
            deadline: block.timestamp + 1 days,
            gasLimit: 100000,
            value: 0,
            payload: payload,
            target: address(counter),
            requestCount: 0,
            batchCount: 0,
            payloadCount: 0,
            prevBatchDigestHash: bytes32(0),
            extraData: bytes("")
        });

        TransmissionParams memory transmissionParams = TransmissionParams({
            transmitterSignature: bytes(""),
            socketFees: socketFees,
            extraData: bytes(""),
            refundAddress: transmitterEOA
        });

        return (executeParams, transmissionParams);
    }
}
