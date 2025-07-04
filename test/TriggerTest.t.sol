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
        bytes32 switchboard,
        bytes32 plug,
        bytes overrides,
        bytes payload
    );

    function setUp() public {
        // Setup core test infrastructure
        deploy();

        // Deploy the gateway with fees
        gateway = new CounterAppGateway(address(addressResolver), feesAmount);
        depositNativeAndCredits(arbChainSlug, 1 ether, 0, address(gateway));

        bytes32[] memory contractIds = new bytes32[](1);
        bytes32 counterId = gateway.counter();
        contractIds[0] = counterId;

        // Deploy the counter contract
        gateway.deployContracts(arbChainSlug);
        executeDeploy(gateway, arbChainSlug, contractIds);

        (bytes32 counterBytes32, ) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            gateway
        );
        address counterAddress = fromBytes32Format(counterBytes32);
        counter = Counter(counterAddress);
        gateway.setIsValidPlug(arbChainSlug, counterId);
    }

    function testIncrementAfterTrigger() public {
        // Initial counter value should be 0
        assertEq(gateway.counterVal(), 0, "Initial gateway counter should be 0");

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
            toBytes32Format(address(gateway)),
            toBytes32Format(address(arbConfig.switchboard)),
            toBytes32Format(address(counter)),
            bytes(""),
            payload
        );
        counter.increaseOnGateway(incrementValue);

        TriggerParams[] memory params = new TriggerParams[](1);
        params[0] = TriggerParams({
            triggerId: triggerId,
            chainSlug: arbChainSlug,
            appGatewayId: toBytes32Format(address(gateway)),
            plug: toBytes32Format(address(counter)),
            payload: payload,
            overrides: bytes("")
        });
        bytes memory data = abi.encode(params);

        WatcherMultiCallParams memory watcherParams;
        watcherParams = WatcherMultiCallParams({
            contractAddress: address(watcher),
            data: data,
            nonce: watcherNonce,
            signature: _createWatcherSignature(address(watcher), data)
        });
        watcherNonce++;
        watcher.callAppGateways(watcherParams);

        // Check counter was incremented
        assertEq(gateway.counterVal(), incrementValue, "Gateway counter should be incremented");
    }
}
