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
    IsPlug isPlug;
    address asyncPromise;
    address target;
    uint32 chainSlug;
    CallType callType;
    Parallel isParallel;
    uint256 gasLimit;
    uint256 value;
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
    uint256 value;
    uint256 executionGasLimit;
    bytes payload;
    address[] next;
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
