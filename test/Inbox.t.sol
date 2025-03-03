// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CounterAppGateway} from "./apps/app-gateways/counter/CounterAppGateway.sol";
import {Counter} from "./apps/app-gateways/counter/Counter.sol";
import "./DeliveryHelper.t.sol";

contract InboxTest is DeliveryHelperTest {
    uint256 constant feesAmount = 0.01 ether;
    CounterAppGateway public gateway;
    Counter public inbox;

    function setUp() public {
        // Setup core test infrastructure
        setUpDeliveryHelper();

        // Deploy the inbox contract
        inbox = new Counter();

        // Deploy the gateway with fees
        gateway = new CounterAppGateway(
            address(addressResolver),
            createFees(feesAmount)
        );
        gateway.setIsValidPlug(arbChainSlug, address(inbox));

        // Connect the inbox to the gateway and socket
        inbox.initSocket(
            address(gateway),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );

        // Setup gateway config for the watcher
        AppGatewayConfig[] memory gateways = new AppGatewayConfig[](1);
        gateways[0] = AppGatewayConfig({
            plug: address(inbox),
            chainSlug: arbChainSlug,
            appGateway: address(gateway),
            switchboard: address(arbConfig.switchboard)
        });

        bytes memory watcherSignature = _createWatcherSignature(
            abi.encode(IWatcherPrecompile.setAppGateways.selector, gateways)
        );
        watcherPrecompile.setAppGateways(gateways, signatureNonce++, watcherSignature);

        hoax(watcherEOA);
        watcherPrecompile.setIsValidPlug(arbChainSlug, address(inbox), true);
    }

    function testInboxIncrement() public {
        // Initial counter value should be 0
        assertEq(gateway.counterVal(), 0, "Initial gateway counter should be 0");

        // Simulate a message from another chain through the watcher
        uint256 incrementValue = 5;

        bytes32 callId = inbox.increaseOnGateway(incrementValue);
        CallFromChainParams[] memory params = new CallFromChainParams[](1);
        params[0] = CallFromChainParams({
            callId: callId,
            chainSlug: arbChainSlug,
            appGateway: address(gateway),
            plug: address(inbox),
            payload: abi.encode(incrementValue),
            params: bytes32(0)
        });

        bytes memory watcherSignature = _createWatcherSignature(
            abi.encode(WatcherPrecompile.callAppGateways.selector, params)
        );
        watcherPrecompile.callAppGateways(params, signatureNonce++, watcherSignature);
        // Check counter was incremented
        assertEq(gateway.counterVal(), incrementValue, "Gateway counter should be incremented");
    }
}
