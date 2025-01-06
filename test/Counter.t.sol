// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./DeliveryHelper.sol";
import {Counter} from "../contracts/apps/counter/Counter.sol";
import {CounterAppGateway} from "../contracts/apps/counter/CounterAppGateway.sol";
import {CounterDeployer} from "../contracts/apps/counter/CounterDeployer.sol";

contract CounterTest is DeliveryHelperTest {
    CounterDeployer public counterDeployer;
    CounterAppGateway public counterAppGateway;
    bytes32 counterId;

    function setUp() public {
        // core
        setUpDeliveryHelper();

        FeesData memory feesData = FeesData({
            feePoolChain: arbChainSlug,
            feePoolToken: ETH_ADDRESS,
            maxFees: 100000000000000
        });
        counterDeployer = new CounterDeployer(
            address(addressResolver),
            feesData
        );
        counterAppGateway = new CounterAppGateway(
            address(addressResolver),
            address(counterDeployer),
            feesData
        );

        counterId = counterDeployer.counter();
    }

    function testDeploy() public {
        bytes32[] memory payloadIds = getWritePayloadIds(
            arbChainSlug,
            getPayloadDeliveryPlug(arbChainSlug),
            1
        );

        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        payloadDetails[0] = createDeployPayloadDetail(
            arbChainSlug,
            address(counterDeployer),
            counterDeployer.creationCodeWithArgs(counterId)
        );
        payloadDetails[0].next[1] = predictAsyncPromiseAddress(
            address(deliveryHelper),
            address(deliveryHelper)
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
            address(deliveryHelper),
            address(deliveryHelper)
        );

        _configure(
            payloadIds,
            address(counterAppGateway),
            maxFees,
            payloadDetails
        );
    }
}
