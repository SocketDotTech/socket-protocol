// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {RequestParams, PayloadSubmitParams} from "../utils/common/Structs.sol";

abstract contract RequestHandler {
    uint40 public nextRequestCount;
    uint40 public nextBatchCount;

    mapping(uint256 => RequestParams) public requestParams;

    function submitRequest(
        PayloadSubmitParams[] calldata payloadSubmitParams
    ) public returns (bytes32 requestCount) {
        PayloadParams[] payloadParamsArray;

        uint256 requestCount = nextRequestCount++;
        uint256 batchCount = nextBatchCount++;

        for (uint256 i = 0; i < payloadSubmitParams.length; i++) {
            PayloadSubmitParams p = payloadSubmitParams[i];
            if (i > 0) {
                PayloadSubmitParams lastP = payloadSubmitParams[i - 1];
                require(
                    p.levelNumber == lastP.levelNumber || p.levelNumber == lastP.levelNumber + 1,
                    InvalidLevelNumber()
                );
                if (p.levelNumber == lastP.levelNumber + 1) {
                    batchCount = nextBatchCount++;
                }
            }

            payloadParamsArray.push(
                PayloadParams({
                    requestCount: requestCount,
                    batchCount: batchCount,
                    chainSlug: p.chainSlug,
                    callType: p.callType,
                    isParallel: p.isParallel,
                    writeFinality: p.writeFinality,
                    asyncPromise: p.asyncPromise,
                    switchboard: p.switchboard,
                    target: p.target,
                    appGateway: p.appGateway,
                    gasLimit: p.gasLimit,
                    value: p.value,
                    readAt: p.readAt,
                    payload: p.payload
                })
            );
        }
        RequestParams requestParams = RequestParams({
            isRequestCancelled: false;
            currentBatch;
            currentBatchPayloadsExecuted; // todo
            totalBatchPayloads; // todo
            middleware: msg.sender;
            payloadParamsArray: payloadParamsArray;
        });
    }
}
