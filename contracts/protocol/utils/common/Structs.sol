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

/// @notice Creates a struct to hold batch parameters
struct BatchParams {
    address appGateway;
    address auctionManager;
    uint256 maxFees;
    bytes onCompleteData;
    bool onlyReadRequests;
    uint256 queryCount;
    uint256 finalizeCount;
}

struct AppGatewayWhitelistParams {
    address appGateway;
    bool isApproved;
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
    bytes32 appGatewayId;
    address switchboard;
    uint32 chainSlug;
}
// Plug config:
struct PlugConfig {
    bytes32 appGatewayId;
    address switchboard;
}
//trigger:
struct TriggerParams {
    bytes32 triggerId;
    address plug;
    bytes32 appGatewayId;
    uint32 chainSlug;
    bytes overrides;
    bytes payload;
}
// timeout:
struct TimeoutRequest {
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
    uint256 fee;
    address transmitter;
    bytes extraData;
}

struct OnChainFees {
    uint32 chainSlug;
    address token;
    uint256 amount;
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
    uint256 gasLimit;
    uint256 value;
    bytes payload;
    address target;
    bytes32 appGatewayId;
    bytes32 prevDigestsHash;
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
    uint256 queryCount;
    uint256 finalizeCount;
    uint256 scheduleCount;
    address middleware;
    // updated after auction
    address transmitter;
    PayloadParams[] payloadParamsArray;
}

struct RequestMetadata {
    bool onlyReadRequests;
    address consumeFrom;
    address appGateway;
    address auctionManager;
    uint256 maxFees;
    uint256 queryCount;
    uint256 finalizeCount;
    Bid winningBid;
    bytes onCompleteData;
}

struct ExecuteParams {
    CallType callType;
    uint40 requestCount;
    uint40 batchCount;
    uint40 payloadCount;
    uint256 deadline;
    uint256 gasLimit;
    uint256 value;
    bytes32 prevDigestsHash;
    address target;
    bytes payload;
    bytes extraData;
}

struct TransmissionParams {
    uint256 socketFees;
    address refundAddress;
    bytes extraData;
    bytes transmitterSignature;
}

struct PayloadIdParams {
    uint40 requestCount;
    uint40 batchCount;
    uint40 payloadCount;
    uint32 chainSlug;
    address switchboard;
}
