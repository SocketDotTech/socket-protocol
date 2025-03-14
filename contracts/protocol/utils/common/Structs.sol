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

// FM:
struct Fees {
    uint32 feePoolChain;
    address feePoolToken;
    uint256 amount;
}

// digest:
struct DigestParams {
    address transmitter;
    bytes32 payloadId;
    uint256 deadline;
    CallType callType;
    WriteFinality writeFinality;
    uint256 gasLimit;
    uint256 value;
    uint256 readAt;
    bytes payload;
    address target;
    address appGateway;
}

struct QueuePayloadParams {
    uint32 chainSlug;
    CallType callType;
    Parallel isParallel;
    IsPlug isPlug;
    WriteFinality writeFinality;
    address asyncPromise;
    address switchboard;
    address target;
    address appGateway;
    uint256 gasLimit;
    uint256 value;
    uint256 readAt;
    bytes payload;
    bytes initCallData;
}

struct PayloadSubmitParams {
    uint256 levelNumber;
    uint32 chainSlug;
    CallType callType;
    Parallel isParallel;
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

struct PayloadParams {
    uint40 requestCount;
    uint40 batchCount;
    uint32 chainSlug;
    CallType callType;
    Parallel isParallel;
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

struct RequestParams {
    bool isRequestCancelled;
    uint256 currentBatch;
    uint256 currentBatchPayloadsExecuted;
    uint256 totalBatchPayloads;
    address middleware;
    address transmitter;
    PayloadParams[] payloadParamsArray;
}

struct RequestMetadata {
    address appGateway;
    address auctionManager;
    Fees fees;
    Bid winningBid;
    bytes onCompleteData;
}

struct ExecuteParams {
    uint256 deadline;
    CallType callType;
    WriteFinality writeFinality;
    uint256 gasLimit;
    uint256 readAt;
    bytes payload;
    address target;
    uint40 requestCount;
    uint40 batchCount;
    uint40 payloadCount;
    bytes32 prevDigestsHash; // should be id? hash of hashes
    address switchboard;
}

struct PayloadIdParams {
    uint40 requestCount;
    uint40 batchCount;
    uint40 payloadCount;
    bytes32 prevDigestsHash; // should be id? hash of hashes
    address switchboard;
    uint32 chainSlug;
}
