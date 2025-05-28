// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {CounterAppGateway} from "./app-gateways/counter/CounterAppGateway.sol";
import {Counter} from "./app-gateways/counter/Counter.sol";
import "../SetupTest.t.sol";

contract CounterTest is AppGatewayBaseSetup {
    uint256 feesAmount = 0.01 ether;

    bytes32 counterId;
    bytes32[] contractIds = new bytes32[](1);
    CounterAppGateway counterGateway;

    event CounterScheduleResolved(uint256 creationTimestamp, uint256 executionTimestamp);

    function setUp() public {
        deploy();

        counterGateway = new CounterAppGateway(address(addressResolver), feesAmount);
        depositNativeAndCredits(arbChainSlug, 1 ether, 0, address(counterGateway));
        counterId = counterGateway.counter();
        contractIds[0] = counterId;
    }

    function deployCounterApp(uint32 chainSlug) internal returns (uint40 requestCount) {
        counterGateway.deployContracts(chainSlug);
        requestCount = executeDeploy(counterGateway, chainSlug, contractIds);
    }

    function testCounterDeployment() external {
        deployCounterApp(arbChainSlug);

        (address onChain, address forwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            counterGateway
        );

        assertEq(
            IForwarder(forwarder).getChainSlug(),
            arbChainSlug,
            "Forwarder chainSlug should be correct"
        );
        assertEq(
            IForwarder(forwarder).getOnChainAddress(),
            onChain,
            "Forwarder onChainAddress should be correct"
        );
    }

    function testCounterDeploymentWithoutAsync() external {
        vm.expectRevert(abi.encodeWithSelector(AsyncModifierNotSet.selector));
        counterGateway.deployContractsWithoutAsync(arbChainSlug);
    }

    function testCounterIncrement() external {
        deployCounterApp(arbChainSlug);

        (address arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            counterGateway
        );

        uint256 arbCounterBefore = Counter(arbCounter).counter();

        address[] memory instances = new address[](1);
        instances[0] = arbCounterForwarder;
        counterGateway.incrementCounters(instances);
        executeRequest();

        assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
    }

    function testCounterIncrementMultipleChains() public {
        deployCounterApp(arbChainSlug);
        deployCounterApp(optChainSlug);

        (address arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            counterGateway
        );
        (address optCounter, address optCounterForwarder) = getOnChainAndForwarderAddresses(
            optChainSlug,
            counterId,
            counterGateway
        );

        uint256 arbCounterBefore = Counter(arbCounter).counter();
        uint256 optCounterBefore = Counter(optCounter).counter();

        address[] memory instances = new address[](2);
        instances[0] = arbCounterForwarder;
        instances[1] = optCounterForwarder;
        counterGateway.incrementCounters(instances);

        uint32[] memory chains = new uint32[](2);
        chains[0] = arbChainSlug;
        chains[1] = optChainSlug;

        executeRequest();
        assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
        assertEq(Counter(optCounter).counter(), optCounterBefore + 1);
    }

    function testCounterReadMultipleChains() external {
        testCounterIncrementMultipleChains();

        (, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            counterGateway
        );
        (, address optCounterForwarder) = getOnChainAndForwarderAddresses(
            optChainSlug,
            counterId,
            counterGateway
        );

        address[] memory instances = new address[](2);
        instances[0] = arbCounterForwarder;
        instances[1] = optCounterForwarder;

        counterGateway.readCounters(instances);
        executeRequest();
    }

    function testCounterSchedule() external {
        deployCounterApp(arbChainSlug);

        uint256 creationTimestamp = block.timestamp;
        counterGateway.setSchedule(100);

        vm.expectEmit(true, true, true, false);
        emit CounterScheduleResolved(creationTimestamp, block.timestamp);
        executeRequest();

        assertLe(block.timestamp, creationTimestamp + 100 + expiryTime);
    }
}
