// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SetupTest.t.sol";

contract WatcherTest is AppGatewayBaseSetup {
    function testWatcherDeployment() public {
        deploy();

        vm.assertEq(address(arbConfig.feesPlug.socket__()), address(arbConfig.socket));
        vm.assertEq(address(optConfig.feesPlug.socket__()), address(optConfig.socket));

        vm.assertEq(address(arbConfig.contractFactoryPlug.socket__()), address(arbConfig.socket));
        vm.assertEq(address(optConfig.contractFactoryPlug.socket__()), address(optConfig.socket));
    }
}
