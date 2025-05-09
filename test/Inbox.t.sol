// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {CounterAppGateway} from "./apps/app-gateways/counter/CounterAppGateway.sol";
import {Counter} from "./apps/app-gateways/counter/Counter.sol";
import "./DeliveryHelper.t.sol";

contract TriggerTest is DeliveryHelperTest {
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
        setUpDeliveryHelper();

        // Deploy the counter contract
        counter = new Counter();

        // Deploy the gateway with fees
        gateway = new CounterAppGateway(address(addressResolver), feesAmount);
        gateway.setIsValidPlug(arbChainSlug, address(counter));

        // Connect the counter to the gateway and socket
        counter.initSocket(
            _encodeAppGatewayId(address(gateway)),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );

        // Setup gateway config for the watcher
        AppGatewayConfig[] memory gateways = new AppGatewayConfig[](1);
        gateways[0] = AppGatewayConfig({
            plug: address(counter),
            chainSlug: arbChainSlug,
            appGatewayId: _encodeAppGatewayId(address(gateway)),
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
        depositUSDCFees(
            address(gateway),
            OnChainFees({
                chainSlug: arbChainSlug,
                token: address(arbConfig.feesTokenUSDC),
                amount: 1 ether
            })
        );
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
            _encodeAppGatewayId(address(gateway)),
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
            appGatewayId: _encodeAppGatewayId(address(gateway)),
            plug: address(counter),
            payload: payload,
            overrides: bytes("")
        });

        bytes memory watcherSignature = _createWatcherSignature(
            address(watcherPrecompile),
            abi.encode(IWatcherPrecompile.callAppGateways.selector, params)
        );
        watcherPrecompile.callAppGateways(params, signatureNonce++, watcherSignature);
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
