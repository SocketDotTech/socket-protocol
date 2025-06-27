// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SetupTest.t.sol";
import "./apps/Counter.t.sol";

contract AuctionManagerTest is AppGatewayBaseSetup {
    uint32 feesChainSlug = arbChainSlug;
    uint256 constant depositAmount = 1 ether;
    uint256 constant feesAmount = 0.01 ether;

    address receiver = address(uint160(c++));
    address user = address(uint160(c++));

    SocketContracts feesConfig;
    CounterAppGateway counterGateway;

    function setUp() public {
        deploy();

        feesConfig = getSocketConfig(feesChainSlug);
        counterGateway = new CounterAppGateway(address(addressResolver), feesAmount);
        depositNativeAndCredits(feesChainSlug, 100 ether, 0, address(counterGateway));

        bytes32[] memory contractIds = new bytes32[](1);
        contractIds[0] = counterGateway.counter();

        // deploy counter app gateway
        counterGateway.deployContracts(feesChainSlug);
        executeDeploy(IAppGateway(counterGateway), feesChainSlug, contractIds);
    }

    function testExpireBid() public {
        depositNativeAndCredits(feesChainSlug, 1 ether, 0, user);
        approveAppGateway(address(feesManager), user);
        uint256 withdrawAmount = 0.5 ether;
        uint40 requestCount = watcher.getCurrentRequestCount();
        console.log("requestCount", requestCount);

        hoax(user);
        feesManager.withdrawCredits(
            feesChainSlug,
            address(feesConfig.testUSDC),
            withdrawAmount,
            feesAmount,
            address(receiver)
        );
        executeRequest();

        // expire bid settle
        executeRequest();
    }
}
