// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {CounterAppGateway} from "./apps/Counter.t.sol";
import {Counter} from "./apps/Counter.t.sol";
import "./SetupTest.t.sol";

contract TriggerTest is AppGatewayBaseSetup {
    uint256 constant feesAmount = 0.01 ether;
    CounterAppGateway public gateway;
    Counter public counter;

    event AppGatewayCallRequested(
        bytes32 triggerId,
        bytes32 appGatewayId,
        address switchboard,
        address plug,
        bytes overrides,
        bytes payload
    );

    function setUp() public {
        // Setup core test infrastructure
        deploy();

        // Deploy the counter contract
        counter = new Counter();

        // Deploy the gateway with fees
        gateway = new CounterAppGateway(address(addressResolver), feesAmount);
        gateway.setIsValidPlug(arbChainSlug, address(counter));

        // Connect the counter to the gateway and socket
        counter.initSocket(
            encodeAppGatewayId(address(gateway)),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );

        // Setup gateway config for the watcher
        AppGatewayConfig[] memory configs = new AppGatewayConfig[](1);
        configs[0] = AppGatewayConfig({
            chainSlug: arbChainSlug,
            plug: address(counter),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(gateway)),
                switchboard: address(arbConfig.switchboard)
            })
        });

        watcherMultiCall(
            address(configurations),
            abi.encodeWithSelector(Configurations.setPlugConfigs.selector, configs)
        );

        hoax(watcherEOA);
        configurations.setIsValidPlug(true, arbChainSlug, address(counter));
    }

    function testIncrementAfterTrigger() public {
        // Initial counter value should be 0
        assertEq(gateway.counterVal(), 0, "Initial gateway counter should be 0");
        depositNativeAndCredits(arbChainSlug, 1 ether, 0, address(gateway));

        bytes32[] memory contractIds = new bytes32[](1);
        contractIds[0] = gateway.counter();
        executeDeploy(arbChainSlug, IAppGateway(gateway), contractIds);

        // Simulate a message from another chain through the watcher
        uint256 incrementValue = 5;
        bytes32 triggerId = _encodeTriggerId(address(arbConfig.socket), arbChainSlug);
        bytes memory payload = abi.encodeWithSelector(
            CounterAppGateway.increase.selector,
            incrementValue
        );

        vm.expectEmit(true, true, true, true);
        emit AppGatewayCallRequested(
            triggerId,
            encodeAppGatewayId(address(gateway)),
            address(arbConfig.switchboard),
            address(counter),
            bytes(""),
            payload
        );
        counter.increaseOnGateway(incrementValue);

        TriggerParams[] memory params = new TriggerParams[](1);
        params[0] = TriggerParams({
            triggerId: triggerId,
            chainSlug: arbChainSlug,
            appGatewayId: encodeAppGatewayId(address(gateway)),
            plug: address(counter),
            payload: payload,
            overrides: bytes("")
        });

        watcherMultiCall(
            address(watcher),
            abi.encodeWithSelector(Watcher.callAppGateways.selector, params)
        );

        // Check counter was incremented
        assertEq(gateway.counterVal(), incrementValue, "Gateway counter should be incremented");
    }

    function _encodeTriggerId(address socket_, uint256 chainSlug_) internal returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug_) << 224) | (uint256(uint160(socket_)) << 64) | triggerCounter++
            );
    }
}
