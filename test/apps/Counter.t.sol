// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {CounterAppGateway} from "./app-gateways/counter/CounterAppGateway.sol";
import {Counter} from "./app-gateways/counter/Counter.sol";
import "../DeliveryHelper.t.sol";

contract CounterTest is DeliveryHelperTest {
    uint256 feesAmount = 0.01 ether;

    bytes32 counterId;
    bytes32[] contractIds = new bytes32[](1);

    CounterAppGateway counterGateway;

    function deploySetup() internal {
        setUpDeliveryHelper();

        counterGateway = new CounterAppGateway(address(addressResolver), createFees(feesAmount));
        depositFees(address(counterGateway), createFees(1 ether));

        counterId = counterGateway.counter();
        contractIds[0] = counterId;
    }

    function deployCounterApp(uint32 chainSlug) internal returns (uint40 requestCount) {
        requestCount = _deploy(chainSlug, IAppGateway(counterGateway), contractIds);
    }

    function testCounterDeployment() external {
        deploySetup();
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
        deploySetup();

        vm.expectRevert(abi.encodeWithSelector(AsyncModifierNotUsed.selector));
        counterGateway.deployContractsWithoutAsync(arbChainSlug);
    }

    function testCounterIncrement() external {
        deploySetup();
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
        executeRequest(new bytes[](0));

        assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
    }

    function testCounterIncrementMultipleChains() public {
        deploySetup();
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

        executeRequest(new bytes[](0));
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

        bytes[] memory readReturnData = new bytes[](2);
        readReturnData[0] = abi.encode(10);
        readReturnData[1] = abi.encode(10);

        executeRequest(readReturnData);
    }
}
