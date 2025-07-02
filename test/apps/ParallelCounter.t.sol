// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {CounterAppGateway} from "./app-gateways/counter/CounterAppGateway.sol";
import {Counter} from "./app-gateways/counter/Counter.sol";
import "../SetupTest.t.sol";

contract ParallelCounterTest is AppGatewayBaseSetup {
    uint256 feesAmount = 0.01 ether;

    bytes32 counterId1;
    bytes32 counterId2;
    bytes32[] contractIds = new bytes32[](2);

    CounterAppGateway parallelCounterGateway;

    function setUp() public {
        deploy();

        parallelCounterGateway = new CounterAppGateway(address(addressResolver), feesAmount);
        depositNativeAndCredits(arbChainSlug, 1 ether, 0, address(parallelCounterGateway));

        counterId2 = parallelCounterGateway.counter();
        counterId1 = parallelCounterGateway.counter1();
        contractIds[0] = counterId1;
        contractIds[1] = counterId2;
    }

    function deployCounterApp(uint32[] memory chainSlugs) internal {
        parallelCounterGateway.deployMultiChainContracts(chainSlugs);
        executeDeployMultiChain(parallelCounterGateway, chainSlugs, contractIds);
    }

    function testParallelCounterDeployment() external {
        uint32[] memory chainSlugs = new uint32[](2);
        chainSlugs[0] = arbChainSlug;
        chainSlugs[1] = optChainSlug;
        deployCounterApp(chainSlugs);

        (bytes32 onChainArb1, address forwarderArb1) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId1,
            parallelCounterGateway
        );

        (bytes32 onChainArb2, address forwarderArb2) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId2,
            parallelCounterGateway
        );

        (bytes32 onChainOpt1, address forwarderOpt1) = getOnChainAndForwarderAddresses(
            optChainSlug,
            counterId1,
            parallelCounterGateway
        );

        (bytes32 onChainOpt2, address forwarderOpt2) = getOnChainAndForwarderAddresses(
            optChainSlug,
            counterId2,
            parallelCounterGateway
        );

        assertEq(
            IForwarder(forwarderArb1).getChainSlug(),
            arbChainSlug,
            "Forwarder chainSlug should be correct"
        );
        assertEq(
            IForwarder(forwarderArb1).getOnChainAddress(),
            onChainArb1,
            "Forwarder onChainAddress should be correct"
        );
        assertEq(
            IForwarder(forwarderOpt1).getChainSlug(),
            optChainSlug,
            "Forwarder chainSlug should be correct"
        );
        assertEq(
            IForwarder(forwarderOpt1).getOnChainAddress(),
            onChainOpt1,
            "Forwarder onChainAddress should be correct"
        );
        assertEq(
            IForwarder(forwarderArb2).getChainSlug(),
            arbChainSlug,
            "Forwarder chainSlug should be correct"
        );
        assertEq(
            IForwarder(forwarderArb2).getOnChainAddress(),
            onChainArb2,
            "Forwarder onChainAddress should be correct"
        );
        assertEq(
            IForwarder(forwarderOpt2).getOnChainAddress(),
            onChainOpt2,
            "Forwarder onChainAddress should be correct"
        );
        assertEq(
            IForwarder(forwarderOpt2).getOnChainAddress(),
            onChainOpt2,
            "Forwarder onChainAddress should be correct"
        );
    }

    function testCounterIncrement() external {
        uint32[] memory chainSlugs = new uint32[](1);
        chainSlugs[0] = arbChainSlug;
        deployCounterApp(chainSlugs);

        (bytes32 arbCounterBytes32, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId1,
            parallelCounterGateway
        );
        address arbCounter = fromBytes32Format(arbCounterBytes32);

        uint256 arbCounterBefore = Counter(arbCounter).counter();

        address[] memory instances = new address[](1);
        instances[0] = arbCounterForwarder;
        parallelCounterGateway.incrementCounters(instances);

        executeRequest();
        assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
    }

    function testCounterIncrementMultipleChains() external {
        uint32[] memory chainSlugs = new uint32[](2);
        chainSlugs[0] = arbChainSlug;
        chainSlugs[1] = optChainSlug;
        deployCounterApp(chainSlugs);

        (bytes32 arbCounterBytes32, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId1,
            parallelCounterGateway
        );
        address arbCounter = fromBytes32Format(arbCounterBytes32);

        (bytes32 optCounterBytes32, address optCounterForwarder) = getOnChainAndForwarderAddresses(
            optChainSlug,
            counterId1,
            parallelCounterGateway
        );
        address optCounter = fromBytes32Format(optCounterBytes32);

        uint256 arbCounterBefore = Counter(arbCounter).counter();
        uint256 optCounterBefore = Counter(optCounter).counter();

        address[] memory instances = new address[](2);
        instances[0] = arbCounterForwarder;
        instances[1] = optCounterForwarder;
        parallelCounterGateway.incrementCounters(instances);

        executeRequest();

        assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
        assertEq(Counter(optCounter).counter(), optCounterBefore + 1);
    }
}
