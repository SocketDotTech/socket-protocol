// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CounterAppGateway} from "./apps/app-gateways/counter/CounterAppGateway.sol";
import {Counter} from "./apps/app-gateways/counter/Counter.sol";
import "./SetupTest.t.sol";
import {SocketFeeManager} from "../contracts/protocol/socket/SocketFeeManager.sol";
import {MockFastSwitchboard} from "./mock/MockFastSwitchboard.sol";
import {ExecuteParams, TransmissionParams, CallType, WriteFinality} from "../contracts/protocol/utils/common/Structs.sol";
import {GOVERNANCE_ROLE, RESCUE_ROLE} from "../contracts/protocol/utils/common/AccessRoles.sol";
import {Test} from "forge-std/Test.sol";

contract SocketFeeManagerTest is SetupTest {
    Counter public counter;
    address public gateway = address(5);
    MockFastSwitchboard public mockSwitchboard;
    Socket public socket;
    SocketFeeManager public socketFeeManager;

    function setUp() public {
        socket = new Socket(arbChainSlug, owner, "test");
        vm.prank(owner);
        socket.grantRole(GOVERNANCE_ROLE, address(owner));
        socketFeeManager = new SocketFeeManager(owner, socketFees);
        mockSwitchboard = new MockFastSwitchboard(arbChainSlug, address(socket), owner);
        mockSwitchboard.registerSwitchboard();

        counter = new Counter();
        counter.initSocket(_encodeAppGatewayId(gateway), address(socket), address(mockSwitchboard));
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
            callType: CallType.WRITE,
            deadline: block.timestamp + 1 days,
            gasLimit: 100000,
            value: 0,
            payload: payload,
            target: address(counter),
            requestCount: 0,
            batchCount: 0,
            payloadCount: 0,
            prevDigestsHash: bytes32(0),
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
