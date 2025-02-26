// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {SuperTokenLockableAppGateway} from "../../test/apps/app-gateways/super-token-lockable/SuperTokenLockableAppGateway.sol";

contract Bridge is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address gateway = vm.envAddress("APP_GATEWAY");
        SuperTokenLockableAppGateway gatewayContract = SuperTokenLockableAppGateway(gateway);

        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address arbTokenForwarder = gatewayContract.forwarderAddresses(
            gatewayContract.superTokenLockable(),
            421614
        );
        address arbHookForwarder = gatewayContract.forwarderAddresses(
            gatewayContract.limitHook(),
            421614
        );
        address optTokenForwarder = gatewayContract.forwarderAddresses(
            gatewayContract.superTokenLockable(),
            11155420
        );
        address optHookForwarder = gatewayContract.forwarderAddresses(
            gatewayContract.limitHook(),
            11155420
        );
        address arbOnChainToken = gatewayContract.getOnChainAddress(
            gatewayContract.superTokenLockable(),
            421614
        );
        address optOnChainToken = gatewayContract.getOnChainAddress(
            gatewayContract.superTokenLockable(),
            11155420
        );
        console.log("arbTokenForwarder");
        console.logAddress(arbTokenForwarder);
        console.log("arbHookForwarder");
        console.logAddress(arbHookForwarder);
        console.log("arbOnChainToken");
        console.logAddress(arbOnChainToken);
        console.log("optTokenForwarder");
        console.logAddress(optTokenForwarder);
        console.log("optHookForwarder");
        console.logAddress(optHookForwarder);
        console.log("optOnChainToken");
        console.logAddress(optOnChainToken);
        if (
            arbTokenForwarder == address(0) ||
            optTokenForwarder == address(0) ||
            arbHookForwarder == address(0) ||
            optHookForwarder == address(0)
        ) {
            revert("Forwarder not found");
        }
        SuperTokenLockableAppGateway.UserOrder memory order = SuperTokenLockableAppGateway
            .UserOrder({
                srcToken: arbTokenForwarder,
                dstToken: optTokenForwarder,
                user: owner,
                srcAmount: 1000,
                deadline: block.timestamp + 1 days
            });
        console.log(order.srcToken);
        console.log(order.dstToken);
        console.log(order.user);
        console.log(order.srcAmount);
        console.log(order.deadline);

        // bytes memory payload = abi.encodeWithSelector(
        //     bytes4(keccak256("bridge(UserOrder)")),
        //     order
        // );
        // console.logBytes(payload);
        gatewayContract.bridge(abi.encode(order));
    }
}
