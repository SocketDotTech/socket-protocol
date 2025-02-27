// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockWatcherPrecompile} from "../../test/mock/MockWatcherPrecompile.sol";

contract QueryTest is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address watcher = vm.envAddress("WATCHER_PRECOMPILE");
        MockWatcherPrecompile watcherInstance = MockWatcherPrecompile(watcher);

        address[] memory asyncPromises = new address[](1);
        asyncPromises[0] = address(0);
        bytes memory payload = abi.encodeWithSignature("balanceOf(address)", address(0));
        watcherInstance.query(
            421614,
            0x6402c4c08C1F752Ac8c91beEAF226018ec1a27f2, // usdc contract
            asyncPromises,
            payload
        );
    }
}
