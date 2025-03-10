// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

//// ENUMS ////
enum CallType {
    READ,
    WRITE,
    DEPLOY,
    WITHDRAW
}

enum IsPlug {
    YES,
    NO
}

enum Parallel {
    OFF,
    ON
}

enum Read {
    OFF,
    ON
}

enum WriteFinality {
    LOW,
    MEDIUM,
    HIGH
}

//// STRUCTS ////

// watcher:
struct PayloadExecutionDetails {
    address middleware;
    address transmitter;
    uint256 deadline;
    bytes32 requestId;
    bytes32 batchId;
    bytes32 digest;
    Payload payload;
}

struct Request {
    bool isRequestCancelled;
    uint256 currentBatch;
    uint256 currentBatchPayloadsExecuted;
    uint256 totalBatchPayloads;
    address middleware;
    PayloadDetails[] payloadDetailsArray;
}
struct FinalizeParams {
    address transmitter;
    bytes32 asyncId;
}


// plug:
struct LimitParams {
    uint256 lastUpdateTimestamp;
    uint256 ratePerSecond;
    uint256 maxLimit;
    uint256 lastUpdateLimit;
}
struct UpdateLimitParams {
    bytes32 limitType;
    address appGateway;
    uint256 maxLimit;
    uint256 ratePerSecond;
}
struct AppGatewayConfig {
    address plug;
    address appGateway;
    address switchboard;
    uint32 chainSlug;
}
// Plug config:
struct PlugConfig {
    address appGateway;
    address switchboard;
}
//inbox:
struct CallFromChainParams {
    bytes32 callId;
    bytes32 params;
    address plug;
    address appGateway;
    uint32 chainSlug;
    bytes payload;
}
// timeout:
struct TimeoutRequest {
    bytes32 timeoutId;
    address target;
    uint256 delayInSeconds;
    uint256 executeAt;
    uint256 executedAt;
    bool isResolved;
    bytes payload;
}
// digest:
struct Digest {
    address appGateway;
    address transmitter;
    address target;
    bytes32 payloadId;
    uint256 value;
    uint256 executionGasLimit;
    uint256 deadline;
    bytes payload;
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

// AM
struct Bid {
    address transmitter;
    uint256 fee;
    bytes extraData;
}

// App gateway base:
struct OverrideParams {
    Read isReadCall;
    Parallel isParallelCall;
    WriteFinality writeFinality;
    uint256 gasLimit;
    uint256 readAt;
}

// socket:
struct AttestAndExecutePayloadParams {
    bytes32 payloadId;
    bytes proof;
    bytes transmitterSignature;
    PayloadExecutionDetails payloadExecutionDetails;
}

// FM:
struct Fees {
    uint32 feePoolChain;
    address feePoolToken;
    uint256 amount;
}

// delivery helper:
struct Payload {
    uint32 chainSlug;
    CallType callType;
    WriteFinality writeFinality;
    address asyncPromise;
    address switchboard;
    address target;
    address appGateway;
    uint256 gasLimit;
    uint256 value;
    uint256 readAt;
    bytes payload;
}
struct CallParams {
    Payload payload;
    IsPlug isPlug;
    Parallel isParallel;
    bytes initCallData;
}
struct PayloadDetails {
    Parallel isParallel;
    uint256 levelNumber;
    Payload payload;
}
struct MiddlewarePayloadRequest {
    address appGateway;
    address auctionManager;
    Fees fees;
    Bid winningBid;
    bytes onCompleteData;
}
