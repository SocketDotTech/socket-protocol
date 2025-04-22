// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./DeliveryHelper.t.sol";
import {Counter} from "./apps/app-gateways/counter/Counter.sol";
import {CounterAppGateway} from "./apps/app-gateways/counter/CounterAppGateway.sol";

contract FeesTest is DeliveryHelperTest {
    uint256 constant depositAmount = 1 ether;
    uint256 constant feesAmount = 0.01 ether;
    address receiver = address(uint160(c++));

    uint32 feesChainSlug = arbChainSlug;
    SocketContracts feesConfig;

    CounterAppGateway counterGateway;

    function setUp() public {
        setUpDeliveryHelper();
        feesConfig = getSocketConfig(feesChainSlug);

        counterGateway = new CounterAppGateway(address(addressResolver), feesAmount);
        depositUSDCFees(
            address(counterGateway),
            OnChainFees({
                chainSlug: feesChainSlug,
                token: address(feesConfig.feesTokenUSDC),
                amount: depositAmount
            })
        );

        bytes32[] memory contractIds = new bytes32[](1);
        contractIds[0] = counterGateway.counter();
        _deploy(feesChainSlug, IAppGateway(counterGateway), contractIds);
    }

    function testDistributeFee() public {
        uint256 initialFeesPlugBalance = feesConfig.feesTokenUSDC.balanceOf(
            address(feesConfig.feesPlug)
        );

        assertEq(
            initialFeesPlugBalance,
            feesConfig.feesTokenUSDC.balanceOf(address(feesConfig.feesPlug)),
            "FeesPlug Balance should be correct"
        );

        uint256 transmitterReceiverBalanceBefore = feesConfig.feesTokenUSDC.balanceOf(receiver);
        uint256 withdrawAmount = feesManager.getMaxFeesAvailableForWithdraw(transmitterEOA);
        vm.startPrank(transmitterEOA);
        uint40 requestCount = deliveryHelper.withdrawTransmitterFees(
            feesChainSlug,
            address(feesConfig.feesTokenUSDC),
            address(receiver),
            withdrawAmount
        );
        vm.stopPrank();
        uint40[] memory batches = watcherPrecompile.getBatches(requestCount);
        _finalizeBatch(batches[0], new bytes[](0), 0, false);
        assertEq(
            transmitterReceiverBalanceBefore + bidAmount,
            feesConfig.feesTokenUSDC.balanceOf(receiver),
            "Transmitter Balance should be correct"
        );
        assertEq(
            initialFeesPlugBalance - bidAmount,
            feesConfig.feesTokenUSDC.balanceOf(address(feesConfig.feesPlug)),
            "FeesPlug Balance should be correct"
        );
    }

    function testWithdrawFeeTokens() public {
        assertEq(
            depositAmount,
            feesConfig.feesTokenUSDC.balanceOf(address(feesConfig.feesPlug)),
            "Balance should be correct"
        );

        uint256 receiverBalanceBefore = feesConfig.feesTokenUSDC.balanceOf(receiver);
        uint256 withdrawAmount = 0.5 ether;

        counterGateway.withdrawFeeTokens(
            feesChainSlug,
            address(feesConfig.feesTokenUSDC),
            withdrawAmount,
            receiver
        );
        executeRequest(new bytes[](0));

        assertEq(
            depositAmount - withdrawAmount,
            feesConfig.feesTokenUSDC.balanceOf(address(feesConfig.feesPlug)),
            "Fees Balance should be correct"
        );

        assertEq(
            receiverBalanceBefore + withdrawAmount,
            feesConfig.feesTokenUSDC.balanceOf(receiver),
            "Receiver Balance should be correct"
        );
    }
}
