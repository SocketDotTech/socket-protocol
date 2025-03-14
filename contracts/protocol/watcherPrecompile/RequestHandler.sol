// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {RequestParams, PayloadSubmitParams} from "../utils/common/Structs.sol";

abstract contract RequestHandler {
    uint40 public nextRequestCount;
    uint40 public nextBatchCount;

    mapping(uint256 => RequestParams) public requestParams;

    function submitRequest(
        PayloadSubmitParams[] calldata payloadSubmitParams
    ) public returns (uint40 requestCount) {
        PayloadParams[] payloadParamsArray = new PayloadParams[]();

        requestCount = nextRequestCount++;
        uint40 batchCount = nextBatchCount++;
        uint40 currentBatch = batchCount;

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

        requestParams[requestCount] = RequestParams({
            isRequestCancelled: false,
            currentBatch: currentBatch,
            currentBatchPayloadsExecuted: 0,
            totalBatchPayloads: 0,
            middleware: msg.sender,
            transmitter: address(0),
            payloadParamsArray: payloadParamsArray
        });
    }

    function startProcessingRequest(uint40 requestCount, address transmitter) public {
        RequestParams r = requestParams[requestCount];
        require(!r.isRequestCancelled, RequestCancelled());
        require(r.middleware == msg.sender, InvalidCaller());
        require(r.transmitter == address(0), AlreadyStarted());
        r.transmitter = transmitter;
        _processNextBatch(requestCount);
    }

    function _processNextBatch(uint40 requestCount) private {
        RequestParams r = requestParams[requestCount];
        PayloadParams[] memory payloadParamsArray = _getNextBatch(requestCount);
        for (uint40 i = 0; i < payloadParamsArray.length; i++) {
            // todo: finalize or query
        }
    }

    function updateTransmitter(uint40 requestCount, address transmitter) public {
        RequestParams r = requestParams[requestCount];
        require(!r.isRequestCancelled, RequestCancelled());
        require(r.middleware == msg.sender, InvalidCaller());
        r.transmitter = transmitter;
        _reprocessCurrentBatch(requestCount);
    }

    function cancelRequest(uint40 requestCount) public {
        RequestParams r = requestParams[requestCount];
        require(!r.isRequestCancelled, RequestAlreadyCancelled());
        require(r.middleware == msg.sender, InvalidCaller());
        r.isRequestCancelled = true;
    }

    function _getNextBatch(uint40 requestCount) private view returns (PayloadParams[] memory) {
        RequestParams r = requestParams[requestCount];
        PayloadParams[] memory payloadParamsArray = new PayloadParams[]();
        uint40 nextBatch = r.currentBatch + 1;
        for (uint40 i = 0; i < r.payloadParamsArray.length; i++) {
            if (r.payloadParamsArray[i].batchCount == nextBatch) {
                payloadParamsArray.push(r.payloadParamsArray[i]);
            }
        }
        return payloadParamsArray;
    }

    function _getCurrentBatch(uint40 requestCount) private view returns (PayloadParams[] memory) {
        RequestParams r = requestParams[requestCount];
        PayloadParams[] memory payloadParamsArray = new PayloadParams[]();
        for (uint40 i = 0; i < r.payloadParamsArray.length; i++) {
            if (r.payloadParamsArray[i].batchCount == r.currentBatch) {
                payloadParamsArray.push(r.payloadParamsArray[i]);
            }
        }
        return payloadParamsArray;
    }
}
