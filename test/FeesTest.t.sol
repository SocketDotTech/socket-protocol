// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./apps/Counter.t.sol";
import "./SetupTest.t.sol";

contract FeesTest is AppGatewayBaseSetup {
    uint256 constant depositAmount = 1 ether;
    uint256 constant feesAmount = 0.01 ether;
    address receiver = address(uint160(c++));
    address user = address(uint160(c++));
    uint32 feesChainSlug = arbChainSlug;
    SocketContracts feesConfig;

    CounterAppGateway counterGateway;

    function setUp() public {
        deploy();
        feesConfig = getSocketConfig(feesChainSlug);

        counterGateway = new CounterAppGateway(address(addressResolver), feesAmount);
        depositNativeAndCredits(feesChainSlug, 1 ether, 0, address(counterGateway));

        bytes32[] memory contractIds = new bytes32[](1);
        contractIds[0] = counterGateway.counter();
        executeDeploy(IAppGateway(counterGateway), feesChainSlug, contractIds);
    }

    function testWithdrawTransmitterFees() public {
        uint256 initialFeesPlugBalance = address(feesConfig.feesPlug).balance;

        assertEq(
            initialFeesPlugBalance,
            address(feesConfig.feesPlug).balance,
            "FeesPlug Balance should be correct"
        );

        uint256 transmitterReceiverBalanceBefore = address(receiver).balance;
        uint256 withdrawAmount = feesManager.getAvailableCredits(transmitterEOA);
        vm.startPrank(transmitterEOA);
        feesManager.withdrawCredits(
            feesChainSlug,
            address(feesConfig.testUSDC),
            withdrawAmount,
            feesAmount,
            address(receiver)
        );
        vm.stopPrank();
        executeRequest();

        assertEq(
            transmitterReceiverBalanceBefore + withdrawAmount,
            feesConfig.testUSDC.balanceOf(receiver),
            "Transmitter Balance should be correct"
        );
        assertEq(
            initialFeesPlugBalance - withdrawAmount,
            feesConfig.testUSDC.balanceOf(address(feesConfig.feesPlug)),
            "FeesPlug Balance should be correct"
        );
    }

    function testWithdrawFeeTokensAppGateway() public {
        uint256 receiverBalanceBefore = feesConfig.testUSDC.balanceOf(receiver);
        uint256 withdrawAmount = 0.5 ether;

        counterGateway.withdrawCredits(
            feesChainSlug,
            address(feesConfig.testUSDC),
            withdrawAmount,
            feesAmount,
            receiver
        );
        executeRequest();

        assertEq(
            receiverBalanceBefore + withdrawAmount,
            feesConfig.testUSDC.balanceOf(receiver),
            "Receiver Balance should be correct"
        );
    }

    function testWithdrawFeeTokensUser() public {
        depositNativeAndCredits(feesChainSlug, 1 ether, 0, user);

        uint256 receiverBalanceBefore = feesConfig.testUSDC.balanceOf(user);
        uint256 withdrawAmount = 0.5 ether;

        vm.prank(user);
        feesManager.withdrawCredits(
            feesChainSlug,
            address(feesConfig.testUSDC),
            withdrawAmount,
            feesAmount,
            address(receiver)
        );
        executeRequest();

        assertEq(
            receiverBalanceBefore + withdrawAmount,
            feesConfig.testUSDC.balanceOf(user),
            "Receiver Balance should be correct"
        );
    }
}
