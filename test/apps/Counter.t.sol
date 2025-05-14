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

        counterGateway = new CounterAppGateway(address(addressResolver), feesAmount);
        depositUSDCFees(
            address(counterGateway),
            OnChainFees({
                chainSlug: arbChainSlug,
                token: address(arbConfig.feesTokenUSDC),
                amount: 1 ether
            })
        );

        counterId = counterGateway.counter();
        contractIds[0] = counterId;
    }

    function deployCounterApp(uint32 chainSlug) internal returns (uint40 requestCount) {
        requestCount = _deploy(chainSlug, counterGateway, contractIds);
    }

    function testCounterDeployment() external {
        deploySetup();
        deployCounterApp(arbChainSlug);

        (bytes32 onChain, address forwarder) = getOnChainAndForwarderAddresses(
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

        (bytes32 arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            counterGateway
        );
        address arbCounterAddress = fromBytes32Format(arbCounter);

        uint256 arbCounterBefore = Counter(arbCounterAddress).counter();

        address[] memory instances = new address[](1);
        instances[0] = arbCounterForwarder;
        counterGateway.incrementCounters(instances);
        executeRequest(new bytes[](0));

        assertEq(Counter(arbCounterAddress).counter(), arbCounterBefore + 1);
    }

    function testCounterIncrementMultipleChains() public {
        deploySetup();
        deployCounterApp(arbChainSlug);
        deployCounterApp(optChainSlug);

        (bytes32 arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            counterGateway
        );
        address arbCounterAddress = fromBytes32Format(arbCounter);
        (bytes32 optCounter, address optCounterForwarder) = getOnChainAndForwarderAddresses(
            optChainSlug,
            counterId,
            counterGateway
        );
        address optCounterAddress = fromBytes32Format(optCounter);

        uint256 arbCounterBefore = Counter(arbCounterAddress).counter();
        uint256 optCounterBefore = Counter(optCounterAddress).counter();

        address[] memory instances = new address[](2);
        instances[0] = arbCounterForwarder;
        instances[1] = optCounterForwarder;
        counterGateway.incrementCounters(instances);

        uint32[] memory chains = new uint32[](2);
        chains[0] = arbChainSlug;
        chains[1] = optChainSlug;

        executeRequest(new bytes[](0));
        assertEq(Counter(arbCounterAddress).counter(), arbCounterBefore + 1);
        assertEq(Counter(optCounterAddress).counter(), optCounterBefore + 1);
    }

    function testCounterReadMultipleChains() external {
        testCounterIncrementMultipleChains();

        (bytes32 arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
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
