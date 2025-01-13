// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {WatcherPrecompile} from "../../contracts/watcherPrecompile/WatcherPrecompile.sol";
import {UpdateLimitParams} from "../../contracts/common/Structs.sol";
import {SCHEDULE, QUERY, FINALIZE} from "../../contracts/common/Constants.sol";

contract UpdateLimitsScript is Script {
    function run() external {
        // Load private key from env
        uint256 deployerPrivateKey = vm.envUint("WATCHER_PRIVATE_KEY");

        // Start broadcast with private key
        vm.startBroadcast(deployerPrivateKey);

        // Get WatcherPrecompile contract address from deployment json
        // string memory json = vm.readFile("deployments/dev_addresses.json");
        // address watcherAddress = abi.decode(vm.parseJson(json, "7625382.WatcherPrecompile"), (address));
        address watcherPrecompile = vm.envAddress("WATCHER_PRECOMPILE");
        address cronAppGateway = vm.envAddress("CRON_APP_GATEWAY");

        console.log("WatcherPrecompile address:", watcherPrecompile);
        console.log("CronAppGateway address:", cronAppGateway);
        WatcherPrecompile watcherContract = WatcherPrecompile(watcherPrecompile);

        // Create update params array
        UpdateLimitParams[] memory updates = new UpdateLimitParams[](1);

        // Example update - modify these values as needed
        updates[0] = UpdateLimitParams({
            limitType: SCHEDULE, // Example limit type
            appGateway: cronAppGateway, // Replace with actual app gateway address
            maxLimit: 1000, // Maximum limit
            ratePerSecond: 1 // Rate per second
        });

        // // Update the limits
        bytes memory payload = abi.encodeCall(watcherContract.updateLimitParams, updates);
        console.logBytes(payload);
        watcherContract.updateLimitParams(updates);

        vm.stopBroadcast();
    }
}
