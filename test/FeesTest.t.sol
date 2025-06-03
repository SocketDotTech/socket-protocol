// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./apps/Counter.t.sol";
import "./SetupTest.t.sol";

contract FeesTest is AppGatewayBaseSetup {
    uint32 feesChainSlug = arbChainSlug;
    uint256 constant depositAmount = 1 ether;
    uint256 constant feesAmount = 0.01 ether;

    address receiver = address(uint160(c++));
    address user = address(uint160(c++));

    SocketContracts feesConfig;
    CounterAppGateway counterGateway;

    function setUp() public {
        deploy();

        feesConfig = getSocketConfig(feesChainSlug);
        counterGateway = new CounterAppGateway(address(addressResolver), feesAmount);
        depositNativeAndCredits(feesChainSlug, 100 ether, 0, address(counterGateway));

        bytes32[] memory contractIds = new bytes32[](1);
        contractIds[0] = counterGateway.counter();

        // deploy counter app gateway
        counterGateway.deployContracts(feesChainSlug);
        executeDeploy(IAppGateway(counterGateway), feesChainSlug, contractIds);
    }

    function withdrawCredits(address from, uint256 withdrawAmount) public {
        approveAppGateway(address(feesManager), from);
        hoax(from);
        feesManager.withdrawCredits(
            feesChainSlug,
            address(feesConfig.testUSDC),
            withdrawAmount,
            feesAmount,
            address(receiver)
        );
        executeRequest();
    }

    function testWithdrawTransmitterFees() public {
        uint256 transmitterReceiverBalanceBefore = feesConfig.testUSDC.balanceOf(receiver);
        uint256 withdrawAmount = feesManager.getAvailableCredits(transmitterEOA);
        withdrawAmount = withdrawAmount - feesAmount;
        withdrawCredits(transmitterEOA, withdrawAmount);

        assertEq(
            transmitterReceiverBalanceBefore + withdrawAmount,
            feesConfig.testUSDC.balanceOf(receiver),
            "Transmitter Balance should be correct"
        );
    }

    function testWithdrawFeeTokensAppGateway() public {
        uint256 receiverBalanceBefore = feesConfig.testUSDC.balanceOf(receiver);
        uint256 withdrawAmount = 0.5 ether;

        withdrawCredits(address(counterGateway), withdrawAmount);

        assertEq(
            receiverBalanceBefore + withdrawAmount,
            feesConfig.testUSDC.balanceOf(receiver),
            "Receiver Balance should be correct"
        );
    }

    function testWithdrawFeeTokensUser() public {
        depositNativeAndCredits(feesChainSlug, 1 ether, 0, user);

        uint256 receiverBalanceBefore = feesConfig.testUSDC.balanceOf(receiver);
        uint256 withdrawAmount = 0.5 ether;
        withdrawCredits(user, withdrawAmount);

        assertEq(
            receiverBalanceBefore + withdrawAmount,
            feesConfig.testUSDC.balanceOf(receiver),
            "Receiver Balance should be correct"
        );
    }
}
