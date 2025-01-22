// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {PayloadBatch} from "../common/Structs.sol";

interface IAppGateway {
    function isReadCall() external view returns (bool);

    function isCallSequential() external view returns (bool);

    function onBatchComplete(bytes32 asyncId_, PayloadBatch memory payloadBatch_) external;

    function callFromInbox(
        uint32 chainSlug_,
        address plug_,
        bytes calldata payload_,
        bytes32 params_
    ) external;
}
