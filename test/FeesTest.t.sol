// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "./DeliveryHelper.t.sol";
import {CounterDeployer} from "../contracts/apps/counter/CounterDeployer.sol";
import {Counter} from "../contracts/apps/counter/Counter.sol";
import {CounterAppGateway} from "../contracts/apps/counter/CounterAppGateway.sol";

contract FeesTest is DeliveryHelperTest {
    uint256 constant depositAmount = 1 ether;
    uint256 constant feesAmount = 0.01 ether;

    uint32 feesChainSlug = arbChainSlug;
    SocketContracts feesConfig;

    bytes32 asyncId;
    CounterAppGateway counterGateway;
    CounterDeployer counterDeployer;

    function setUp() public {
        setUpDeliveryHelper();
        feesConfig = getSocketConfig(feesChainSlug);

        counterDeployer = new CounterDeployer(
            address(addressResolver),
            address(auctionManager),
            FAST,
            createFees(feesAmount)
        );

        counterGateway = new CounterAppGateway(
            address(addressResolver),
            address(counterDeployer),
            address(auctionManager),
            createFees(feesAmount)
        );
        setLimit(address(counterGateway));

        bytes32[] memory contractIds = new bytes32[](1);
        contractIds[0] = counterDeployer.counter();
        asyncId = _deploy(
            contractIds,
            feesChainSlug,
            1,
            IAppDeployer(counterDeployer),
            address(counterGateway)
        );
    }

    function testDistributeFee() public {
        bytes32 payloadId = getWritePayloadId(
            feesChainSlug,
            address(getSocketConfig(feesChainSlug).switchboard),
            writePayloadIdCounter - 1
        );

        deal(owner, depositAmount);

        hoax(owner);
        feesConfig.feesPlug.deposit{value: depositAmount}(
            ETH_ADDRESS,
            address(counterGateway),
            depositAmount
        );

        assertEq(
            depositAmount,
            address(feesConfig.feesPlug).balance,
            "FeesPlug Balance should be correct"
        );

        assertEq(
            depositAmount,
            feesConfig.feesPlug.balanceOf(ETH_ADDRESS),
            "FeesPlug balance of counterGateway should be correct"
        );

        uint256 transmitterBalanceBefore = address(transmitterEOA).balance;
        finalizeAndExecute(payloadId, true);

        assertEq(
            transmitterBalanceBefore + bidAmount,
            address(transmitterEOA).balance,
            "Transmitter Balance should be correct"
        );
        assertEq(
            depositAmount - bidAmount,
            address(feesConfig.feesPlug).balance,
            "FeesPlug Balance should be correct"
        );
    }

    function testWithdrawFeeTokens() public {
        feesConfig.feesPlug.deposit{value: depositAmount}(
            ETH_ADDRESS,
            address(counterGateway),
            depositAmount
        );
        assertEq(
            depositAmount,
            feesConfig.feesPlug.balanceOf(ETH_ADDRESS),
            "Balance should be correct"
        );

        address receiver = address(uint160(c++));

        uint256 receiverBalanceBefore = receiver.balance;
        counterGateway.withdrawFeeTokens(feesChainSlug, ETH_ADDRESS, depositAmount, receiver);

        asyncId = getCurrentAsyncId();
        bytes32[] memory payloadIds = getWritePayloadIds(
            feesChainSlug,
            address(getSocketConfig(feesChainSlug).switchboard),
            1
        );
        bidAndEndAuction(asyncId);
        finalizeAndExecute(payloadIds[0], true);
        assertEq(0, address(feesConfig.feesPlug).balance, "Fees Balance should be correct");

        assertEq(
            receiverBalanceBefore + depositAmount,
            receiver.balance,
            "Receiver Balance should be correct"
        );
    }
}
