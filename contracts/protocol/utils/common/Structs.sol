// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

//// ENUMS ////
enum CallType {
    READ,
    WRITE,
    DEPLOY
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

enum SwitchboardStatus {
    NOT_REGISTERED,
    REGISTERED,
    DISABLED
}

/// @notice The state of the async promise
enum AsyncPromiseState {
    WAITING_FOR_SET_CALLBACK_SELECTOR,
    WAITING_FOR_CALLBACK_EXECUTION,
    CALLBACK_REVERTING,
    ONCHAIN_REVERTING,
    RESOLVED
}

enum ExecutionStatus {
    NotExecuted,
    Executed,
    Reverted
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
//trigger:
struct TriggerParams {
    bytes32 triggerId;
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

struct ResolvedPromises {
    bytes32 payloadId;
    bytes returnData;
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
    uint256 value;
    uint256 readAt;
}

// FM:
struct RequestFee {
    uint256 blockedCredits;
    address consumeFrom;
}

struct UserCredits {
    uint256 totalCredits;
    uint256 blockedCredits;
}

// digest:
struct DigestParams {
    address socket;
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
    bytes32 prevDigestsHash; // should be id? hash of hashes
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
    // uint40 requestCount + uint40 batchCount + uint40 payloadCount + uint32 chainSlug
    // CallType callType + Parallel isParallel + WriteFinality writeFinality
    bytes32 payloadHeader;
    // uint40 requestCount;
    // uint40 batchCount;
    // uint40 payloadCount;
    // uint32 chainSlug;
    // CallType callType;
    // Parallel isParallel;
    // WriteFinality writeFinality;
    address asyncPromise;
    address switchboard;
    address target;
    address appGateway;
    bytes32 payloadId;
    bytes32 prevDigestsHash;
    uint256 gasLimit;
    uint256 value;
    uint256 readAt;
    uint256 deadline;
    bytes payload;
    address finalizedTransmitter;
}

struct RequestParams {
    bool isRequestCancelled;
    uint40 currentBatch;
    // updated while processing request
    uint256 currentBatchPayloadsLeft;
    uint256 payloadsRemaining;
    address middleware;
    // updated after auction
    address transmitter;
    PayloadParams[] payloadParamsArray;
}

struct RequestMetadata {
    address appGateway;
    address auctionManager;
    uint256 fees;
    Bid winningBid;
    bytes onCompleteData;
    bool onlyReadRequests;
    bytes feesApprovalData;
}

struct ExecuteParams {
    uint256 deadline;
    CallType callType;
    WriteFinality writeFinality;
    uint256 gasLimit;
    uint256 value;
    uint256 readAt;
    bytes payload;
    address target;
    uint40 requestCount;
    uint40 batchCount;
    uint40 payloadCount;
    bytes32 prevDigestsHash; // should be id? hash of hashes
    address switchboard;
}
