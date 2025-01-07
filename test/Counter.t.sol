// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CounterAppGateway} from "../contracts/apps/counter/CounterAppGateway.sol";
import {CounterDeployer} from "../contracts/apps/counter/CounterDeployer.sol";
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

        CounterAppGateway gateway = new CounterAppGateway(
            address(addressResolver),
            address(deployer),
            address(auctionManager),
            createFeesData(0.01 ether)
        );
        UpdateLimitParams[] memory params = new UpdateLimitParams[](2);
        params[0] = UpdateLimitParams({
            limitType: FINALIZE,
            appGateway: address(deployer),
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });
        params[1] = UpdateLimitParams({
            limitType: FINALIZE,
            appGateway: address(gateway),
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });

        hoax(watcherEOA);
        watcherPrecompile.updateLimitParams(params);
        skip(1000);

        bytes32[] memory payloadIds = getWritePayloadIds(
            arbChainSlug,
            address(arbConfig.switchboard),
            1
        );
        bytes32[] memory contractIds = new bytes32[](2);
        contractIds[1] = deployer.counter();

        _deploy(
            contractIds,
            payloadIds,
            arbChainSlug,
            IAppDeployer(deployer),
            address(gateway)
        );
    }
}
