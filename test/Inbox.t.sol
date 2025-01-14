// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CounterInboxAppGateway} from "../contracts/apps/counter-inbox/CounterInboxAppGateway.sol";
import {CounterInbox} from "../contracts/apps/counter-inbox/CounterInbox.sol";
import "./DeliveryHelper.t.sol";

contract InboxTest is DeliveryHelperTest {
    uint256 constant feesAmount = 0.01 ether;
    CounterInboxAppGateway public gateway;
    CounterInbox public inbox;

    function setUp() public {
        // Setup core test infrastructure
        setUpDeliveryHelper();

        // Deploy the inbox contract
        inbox = new CounterInbox();

        // Deploy the gateway with fees
        gateway = new CounterInboxAppGateway(
            address(addressResolver),
            address(auctionManager),
            address(inbox),
            arbChainSlug,
            createFeesData(feesAmount)
        );
        setLimit(address(gateway));

        // Connect the inbox to the gateway and socket
        inbox.connectSocket(
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

        hoax(watcherEOA);
        watcherPrecompile.setAppGateways(gateways);

        hoax(watcherEOA);
        watcherPrecompile.setIsValidInboxCaller(arbChainSlug, address(inbox), true);
    }

    function testInboxIncrement() public {
        // Initial counter value should be 0
        assertEq(gateway.counter(), 0, "Initial gateway counter should be 0");

        // Simulate a message from another chain through the watcher
        uint256 incrementValue = 5;

        bytes32 callId = inbox.increaseOnGateway(incrementValue);

        hoax(watcherEOA);
        CallFromInboxParams[] memory params = new CallFromInboxParams[](1);
        params[0] = CallFromInboxParams({
            callId: callId,
            chainSlug: arbChainSlug,
            appGateway: address(gateway),
            plug: address(inbox),
            payload: abi.encode(incrementValue),
            params: bytes32(0)
        });
        watcherPrecompile.callAppGateways(params);
        // Check counter was incremented
        assertEq(gateway.counter(), incrementValue, "Gateway counter should be incremented");
    }
}
