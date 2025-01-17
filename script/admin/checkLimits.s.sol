// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {WatcherPrecompile} from "../../contracts/watcherPrecompile/WatcherPrecompile.sol";
import {LimitParams} from "../../contracts/common/Structs.sol";
import {SCHEDULE, QUERY, FINALIZE} from "../../contracts/common/Constants.sol";

contract CheckLimitsScript is Script {
    function run() external {
        string memory rpc = vm.envString("OFF_CHAIN_VM_RPC");
        vm.createSelectFork(rpc);

        address watcherPrecompile = vm.envAddress("WATCHER_PRECOMPILE");
        address cronAppGateway = vm.envAddress("APP_GATEWAY");

        console.log("WatcherPrecompile address:", watcherPrecompile);
        console.log("CronAppGateway address:", cronAppGateway);
        WatcherPrecompile watcherContract = WatcherPrecompile(watcherPrecompile);
        LimitParams memory scheduleLimit = watcherContract.getLimitParams(cronAppGateway, SCHEDULE);
        LimitParams memory queryLimit = watcherContract.getLimitParams(cronAppGateway, QUERY);
        LimitParams memory finalizeLimit = watcherContract.getLimitParams(cronAppGateway, FINALIZE);
        console.log("Schedule limit:");
        console.log(scheduleLimit.maxLimit);
        console.log("Query limit:");
        console.log(queryLimit.maxLimit);
        console.log("Finalize limit:");
        console.log(finalizeLimit.maxLimit);
    }
}
