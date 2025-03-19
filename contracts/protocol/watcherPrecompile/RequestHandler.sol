// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./WatcherPrecompileCore.sol";

abstract contract RequestHandler is WatcherPrecompileCore {
    using DumpDecoder for bytes32;

    function submitRequest(
        PayloadSubmitParams[] calldata payloadSubmitParams
    ) public returns (uint40 requestCount) {
        requestCount = nextRequestCount++;
        uint40 batchCount = nextBatchCount;
        uint40 currentBatch = batchCount;

        address appGateway = _checkAppGateways(payloadSubmitParams);

        uint256 readCount;
        uint256 writeCount;

        for (uint256 i = 0; i < payloadSubmitParams.length; i++) {
            PayloadSubmitParams memory p = payloadSubmitParams[i];

            // Count reads and writes
            if (p.callType == CallType.READ) {
                readCount++;
            } else writeCount++;

            if (i > 0) {
                PayloadSubmitParams memory lastP = payloadSubmitParams[i - 1];
                if (p.levelNumber != lastP.levelNumber && p.levelNumber != lastP.levelNumber + 1)
                    revert InvalidLevelNumber();
                if (p.levelNumber == lastP.levelNumber + 1) {
                    requestBatchIds[requestCount].push(batchCount);
                    batchCount = nextBatchCount++;
                }
            }
            uint40 localPayloadCount = payloadCounter++;
            bytes32 payloadId = _createPayloadId(p, requestCount, batchCount, localPayloadCount);
            batchPayloadIds[batchCount].push(payloadId);

            bytes32 dump;
            dump = dump.setRequestCount(requestCount);
            dump = dump.setBatchCount(batchCount);
            dump = dump.setPayloadCount(localPayloadCount);
            dump = dump.setChainSlug(p.chainSlug);
            dump = dump.setCallType(p.callType);
            dump = dump.setIsParallel(p.isParallel);
            dump = dump.setWriteFinality(p.writeFinality);

            payloads[payloadId].dump = dump;
            payloads[payloadId].asyncPromise = p.asyncPromise;
            payloads[payloadId].switchboard = p.switchboard;
            payloads[payloadId].target = p.target;
            payloads[payloadId].appGateway = p.callType == CallType.DEPLOY
                ? addressResolver__.deliveryHelper()
                : p.appGateway;
            payloads[payloadId].payloadId = payloadId;
            payloads[payloadId].prevDigestsHash = bytes32(0);
            payloads[payloadId].gasLimit = p.gasLimit;
            payloads[payloadId].value = p.value;
            payloads[payloadId].readAt = p.readAt;
            payloads[payloadId].deadline = 0;
            payloads[payloadId].payload = p.payload;
            payloads[payloadId].finalizedTransmitter = address(0);

            requestParams[requestCount].payloadParamsArray.push(payloads[payloadId]);
        }

        requestBatchIds[requestCount].push(nextBatchCount++);

        watcherPrecompileLimits__.consumeLimit(appGateway, QUERY, readCount);
        watcherPrecompileLimits__.consumeLimit(appGateway, FINALIZE, writeCount);
        requestParams[requestCount].isRequestCancelled = false;
        requestParams[requestCount].currentBatch = currentBatch;
        requestParams[requestCount].currentBatchPayloadsLeft = 0;
        requestParams[requestCount].payloadsRemaining = payloadSubmitParams.length;
        requestParams[requestCount].middleware = msg.sender;
        requestParams[requestCount].transmitter = address(0);

        emit RequestSubmitted(
            msg.sender,
            requestCount,
            requestParams[requestCount].payloadParamsArray
        );
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
        RequestParams storage r = requestParams[requestCount];
        if (r.middleware != msg.sender) revert InvalidCaller();
        if (r.transmitter != address(0)) revert AlreadyStarted();
        if (r.currentBatchPayloadsLeft > 0) revert AlreadyStarted();
        r.transmitter = transmitter;
        uint40 batchCount = r.payloadParamsArray[0].dump.getBatchCount();

        uint256 totalPayloadsLeft = _processBatch(requestCount, batchCount);
        r.currentBatchPayloadsLeft = totalPayloadsLeft;
    }

    function _processBatch(
        uint40 requestCount_,
        uint40 batchCount_
    ) internal returns (uint256 totalPayloadsLeft) {
        RequestParams memory r = requestParams[requestCount_];
        PayloadParams[] memory payloadParamsArray = _getBatch(requestCount_, batchCount_);

        if (r.isRequestCancelled) revert RequestCancelled();

        for (uint40 i = 0; i < payloadParamsArray.length; i++) {
            bool executed = isPromiseExecuted[payloadParamsArray[i].payloadId];
            if (executed) continue;
            totalPayloadsLeft++;

            if (payloadParamsArray[i].dump.getCallType() != CallType.READ) {
                _finalize(payloadParamsArray[i], r.transmitter);
            } else {
                _query(payloadParamsArray[i]);
            }
        }
    }

    function getCurrentRequestCount() external view returns (uint40) {
        return nextRequestCount;
    }
}
