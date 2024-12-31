// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum CallType {
    READ,
    WRITE,
    DEPLOY,
    WITHDRAW
}

struct FeesData {
    uint32 feePoolChain;
    address feePoolToken;
    uint256 maxFees;
}

struct PayloadDetails {
    uint32 chainSlug;
    address target;
    bytes payload;
    CallType callType;
    uint256 executionGasLimit;
    address[] next;
    bool isSequential;
}

struct DeployParams {
    address contractAddr;
    bytes bytecode;
}

struct CallParams {
    CallType callType;
    address asyncPromise;
    uint32 chainSlug;
    address target;
    uint256 gasLimit;
    bytes payload;
    bool isSequential;
}

struct Bid {
    uint256 fee;
    address transmitter;
    bytes extraData;
}

struct PayloadBatch {
    address appGateway;
    FeesData feesData;
    uint256 currentPayloadIndex;
    address auctionManager;
    Bid winningBid;
    bool isBatchCancelled;
    uint256 totalPayloadsRemaining;
}

struct FinalizeParams {
    PayloadDetails payloadDetails;
    address transmitter;
}

// list of promises to resolve
struct AsyncRequest {
    address[] next;
    address appGateway;
    address transmitter;
    uint256 executionGasLimit;
    bytes payload;
    address switchboard;
    bytes32 root;
}

struct PayloadRootParams {
    bytes32 payloadId;
    address appGateway;
    address transmitter;
    address target;
    uint256 executionGasLimit;
    bytes payload;
}

struct PlugConfig {
    address appGateway;
    address switchboard;
}

struct AppGatewayConfig {
    address plug;
    uint32 chainSlug;
    address appGateway;
    address switchboard;
}

struct ResolvedPromises {
    bytes32 payloadId;
    bytes[] returnData;
}

struct QueryResults {
    uint256 queryCounter;
    address target;
    bytes functionSelector;
    bytes returnData;
    bytes callback;
}

struct ExecutePayloadParams {
    address switchboard;
    bytes32 root;
    bytes watcherSignature;
    bytes32 payloadId;
    address appGateway;
    uint256 executionGasLimit;
    bytes transmitterSignature;
    bytes payload;
    address target;
}

struct TimeoutRequest {
    bytes32 timeoutId;
    address target;
    bytes payload;
    uint256 delayInSeconds;
    uint256 executeAt;
    uint256 executedAt;
    bool isResolved;
}

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

struct CallFromInboxParams {
    bytes32 callId;
    uint32 chainSlug;
    address plug;
    address appGateway;
    bytes32 params;
    bytes payload;
}
