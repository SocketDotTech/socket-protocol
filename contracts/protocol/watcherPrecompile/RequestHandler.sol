// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {RequestParams, PayloadSubmitParams, PayloadParams} from "../utils/common/Structs.sol";
import "./WatcherPrecompileCore.sol";

abstract contract RequestHandler is WatcherPrecompileCore {
    uint40 public nextRequestCount;
    uint40 public nextBatchCount = 1;
    mapping(uint256 => RequestParams) public requestParams;
    mapping(uint40 => bytes32[]) public batchPayloadIds;
    mapping(uint40 => uint40[]) public requestBatchIds;

    event RequestSubmitted(
        address middleware,
        uint40 requestCount,
        PayloadParams[] payloadParamsArray
    );

    function submitRequest(
        PayloadSubmitParams[] calldata payloadSubmitParams
    ) public returns (uint40 requestCount) {
        PayloadParams[] payloadParamsArray = new PayloadParams[]();

        requestCount = nextRequestCount++;
        uint40 batchCount = nextBatchCount++;
        uint40 currentBatch = batchCount;

        address appGateway = _checkAppGateways(payloadSubmitParams);

        uint256 readCount;
        uint256 writeCount;

        for (uint256 i = 0; i < payloadSubmitParams.length; i++) {
            PayloadSubmitParams p = payloadSubmitParams[i];

            // Count reads and writes
            if (p.callType == CallType.READ) {
                readCount++;
            } else writeCount++;

            /// consume limit
            if (i > 0) {
                PayloadSubmitParams lastP = payloadSubmitParams[i - 1];
                if (p.levelNumber != lastP.levelNumber && p.levelNumber != lastP.levelNumber + 1)
                    revert InvalidLevelNumber();
                if (p.levelNumber == lastP.levelNumber + 1) {
                    requestBatchIds[requestCount].push(batchCount);
                    batchCount = nextBatchCount++;
                }
            }

            uint40 localPayloadCount = payloadCount++;
            bytes32 payloadId = _createPayloadId(
                p,
                requestCount,
                batchCount,
                localPayloadCount,
                prevDigestsHash
            );
            batchPayloadIds[batchCount].push(payloadId);
            payload[payloadId] = p;

            payloadParamsArray.push(
                PayloadParams({
                    requestCount: requestCount,
                    batchCount: batchCount,
                    payloadCount: localPayloadCount,
                    chainSlug: p.chainSlug,
                    callType: p.callType,
                    isParallel: p.isParallel,
                    writeFinality: p.writeFinality,
                    asyncPromise: p.asyncPromise,
                    switchboard: p.switchboard,
                    target: p.target,
                    appGateway: p.appGateway,
                    payloadId: payloadId,
                    gasLimit: p.gasLimit,
                    value: p.value,
                    readAt: p.readAt,
                    payload: p.payload
                })
            );
        }

        _consumeLimit(appGateway, QUERY, readCount);
        _consumeLimit(appGateway, FINALIZE, writeCount);

        requestParams[requestCount] = RequestParams({
            isRequestCancelled: false,
            currentBatch: currentBatch,
            currentBatchPayloadsExecuted: 0,
            totalBatchPayloads: 0,
            middleware: msg.sender,
            transmitter: address(0),
            payloadParamsArray: payloadParamsArray
        });

        emit RequestSubmitted(msg.sender, requestCount, payloadParamsArray);
    }

    function _checkAppGateways(
        PayloadSubmitParams[] calldata payloadSubmitParams
    ) internal view returns (address appGateway) {
        bool isDeliveryHelper = msg.sender == addressResolver__.deliveryHelper();
        address coreAppGateway = isDeliveryHelper
            ? payloadSubmitParams[0].appGateway
            : _getCoreAppGateway(payloadSubmitParams[0].appGateway);

        for (uint256 i = 0; i < payloadSubmitParams.length; i++) {
            address callerAppGateway = isDeliveryHelper
                ? payloadSubmitParams[i].appGateway
                : msg.sender;
            appGateway = _getCoreAppGateway(callerAppGateway);
            if (appGateway != coreAppGateway) revert InvalidGateway();
        }
    }

    function startProcessingRequest(uint40 requestCount, address transmitter) public {
        RequestParams r = requestParams[requestCount];
        if (r.middleware != msg.sender) revert InvalidCaller();
        if (r.transmitter != address(0)) revert AlreadyStarted();
        if (r.currentBatchPayloadsExecuted > 0) revert AlreadyStarted();

        r.transmitter = transmitter;
        uint40 batchCount = r.payloadParamsArray[0].batchCount;
        _processBatch(requestCount, batchCount);
    }

    function _processBatch(uint40 requestCount_, uint40 batchCount_) private {
        RequestParams r = requestParams[requestCount_];
        PayloadParams[] memory payloadParamsArray = _getBatch(requestCount_, batchCount_);
        if (r.isRequestCancelled) revert RequestCancelled();

        for (uint40 i = 0; i < payloadParamsArray.length; i++) {
            bool isResolved = IPromise(payloadParamsArray[i].asyncPromise).resolved();
            if (isResolved) continue;

            if (payloadParamsArray[i].callType != CallType.READ) {
                _finalize(payloadParamsArray[i], r.transmitter);
            } else {
                _query(payloadParamsArray[i]);
            }
        }
    }

    function _getBatch(
        uint40 requestCount,
        uint40 batchCount
    ) private view returns (PayloadParams[] memory) {
        RequestParams r = requestParams[requestCount];
        PayloadParams[] memory payloadParamsArray = new PayloadParams[]();

        for (uint40 i = 0; i < r.payloadParamsArray.length; i++) {
            if (r.payloadParamsArray[i].batchCount == batchCount) {
                payloadParamsArray.push(r.payloadParamsArray[i]);
            }
        }
        return payloadParamsArray;
    }
}
