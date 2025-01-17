// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {SuperTokenLockableAppGateway} from "../../contracts/apps/super-token-lockable/SuperTokenLockableAppGateway.sol";
import {SuperTokenLockableDeployer} from "../../contracts/apps/super-token-lockable/SuperTokenLockableDeployer.sol";

contract Bridge is Script {
    function run() external {
        address owner = vm.envAddress("SUPERTOKEN_OWNER");
        address deployer = vm.envAddress("SUPERTOKEN_DEPLOYER");
        address gateway = vm.envAddress("SUPERTOKEN_APP_GATEWAY");
        SuperTokenLockableAppGateway gatewayContract = SuperTokenLockableAppGateway(gateway);
        SuperTokenLockableDeployer deployerContract = SuperTokenLockableDeployer(deployer);
        string memory rpc = vm.envString("OFF_CHAIN_VM_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address arbTokenForwarder = deployerContract.forwarderAddresses(
            deployerContract.superTokenLockable(),
            421614
        );
        address arbHookForwarder = deployerContract.forwarderAddresses(
            deployerContract.limitHook(),
            421614
        );
        address optTokenForwarder = deployerContract.forwarderAddresses(
            deployerContract.superTokenLockable(),
            11155420
        );
        address optHookForwarder = deployerContract.forwarderAddresses(
            deployerContract.limitHook(),
            11155420
        );
        address arbOnChainToken = deployerContract.getOnChainAddress(
            deployerContract.superTokenLockable(),
            421614
        );
        address optOnChainToken = deployerContract.getOnChainAddress(
            deployerContract.superTokenLockable(),
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
