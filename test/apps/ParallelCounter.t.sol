// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {CounterAppGateway} from "./app-gateways/counter/CounterAppGateway.sol";
import "../DeliveryHelper.t.sol";

contract ParallelCounterTest is DeliveryHelperTest {
    uint256 feesAmount = 0.01 ether;

    bytes32 counterId1;
    bytes32 counterId2;
    bytes32[] contractIds = new bytes32[](2);

    CounterAppGateway parallelCounterGateway;

    function deploySetup() internal {
        setUpDeliveryHelper();

        parallelCounterGateway = new CounterAppGateway(
            address(addressResolver),
            createFees(feesAmount)
        );
        depositFees(address(parallelCounterGateway), createFees(1 ether));
        counterId1 = parallelCounterGateway.counter1();
        counterId2 = parallelCounterGateway.counter();
        contractIds[0] = counterId1;
        contractIds[1] = counterId2;
    }

    function deployCounterApps(uint32[] memory chainSlugs) internal {
        parallelCounterGateway.deployMultiChainContracts(chainSlugs);
        executeRequest(new bytes[](0));
    }

    function testParallelCounterDeployment() external {
        deploySetup();
        uint32[] memory chainSlugs = new uint32[](2);
        chainSlugs[0] = arbChainSlug;
        chainSlugs[1] = optChainSlug;
        deployCounterApps(chainSlugs);

        (address onChainArb1, address forwarderArb1) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId1,
            parallelCounterGateway
        );
        (address onChainArb2, address forwarderArb2) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId2,
            parallelCounterGateway
        );

        (address onChainOpt1, address forwarderOpt1) = getOnChainAndForwarderAddresses(
            optChainSlug,
            counterId1,
            parallelCounterGateway
        );
        (address onChainOpt2, address forwarderOpt2) = getOnChainAndForwarderAddresses(
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

    function testAsyncModifierNotSet() external {
        deploySetup();
        uint32[] memory chainSlugs = new uint32[](1);
        chainSlugs[0] = arbChainSlug;
        deployCounterApps(chainSlugs);

        (, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId1,
            parallelCounterGateway
        );

        address[] memory instances = new address[](1);
        instances[0] = arbCounterForwarder;

        // Should revert with AsyncModifierNotUsed error
        vm.expectRevert(abi.encodeWithSignature("AsyncModifierNotUsed()"));
        parallelCounterGateway.incrementCountersWithoutAsync(instances);
    }

    // function testCounterIncrement() external {
    //     deploySetup();
    //     deployCounterApp(arbChainSlug);

    //     (address arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
    //         arbChainSlug,
    //         counterId,
    //         counterDeployer
    //     );

    //     uint256 arbCounterBefore = Counter(arbCounter).counter();

    //     address[] memory instances = new address[](1);
    //     instances[0] = arbCounterForwarder;
    //     counterGateway.incrementCounters(instances);

    //     _executeRequestSingleChain(arbChainSlug, 1);
    //     assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
    // }

    // function testCounterIncrementMultipleChains() external {
    //     deploySetup();
    //     deployCounterApp(arbChainSlug);
    //     deployCounterApp(optChainSlug);

    //     (address arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
    //         arbChainSlug,
    //         counterId,
    //         counterDeployer
    //     );
    //     (address optCounter, address optCounterForwarder) = getOnChainAndForwarderAddresses(
    //         optChainSlug,
    //         counterId,
    //         counterDeployer
    //     );

    //     uint256 arbCounterBefore = Counter(arbCounter).counter();
    //     uint256 optCounterBefore = Counter(optCounter).counter();

    //     address[] memory instances = new address[](2);
    //     instances[0] = arbCounterForwarder;
    //     instances[1] = optCounterForwarder;
    //     counterGateway.incrementCounters(instances);

    //     uint32[] memory chains = new uint32[](2);
    //     chains[0] = arbChainSlug;
    //     chains[1] = optChainSlug;
    //     _executeRequestMultiChain(chains);
    //     assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
    //     assertEq(Counter(optCounter).counter(), optCounterBefore + 1);
    // }
}
