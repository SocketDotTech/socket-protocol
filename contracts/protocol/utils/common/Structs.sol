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
    uint256 deadline;
    bytes32 asyncId;
    bytes32 digest;
    bytes payload;
    address[] next;
    WriteFinality writeFinality;
    uint256 readAt;
}

struct AttestAndExecutePayloadParams {
    bytes32 payloadId;
    bytes32 digest;
    address switchboard;
    address appGateway;
    address target;
    uint256 executionGasLimit;
    uint256 deadline;
    bytes proof;
    bytes transmitterSignature;
    bytes payload;
}

struct Bid {
    address transmitter;
    uint256 fee;
    bytes extraData;
}

struct CallParams {
    uint32 chainSlug;
    IsPlug isPlug;
    CallType callType;
    Parallel isParallel;
    WriteFinality writeFinality;
    address asyncPromise;
    address switchboard;
    address target;
    uint256 gasLimit;
    uint256 value;
    uint256 readAt;
    bytes payload;
    bytes initCallData;
}

struct CallFromChainParams {
    bytes32 callId;
    bytes32 params;
    address plug;
    address appGateway;
    uint32 chainSlug;
    bytes payload;
}

struct DeployParams {
    address contractAddr;
    bytes bytecode;
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

struct OverrideParams {
    Read isReadCall;
    Parallel isParallelCall;
    uint256 gasLimit;
    WriteFinality writeFinality;
    uint256 readAt;
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
    uint32 chainSlug;
    Parallel isParallel;
    CallType callType;
    WriteFinality writeFinality;
    address appGateway;
    address target;
    address asyncPromise;
	address switchboard;
    uint256 levelNumber;
    uint256 value;
    uint256 executionGasLimit;
    uint256 readAt;
    bytes payload;
}

struct PayloadDigestParams {
    address appGateway;
    address transmitter;
    address target;
    bytes32 payloadId;
    uint256 value;
    uint256 executionGasLimit;
    uint256 deadline;
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
