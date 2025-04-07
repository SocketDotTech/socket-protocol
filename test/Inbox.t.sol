// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CounterAppGateway} from "./apps/app-gateways/counter/CounterAppGateway.sol";
import {Counter} from "./apps/app-gateways/counter/Counter.sol";
import "./DeliveryHelper.t.sol";

contract TriggerTest is DeliveryHelperTest {
    uint256 constant feesAmount = 0.01 ether;
    CounterAppGateway public gateway;
    Counter public counter;

    event AppGatewayCallRequested(
        bytes32 triggerId,
        uint32 chainSlug,
        address plug,
        bytes params,
        bytes payload
    );

    function setUp() public {
        // Setup core test infrastructure
        setUpDeliveryHelper();

        // Deploy the counter contract
        counter = new Counter();

        // Deploy the gateway with fees
        gateway = new CounterAppGateway(address(addressResolver), createFees(feesAmount));
        gateway.setIsValidPlug(arbChainSlug, address(counter));

        // Connect the counter to the gateway and socket
        counter.initSocket(
            address(gateway),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );

        // Setup gateway config for the watcher
        AppGatewayConfig[] memory gateways = new AppGatewayConfig[](1);
        gateways[0] = AppGatewayConfig({
            plug: address(counter),
            chainSlug: arbChainSlug,
            appGateway: address(gateway),
            switchboard: address(arbConfig.switchboard)
        });

        bytes memory watcherSignature = _createWatcherSignature(
            address(watcherPrecompileConfig),
            abi.encode(IWatcherPrecompileConfig.setAppGateways.selector, gateways)
        );

        watcherPrecompileConfig.setAppGateways(gateways, signatureNonce++, watcherSignature);

        hoax(watcherEOA);
        watcherPrecompileConfig.setIsValidPlug(arbChainSlug, address(counter), true);
    }

    function testIncrementAfterTrigger() public {
        // Initial counter value should be 0
        assertEq(gateway.counterVal(), 0, "Initial gateway counter should be 0");

        // Simulate a message from another chain through the watcher
        uint256 incrementValue = 5;
        bytes32 triggerId = _encodeTriggerId(address(gateway), arbChainSlug);
        bytes memory payload = abi.encodeWithSelector(
            CounterAppGateway.increase.selector,
            incrementValue
        );

        vm.expectEmit(true, true, true, true);
        emit AppGatewayCallRequested(triggerId, arbChainSlug, address(counter), bytes(""), payload);
        counter.increaseOnGateway(incrementValue);

        TriggerParams[] memory params = new TriggerParams[](1);
        params[0] = TriggerParams({
            triggerId: triggerId,
            chainSlug: arbChainSlug,
            appGateway: address(gateway),
            plug: address(counter),
            payload: payload,
            params: bytes32(0)
        });

        bytes memory watcherSignature = _createWatcherSignature(
            address(watcherPrecompile),
            abi.encode(IWatcherPrecompile.callAppGateways.selector, params)
        );
        watcherPrecompile.callAppGateways(params, signatureNonce++, watcherSignature);
        // Check counter was incremented
        assertEq(gateway.counterVal(), incrementValue, "Gateway counter should be incremented");
    }

    function _encodeTriggerId(address appGateway_, uint256 chainSlug_) internal returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug_) << 224) |
                    (uint256(uint160(appGateway_)) << 64) |
                    triggerCounter++
            );
    }
}
