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
    WAITING_FOR_CALLBACK_SELECTOR,
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

struct AppGatewayApprovals {
    address appGateway;
    bool approval;
}

//// STRUCTS ////
struct AppGatewayConfig {
    PlugConfigGeneric plugConfig;
    bytes32 plug;
    uint32 chainSlug;
}
// Plug config:
// struct PlugConfig {
//     bytes32 appGatewayId;
//     address switchboard;
// }
struct PlugConfigGeneric {
    bytes32 appGatewayId;
    bytes32 switchboard;
}

// Plug config:
struct PlugConfigEvm {
    bytes32 appGatewayId;
    address switchboard;
}

//trigger:
struct TriggerParams {
    bytes32 triggerId;
    bytes32 plug;
    bytes32 appGatewayId;
    uint32 chainSlug;
    bytes overrides;
    bytes payload;
}

struct PromiseReturnData {
    bool exceededMaxCopy;
    bytes32 payloadId;
    bytes returnData;
}
// AM
struct ExecuteParams {
    bytes4 callType;
    uint40 requestCount;
    uint40 batchCount;
    uint40 payloadCount;
    uint256 deadline;
    uint256 gasLimit;
    uint256 value;
    bytes32 prevBatchDigestHash;
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

struct WatcherMultiCallParams {
    address contractAddress;
    bytes data;
    uint256 nonce;
    bytes signature;
}

struct CreateRequestResult {
    uint256 totalEstimatedWatcherFees;
    uint256 writeCount;
    address[] promiseList;
    PayloadParams[] payloadParams;
}

struct Bid {
    uint256 fee;
    address transmitter;
    bytes extraData;
}

struct UserCredits {
    uint256 totalCredits;
    uint256 blockedCredits;
}

// digest:
struct DigestParams {
    bytes32 socket;
    address transmitter;
    bytes32 payloadId;
    uint256 deadline;
    bytes4 callType;
    uint256 gasLimit;
    uint256 value;
    bytes payload;
    bytes32 target;
    bytes32 appGatewayId;
    bytes32 prevBatchDigestHash;
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

struct Transaction {
    uint32 chainSlug;
    bytes32 target;
    bytes payload;
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
    address asyncPromise;
    address appGateway;
    bytes32 payloadId;
    uint256 resolvedAt;
    uint256 deadline;
    bytes precompileData;
}

// request
struct RequestTrackingParams {
    bool isRequestCancelled;
    bool isRequestExecuted;
    uint40 currentBatch;
    uint256 currentBatchPayloadsLeft;
    uint256 payloadsRemaining;
}

struct RequestFeesDetails {
    uint256 maxFees;
    address consumeFrom;
    Bid winningBid;
}

struct RequestParams {
    RequestTrackingParams requestTrackingParams;
    RequestFeesDetails requestFeesDetails;
    address appGateway;
    address auctionManager;
    uint256 writeCount;
    bytes onCompleteData;
}

/********* Solana payloads *********/

/** Solana write payload - SolanaInstruction **/

struct SolanaInstruction {
    SolanaInstructionData data;
    SolanaInstructionDataDescription description;
}

struct SolanaInstructionData {
    bytes32 programId;
    bytes32[] accounts;
    bytes8 instructionDiscriminator;
    bytes[] functionArguments;
}

struct SolanaInstructionDataDescription {
    // flags for accounts, we only need isWritable for now
    // 0 bit - isWritable (0|1)
    bytes1[] accountFlags;
    // names for function argument types used later in data decoding in watcher and transmitter
    string[] functionArgumentTypeNames;
}

/** Solana read payload - SolanaReadInstruction **/

enum SolanaReadSchemaType {
    PREDEFINED,
    GENERIC
}

struct SolanaReadRequest {
    bytes32 accountToRead;
    SolanaReadSchemaType schemaType;
    // keccak256("schema-name")
    bytes32 predefinedSchemaNameHash;
}

// this is only used after getting the data from Solana account
struct GenericSchema {
    // list of types recognizable by BorshEncoder that we expect to read from Solana account (data model)
    string[] valuesTypeNames;
}