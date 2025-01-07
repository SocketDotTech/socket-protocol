// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CounterComposer} from "../contracts/apps/counter/app-gateway/CounterComposer.sol";
import {CounterDeployer} from "../contracts/apps/counter/app-gateway/CounterDeployer.sol";
import {Counter} from "../contracts/apps/counter/Counter.sol";
import "./DeliveryHelper.t.sol";

contract CounterTest is DeliveryHelperTest {
    function testCounter() external {
        console.log("Deploying contracts on Arbitrum...");
        setUpDeliveryHelper();
        CounterDeployer deployer = new CounterDeployer(
            address(addressResolver),
            address(auctionManager),
            createFeesData(0.01 ether)
        );

        CounterComposer composer = new CounterComposer(
            address(addressResolver),
            address(deployer),
            createFeesData(0.01 ether),
            address(auctionManager)
        );

        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        payloadDetails[0] = createDeployPayloadDetail(
            arbChainSlug,
            address(counterDeployer),
            counterDeployer.creationCodeWithArgs(counterId)
        );
        payloadDetails[0].next[1] = predictAsyncPromiseAddress(
            address(auctionHouse),
            address(auctionHouse)
        );

        _deploy(
            payloadIds,
            arbChainSlug,
            maxFees,
            IAppDeployer(counterDeployer),
            payloadDetails
        );

        address counterForwarder = counterDeployer.forwarderAddresses(
            counterId,
            arbChainSlug
        );
        address deployedCounter = IForwarder(counterForwarder)
            .getOnChainAddress();

        payloadIds = getWritePayloadIds(
            arbChainSlug,
            getPayloadDeliveryPlug(arbChainSlug),
            1
        );

        payloadDetails = new PayloadDetails[](1);
        payloadDetails[0] = createExecutePayloadDetail(
            arbChainSlug,
            deployedCounter,
            address(counterDeployer),
            counterForwarder,
            abi.encodeWithSignature(
                "setSocket(address)",
                counterDeployer.getSocketAddress(arbChainSlug)
            )
        );

        payloadDetails[0].next[1] = predictAsyncPromiseAddress(
            address(auctionHouse),
            address(auctionHouse)
        );

        _configure(
            payloadIds,
            address(counterAppGateway),
            maxFees,
            payloadDetails
        );
    }
}
