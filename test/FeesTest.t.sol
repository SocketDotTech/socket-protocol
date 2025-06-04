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

    event WithdrawFailed(bytes32 indexed payloadId);

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

    function testDisconnectFeesPlug() public {
        hoax(socketOwner);

        // disconnect old fees plug
        arbConfig.feesPlug.connectSocket(
            bytes32(0),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );

        hoax(watcherEOA);
        feesManager.setFeesPlug(arbChainSlug, address(0));

        AppGatewayConfig[] memory configs = new AppGatewayConfig[](1);
        configs[0] = AppGatewayConfig({
            chainSlug: arbChainSlug,
            plug: address(arbConfig.feesPlug),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(0)),
                switchboard: address(0)
            })
        });
        watcherMultiCall(
            address(configurations),
            abi.encodeWithSelector(Configurations.setAppGatewayConfigs.selector, configs)
        );

        approveAppGateway(address(feesManager), address(counterGateway));
        uint256 withdrawAmount = 0.5 ether;

        vm.expectRevert(abi.encodeWithSelector(InvalidChainSlug.selector));
        hoax(address(counterGateway));
        feesManager.withdrawCredits(
            arbChainSlug,
            address(arbConfig.testUSDC),
            withdrawAmount,
            feesAmount,
            address(receiver)
        );
    }

    function testMigrateFeesPlug() public {
        FeesPlug oldFeesPlug = arbConfig.feesPlug;

        // disconnect old fees plug
        hoax(socketOwner);
        oldFeesPlug.connectSocket(
            bytes32(0),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );

        // deploy new fees plug
        arbConfig.feesPlug = new FeesPlug(address(arbConfig.socket), address(socketOwner));

        // configure
        vm.startPrank(socketOwner);
        arbConfig.feesPlug.grantRole(RESCUE_ROLE, address(socketOwner));
        arbConfig.feesPlug.whitelistToken(address(arbConfig.testUSDC));
        arbConfig.feesPlug.connectSocket(
            encodeAppGatewayId(address(feesManager)),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );
        vm.stopPrank();

        hoax(watcherEOA);
        feesManager.setFeesPlug(arbChainSlug, address(arbConfig.feesPlug));

        AppGatewayConfig[] memory configs = new AppGatewayConfig[](1);
        configs[0] = AppGatewayConfig({
            chainSlug: arbChainSlug,
            plug: address(arbConfig.feesPlug),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(feesManager)),
                switchboard: address(arbConfig.switchboard)
            })
        });
        watcherMultiCall(
            address(configurations),
            abi.encodeWithSelector(Configurations.setAppGatewayConfigs.selector, configs)
        );

        uint256 withdrawAmount = 0.5 ether;
        approveAppGateway(address(feesManager), address(counterGateway));

        uint256 receiverBalanceBefore = arbConfig.testUSDC.balanceOf(receiver);

        hoax(address(counterGateway));
        feesManager.withdrawCredits(
            arbChainSlug,
            address(arbConfig.testUSDC),
            withdrawAmount,
            feesAmount,
            address(receiver)
        );
        executeRequest();

        assertEq(
            arbConfig.testUSDC.balanceOf(receiver),
            receiverBalanceBefore,
            "Receiver balance should be same"
        );

        arbConfig.testUSDC.mint(address(arbConfig.feesPlug), withdrawAmount);
        withdrawCredits(address(counterGateway), withdrawAmount);

        assertEq(
            arbConfig.testUSDC.balanceOf(receiver),
            receiverBalanceBefore + withdrawAmount,
            "Receiver balance should increase"
        );
    }
}
