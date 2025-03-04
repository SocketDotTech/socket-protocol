// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "../../contracts/protocol/payload-delivery/FeesPlug.sol";
import {Fees} from "../../contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "../../contracts/protocol/utils/common/Constants.sol";

contract DepositFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("INTEROP_ALPHA_0_RPC"));
        uint256 privateKey = vm.envUint("SOCKET_SIGNER_KEY");
        vm.startBroadcast(privateKey);

        FeesPlug feesPlug = FeesPlug(payable(vm.envAddress("FEES_PLUG")));
        address appGateway = vm.envAddress("APP_GATEWAY");

        address sender = vm.addr(privateKey);
        console.log("Sender address:", sender);
        uint256 balance = sender.balance;
        console.log("Sender balance in wei:", balance);

        uint feesAmount = 0.0001 ether;
        feesPlug.deposit{value: feesAmount}(ETH_ADDRESS, appGateway, feesAmount);
    }
}
