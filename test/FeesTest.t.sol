// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "./DeliveryHelper.t.sol";
import {Counter} from "./apps/app-gateways/counter/Counter.sol";
import {CounterAppGateway} from "./apps/app-gateways/counter/CounterAppGateway.sol";

contract FeesTest is DeliveryHelperTest {
    uint256 constant depositAmount = 1 ether;
    uint256 constant feesAmount = 0.01 ether;
    address receiver = address(uint160(c++));

    uint32 feesChainSlug = arbChainSlug;
    SocketContracts feesConfig;

    bytes32 asyncId;
    CounterAppGateway counterGateway;

    function setUp() public {
        setUpDeliveryHelper();
        feesConfig = getSocketConfig(feesChainSlug);

        counterGateway = new CounterAppGateway(address(addressResolver), createFees(feesAmount));
        depositFees(address(counterGateway), createFees(depositAmount));

        bytes32[] memory contractIds = new bytes32[](1);
        contractIds[0] = counterGateway.counter();
        asyncId = _deploy(contractIds, feesChainSlug, 1, IAppGateway(counterGateway));
    }

    function testDistributeFee() public {
        uint256 initialFeesPlugBalance = address(feesConfig.feesPlug).balance;

        assertEq(
            initialFeesPlugBalance,
            address(feesConfig.feesPlug).balance,
            "FeesPlug Balance should be correct"
        );

        assertEq(
            initialFeesPlugBalance,
            feesConfig.feesPlug.balanceOf(ETH_ADDRESS),
            "FeesPlug balance of counterGateway should be correct"
        );

        uint256 transmitterReceiverBalanceBefore = address(receiver).balance;

        hoax(transmitterEOA);
        (bytes32 payloadId, , PayloadDetails memory payloadDetails) = feesManager
            .withdrawTransmitterFees(feesChainSlug, ETH_ADDRESS, address(receiver));
        payloadIdCounter++;
        finalizeAndRelay(payloadId, payloadDetails);

        assertEq(
            transmitterReceiverBalanceBefore + bidAmount,
            address(receiver).balance,
            "Transmitter Balance should be correct"
        );
        assertEq(
            initialFeesPlugBalance - bidAmount,
            address(feesConfig.feesPlug).balance,
            "FeesPlug Balance should be correct"
        );
    }

    function testWithdrawFeeTokens() public {
        assertEq(
            depositAmount,
            feesConfig.feesPlug.balanceOf(ETH_ADDRESS),
            "Balance should be correct"
        );

        uint256 receiverBalanceBefore = receiver.balance;
        uint256 withdrawAmount = 0.5 ether;

        counterGateway.withdrawFeeTokens(feesChainSlug, ETH_ADDRESS, withdrawAmount, receiver);

        asyncId = getNextAsyncId();
        bytes32[] memory payloadIds = getWritePayloadIds(
            feesChainSlug,
            address(getSocketConfig(feesChainSlug).switchboard),
            1
        );
        bidAndEndAuction(asyncId);

        PayloadDetails memory payloadDetails = deliveryHelper.getPayloadDetails(payloadIds[0]);
        finalizeAndRelay(payloadIds[0], payloadDetails);
        assertEq(
            depositAmount - withdrawAmount,
            address(feesConfig.feesPlug).balance,
            "Fees Balance should be correct"
        );

        assertEq(
            receiverBalanceBefore + withdrawAmount,
            receiver.balance,
            "Receiver Balance should be correct"
        );
    }
}
