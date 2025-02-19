// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

enum CallType {
    READ,
    WRITE,
    DEPLOY,
    WITHDRAW
}

enum Read {
    OFF,
    ON
}

enum Parallel {
    OFF,
    ON
}

struct AppGatewayConfig {
    address plug;
    address appGateway;
    address switchboard;
    uint32 chainSlug;
}

struct AsyncRequest {
    address finalizedBy;
    address appGateway;
    address transmitter;
    address target;
    address switchboard;
    uint256 executionGasLimit;
    uint256 expiryTime;
    bytes32 asyncId;
    bytes32 root;
    bytes payload;
    address[] next;
}

struct Bid {
    address transmitter;
    uint256 fee;
    bytes extraData;
}

struct CallFromInboxParams {
    bytes32 callId;
    bytes32 params;
    address plug;
    address appGateway;
    uint32 chainSlug;
    bytes payload;
}

struct CallParams {
    address asyncPromise;
    address target;
    uint32 chainSlug;
    CallType callType;
    Parallel isParallel;
    uint256 gasLimit;
    bytes payload;
}

struct DeployParams {
    address contractAddr;
    bytes bytecode;
}

struct ExecutePayloadParams {
    bytes32 payloadId;
    bytes32 root;
    address switchboard;
    address appGateway;
    address target;
    uint256 executionGasLimit;
    bytes watcherSignature;
    bytes transmitterSignature;
    bytes payload;
}

struct Fees {
    uint32 feePoolChain;
    address feePoolToken;
    uint256 amount;
}

struct FinalizeParams {
    address transmitter;
    bytes32 asyncId;
    PayloadDetails payloadDetails;
}

struct LimitParams {
    uint256 lastUpdateTimestamp;
    uint256 ratePerSecond;
    uint256 maxLimit;
    uint256 lastUpdateLimit;
}

struct PayloadBatch {
    address appGateway;
    address auctionManager;
    bool isBatchCancelled;
    uint256 currentPayloadIndex;
    uint256 totalPayloadsRemaining;
    Fees fees;
    Bid winningBid;
    address[] lastBatchPromises;
    bytes32[] lastBatchOfPayloads;
    bytes onCompleteData;
}

struct PayloadDetails {
    address appGateway;
    address target;
    uint32 chainSlug;
    Parallel isParallel;
    CallType callType;
    uint256 executionGasLimit;
    bytes payload;
    address[] next;
}

struct PayloadRootParams {
    address appGateway;
    address transmitter;
    address target;
    bytes32 payloadId;
    uint256 executionGasLimit;
    uint256 expiryTime;
    bytes payload;
}

struct PlugConfig {
    address appGateway;
    address switchboard;
}

struct QueryResults {
    address target;
    uint256 queryCounter;
    bytes functionSelector;
    bytes returnData;
    bytes callback;
}

struct ResolvedPromises {
    bytes32 payloadId;
    bytes[] returnData;
}

struct TimeoutRequest {
    bytes32 timeoutId;
    address target;
    uint256 delayInSeconds;
    uint256 executeAt;
    uint256 executedAt;
    bool isResolved;
    bytes payload;
}

struct UpdateLimitParams {
    bytes32 limitType;
    address appGateway;
    uint256 maxLimit;
    uint256 ratePerSecond;
}
