// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

//// ENUMS ////
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
    PlugConfig plugConfig;
    address plug;
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

struct ExecuteParams {
    bytes4 callType;
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

struct OnChainFees {
    uint32 chainSlug;
    address token;
    uint256 amount;
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
    bytes4 callType;
    uint256 gasLimit;
    uint256 value;
    bytes payload;
    address target;
    bytes32 appGatewayId;
    bytes32 prevDigestsHash;
    bytes extraData;
}
// App gateway base:
struct OverrideParams {
    bytes4 callType;
    Parallel isParallelCall;
    WriteFinality writeFinality;
    uint256 gasLimit;
    uint256 value;
    uint256 readAtBlockNumber;
    uint256 delayInSeconds;
}

// payload
struct Transaction {
    uint32 chainSlug;
    address target;
    bytes payload;
}

struct DeployParam {
    IsPlug isPlug;
    bytes initCallData;
}

struct QueueParams {
    OverrideParams overrideParams;
    Transaction transaction;
    address asyncPromise;
    bytes32 switchboardType;
}

struct PayloadParams {
    uint40 requestCount;
    uint40 batchCount;
    uint40 payloadCount;
    bytes4 callType;
    address asyncPromise; // todo: multiple promise support?
    address appGateway;
    bytes32 payloadId;
    uint256 resolvedAt; // replaced isPromiseExecuted
    uint256 deadline;
    bytes precompileData;

    // bytes32 prevDigestsHash;
    // address finalizedTransmitter;
    // Transaction transaction;
    // OverrideParams overrideParams;
    // TimeoutRequest timeoutRequest;
    // address switchboard;
}
// timeout:
// struct TimeoutRequest {
//     uint256 delayInSeconds;
//     uint256 executeAt;
//     bool isResolved;
// }

// request
struct RequestTrackingParams {
    bool isRequestCancelled;
    bool isRequestExecuted; //
    uint40 firstBatchCount; //
    uint40 currentBatch; //
    uint256 currentBatchPayloadsLeft; //
    uint256 payloadsRemaining; //
}

struct RequestFeesDetails {
    uint256 maxFees; //
    address consumeFrom; //
    Bid winningBid; //
}

struct RequestParams {
    RequestTrackingParams requestTrackingParams;
    RequestFeesDetails requestFeesDetails;
    address appGateway; //
    address auctionManager; //
    uint256 writeCount; //
    bytes onCompleteData; //
}
