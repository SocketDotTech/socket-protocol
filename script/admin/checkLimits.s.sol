


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {WatcherPrecompile} from "../../contracts/watcherPrecompile/WatcherPrecompile.sol";
import {LimitParams} from "../../contracts/common/Structs.sol";
import {SCHEDULE, QUERY, FINALIZE} from "../../contracts/common/Constants.sol";

contract CheckLimitsScript is Script {
    function run() external {
        address watcherPrecompile = vm.envAddress("WATCHER_PRECOMPILE");
        address cronAppGateway = vm.envAddress("CRON_APP_GATEWAY");

        console.log("WatcherPrecompile address:", watcherPrecompile);
        console.log("CronAppGateway address:", cronAppGateway);
        WatcherPrecompile watcherContract = WatcherPrecompile(watcherPrecompile);
        LimitParams memory limitParams = watcherContract.getLimitParams(cronAppGateway, SCHEDULE);
        console.log("Max limit:", limitParams.maxLimit);
        console.log("Rate per second:", limitParams.ratePerSecond);
    }
}
