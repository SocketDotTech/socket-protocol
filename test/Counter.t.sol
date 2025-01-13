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

        address arbCounter = deployer.getOnChainAddress(counterId, arbChainSlug);
        address arbCounterForwarder = deployer.forwarderAddresses(counterId, arbChainSlug);

        console.log("Counter on Arbitrum before:", Counter(arbCounter).counter());

        address[] memory instances = new address[](1);
        instances[0] = arbCounterForwarder;
        gateway.incrementCounters(instances);

        _executeBatchSingleChain(arbChainSlug, 1);
        console.log("Counter on Arbitrum after:", Counter(arbCounter).counter());
    }
}
