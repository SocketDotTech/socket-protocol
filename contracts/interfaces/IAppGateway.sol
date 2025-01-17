// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {PayloadBatch} from "../common/Structs.sol";
interface IAppGateway {
    function isReadCall() external view returns (bool);

    function isCallSequential() external view returns (bool);

    function onBatchComplete(bytes32 asyncId, PayloadBatch memory payloadBatch) external;

    function callFromInbox(
        uint32 chainSlug,
        address plug,
        bytes calldata payload,
        bytes32 params
    ) external;
}
