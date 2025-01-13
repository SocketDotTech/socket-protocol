// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CounterAppGateway} from "../contracts/apps/counter/CounterAppGateway.sol";
import {CounterDeployer} from "../contracts/apps/counter/CounterDeployer.sol";
import {Counter} from "../contracts/apps/counter/Counter.sol";
import "./DeliveryHelper.t.sol";

contract CounterTest is DeliveryHelperTest {
    bytes32 counterId;
    bytes32[] contractIds = new bytes32[](2);

    CounterAppGateway gateway;
    CounterDeployer deployer;

    function deploySetup() internal {
        setUpDeliveryHelper();

        deployer = new CounterDeployer(
            address(addressResolver),
            address(auctionManager),
            FAST,
            createFeesData(0.01 ether)
        );

        gateway = new CounterAppGateway(
            address(addressResolver),
            address(deployer),
            address(auctionManager),
            createFeesData(0.01 ether)
        );
        setLimit(address(gateway));

        counterId = deployer.counter();
        contractIds[0] = counterId;
    }

    function deployCounterApp(uint32 chainSlug) internal {
        _deploy(contractIds, chainSlug, 1, IAppDeployer(deployer), address(gateway));
    }

    function testCounterDeployment() external {
        deploySetup();
        deployCounterApp(arbChainSlug);
    }

    function testCounterIncrement() external {
        deploySetup();
        deployCounterApp(arbChainSlug);

        (address arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            deployer
        );

        uint256 arbCounterBefore = Counter(arbCounter).counter();

        address[] memory instances = new address[](1);
        instances[0] = arbCounterForwarder;
        gateway.incrementCounters(instances);

        _executeBatchSingleChain(arbChainSlug, 1);
        assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
    }

    function testCounterIncrementMultipleChains() external {
        deploySetup();
        deployCounterApp(arbChainSlug);
        deployCounterApp(optChainSlug);

        (address arbCounter, address arbCounterForwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            counterId,
            deployer
        );
        (address optCounter, address optCounterForwarder) = getOnChainAndForwarderAddresses(
            optChainSlug,
            counterId,
            deployer
        );

        uint256 arbCounterBefore = Counter(arbCounter).counter();
        uint256 optCounterBefore = Counter(optCounter).counter();

        address[] memory instances = new address[](2);
        instances[0] = arbCounterForwarder;
        instances[1] = optCounterForwarder;
        gateway.incrementCounters(instances);

        uint32[] memory chains = new uint32[](2);
        chains[0] = arbChainSlug;
        chains[1] = optChainSlug;
        // _executeBatchMultipleChains(chains, 2);
        // assertEq(Counter(arbCounter).counter(), arbCounterBefore + 1);
        // assertEq(Counter(optCounter).counter(), optCounterBefore + 1);
    }
}
