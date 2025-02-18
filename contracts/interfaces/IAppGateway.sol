// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {PayloadBatch} from "../protocol/utils/common/Structs.sol";

interface IAppGateway {
    function isReadCall() external view returns (bool);

    function isCallSequential() external view returns (bool);

    function gasLimit() external view returns (uint256);

    function onBatchComplete(bytes32 asyncId_, PayloadBatch memory payloadBatch_) external;

    function callFromInbox(
        uint32 chainSlug_,
        address plug_,
        bytes calldata payload_,
        bytes32 params_
    ) external;

    function handleRevert(bytes32 asyncId_, bytes32 payloadId_) external;
}
