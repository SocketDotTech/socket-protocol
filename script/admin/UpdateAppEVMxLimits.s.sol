// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {WatcherPrecompile} from "../../contracts/protocol/watcherPrecompile/WatcherPrecompile.sol";
import {UpdateLimitParams} from "../../contracts/protocol/utils/common/Structs.sol";
import {SCHEDULE, QUERY, FINALIZE} from "../../contracts/protocol/utils/common/Constants.sol";

contract UpdateLimitsScript is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        // Load private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcast with private key
        vm.startBroadcast(deployerPrivateKey);
        address watcherPrecompile = vm.envAddress("WATCHER_PRECOMPILE");
        address appGateway = vm.envAddress("APP_GATEWAY");

        console.log("WatcherPrecompile address:", watcherPrecompile);
        console.log("AppGateway address:", appGateway);
        WatcherPrecompile watcherContract = WatcherPrecompile(watcherPrecompile);

        // Create update params array
        UpdateLimitParams[] memory updates = new UpdateLimitParams[](3);

        // Example update - modify these values as needed
        updates[0] = UpdateLimitParams({
            limitType: SCHEDULE, // Example limit type
            appGateway: appGateway, // Replace with actual app gateway address
            maxLimit: 10000000000, // Maximum limit
            ratePerSecond: 10000000000 // Rate per second
        });
        updates[1] = UpdateLimitParams({
            limitType: QUERY, // Example limit type
            appGateway: appGateway, // Replace with actual app gateway address
            maxLimit: 10000000000, // Maximum limit
            ratePerSecond: 10000000000 // Rate per second
        });
        updates[2] = UpdateLimitParams({
            limitType: FINALIZE, // Example limit type
            appGateway: appGateway, // Replace with actual app gateway address
            maxLimit: 10000000000, // Maximum limit
            ratePerSecond: 10000000000 // Rate per second
        });
        // // Update the limits
        watcherContract.updateLimitParams(updates);

        vm.stopBroadcast();
    }
}
