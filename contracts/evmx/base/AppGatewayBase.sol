// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../helpers/AddressResolverUtil.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IForwarder.sol";
import "../interfaces/IPromise.sol";

import {InvalidPromise, AsyncModifierNotSet} from "../../utils/common/Errors.sol";
import {FAST, READ, WRITE, SCHEDULE} from "../../utils/common/Constants.sol";
import {IsPlug, QueueParams, Read, WriteFinality, Parallel} from "../../utils/common/Structs.sol";
import {toBytes32Format} from "../../utils/common/Converters.sol";

/// @title AppGatewayBase
/// @notice Abstract contract for the app gateway
/// @dev This contract contains helpers for contract deployment, overrides, hooks and request processing
abstract contract AppGatewayBase is AddressResolverUtil, IAppGateway {
    // 50 slots reserved for address resolver util
    // slot 51
    bool public isAsyncModifierSet;
    address public consumeFrom;

    // slot 52
    address public auctionManager;

    // slot 53
    uint256 public maxFees;

    // slot 54
    bytes32 public sbType;

    // slot 55
    bytes public onCompleteData;

    // slot 56
    OverrideParams public overrideParams;

    // slot 57
    mapping(address => bool) public isValidPromise;

    // slot 58
    mapping(bytes32 => mapping(uint32 => address)) public override forwarderAddresses;

    // slot 59
    mapping(bytes32 => bytes) public creationCodeWithArgs;

    /// @notice Modifier to treat functions async
    modifier async() {
        _preAsync();
        _;
        _postAsync();
    }

    /// @notice Modifier to ensure only valid promises can call the function
    /// @dev only valid promises can call the function
    modifier onlyPromises() {
        if (!isValidPromise[msg.sender]) revert InvalidPromise();
        // remove promise once resolved
        isValidPromise[msg.sender] = false;
        _;
    }

    /// @notice Initializer for AppGatewayBase
    /// @param addressResolver_ The address resolver address
    function _initializeAppGateway(address addressResolver_) internal {
        sbType = FAST;
        _setAddressResolver(addressResolver_);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////   ASYNC HELPERS ////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function _preAsync() internal {
        isAsyncModifierSet = true;
        _clearOverrides();
        watcher__().clearQueue();
    }

    function _postAsync() internal {
        isAsyncModifierSet = false;

        (, address[] memory promises) = watcher__().submitRequest(
            maxFees,
            auctionManager,
            consumeFrom,
            onCompleteData
        );
        _markValidPromises(promises);
    }

    function then(bytes4 selector_, bytes memory data_) internal {
        IPromise(watcher__().latestAsyncPromise()).then(selector_, data_);
    }

    /// @notice Schedules a function to be called after a delay
    /// @param delayInSeconds_ The delay in seconds
    /// @dev callback function and data is set in .then call
    function _setSchedule(uint256 delayInSeconds_) internal {
        if (!isAsyncModifierSet) revert AsyncModifierNotSet();
        overrideParams.callType = SCHEDULE;
        overrideParams.delayInSeconds = delayInSeconds_;

        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;
        watcher__().queue(queueParams, address(this));
    }

    /////////////////////////////////   DEPLOY HELPERS ///////////////////////////////////////////////////

    function _deploy(bytes32 contractId_, uint32 chainSlug_, IsPlug isPlug_) internal {
        _deploy(contractId_, chainSlug_, isPlug_, bytes(""));
    }

    /// @notice Deploys a contract
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    function _deploy(
        bytes32 contractId_,
        uint32 chainSlug_,
        IsPlug isPlug_,
        bytes memory initCallData_
    ) internal {
        deployForwarder__().deploy(
            isPlug_,
            chainSlug_,
            initCallData_,
            creationCodeWithArgs[contractId_]
        );

        then(this.setAddress.selector, abi.encode(chainSlug_, contractId_));
        onCompleteData = abi.encode(chainSlug_, true);
    }

    /// @notice Sets the address for a deployed contract
    /// @param data_ The data
    /// @param returnData_ The return data
    function setAddress(bytes memory data_, bytes memory returnData_) external onlyPromises {
        (uint32 chainSlug, bytes32 contractId) = abi.decode(data_, (uint32, bytes32));
        forwarderAddresses[contractId][chainSlug] = asyncDeployer__().getOrDeployForwarderContract(
            toBytes32Format(abi.decode(returnData_, (address))),
            chainSlug
        );
    }

    /// @notice Reverts the transaction
    /// @param requestCount_ The request count
    function _revertTx(uint40 requestCount_) internal {
        watcher__().cancelRequest(requestCount_);
    }

    /// @notice increases the transaction maxFees
    /// @param requestCount_ The request count
    function _increaseFees(uint40 requestCount_, uint256 newMaxFees_) internal {
        watcher__().increaseFees(requestCount_, newMaxFees_);
    }

    /// @notice Gets the on-chain address
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    /// @return onChainAddress The on-chain address
    function getOnChainAddress(
        bytes32 contractId_,
        uint32 chainSlug_
    ) public view returns (bytes32 onChainAddress) {
        if (forwarderAddresses[contractId_][chainSlug_] == address(0)) {
            return bytes32(0);
        }

        onChainAddress = IForwarder(forwarderAddresses[contractId_][chainSlug_])
            .getOnChainAddress();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////   UTILS ////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Creates a contract ID
    /// @param contractName_ The contract name
    /// @return bytes32 The contract ID
    function _createContractId(string memory contractName_) internal pure returns (bytes32) {
        return keccak256(abi.encode(contractName_));
    }

    /// @notice Gets the current request count
    /// @return uint40 The current request count
    function _getCurrentRequestCount() internal view returns (uint40) {
        return watcher__().getCurrentRequestCount();
    }

    /// @notice Marks the promises as valid
    function _markValidPromises(address[] memory promises_) internal {
        for (uint256 i = 0; i < promises_.length; i++) {
            isValidPromise[promises_[i]] = true;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////   ADMIN HELPERS ////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Sets the auction manager
    /// @param auctionManager_ The auction manager
    function _setAuctionManager(address auctionManager_) internal {
        auctionManager = auctionManager_;
    }

    /// @notice Sets the switchboard type
    /// @param sbType_ The switchboard type
    function _setSbType(bytes32 sbType_) internal {
        sbType = sbType_;
    }

    /// @notice Sets the validity of an onchain contract (plug) to authorize it to send information to a specific AppGateway
    /// @param chainSlug_ The unique identifier of the chain where the contract resides
    /// @param contractId_ The bytes32 identifier of the contract to be validated
    /// @param isValid Boolean flag indicating whether the contract is authorized (true) or not (false)
    /// @dev This function retrieves the onchain address using the contractId_ and chainSlug, then calls the watcher precompile to update the plug's validity status
    function _setValidPlug(bool isValid, uint32 chainSlug_, bytes32 contractId_) internal {
        bytes32 onchainAddress = getOnChainAddress(contractId_, chainSlug_);
        watcher__().setIsValidPlug(isValid, chainSlug_, onchainAddress);
    }

    function _approveFeesWithSignature(bytes memory feesApprovalData_) internal {
        if (feesApprovalData_.length == 0) return;
        (consumeFrom, , ) = feesManager__().approveAppGatewayWithSignature(feesApprovalData_);
    }

    /// @notice Withdraws fee tokens
    /// @param chainSlug_ The chain slug
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function _withdrawCredits(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) internal {
        feesManager__().approveAppGateway(address(feesManager__()), true);
        feesManager__().withdrawCredits(chainSlug_, token_, amount_, maxFees, receiver_);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// TX OVERRIDE HELPERS ///////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function _clearOverrides() internal {
        overrideParams.callType = WRITE;
        overrideParams.isParallelCall = Parallel.OFF;
        overrideParams.gasLimit = 0;
        overrideParams.value = 0;
        overrideParams.readAtBlockNumber = 0;
        overrideParams.writeFinality = WriteFinality.LOW;
        overrideParams.delayInSeconds = 0;
        consumeFrom = address(this);
        onCompleteData = bytes("");
    }

    /// @notice Sets multiple overrides in one call
    /// @param isReadCall_ The read call flag
    /// @param fees_ The maxFees configuration
    /// @param gasLimit_ The gas limit
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(
        Read isReadCall_,
        Parallel isParallelCall_,
        uint256 gasLimit_,
        uint256 fees_
    ) internal {
        _setCallType(isReadCall_);
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.gasLimit = gasLimit_;
        maxFees = fees_;
    }

    /// @notice Modifier to treat functions async with consume from address
    function _setOverrides(address consumeFrom_) internal {
        consumeFrom = consumeFrom_;
    }

    /// @notice Sets isReadCall, maxFees and gasLimit overrides
    /// @param isReadCall_ The read call flag
    /// @param isParallelCall_ The sequential call flag
    /// @param gasLimit_ The gas limit
    function _setOverrides(Read isReadCall_, Parallel isParallelCall_, uint256 gasLimit_) internal {
        _setCallType(isReadCall_);
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.gasLimit = gasLimit_;
    }

    /// @notice Sets isReadCall and isParallelCall overrides
    /// @param isReadCall_ The read call flag
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(Read isReadCall_, Parallel isParallelCall_) internal {
        _setCallType(isReadCall_);
        overrideParams.isParallelCall = isParallelCall_;
    }

    /// @notice Sets isParallelCall overrides
    /// @param writeFinality_ The write finality
    function _setOverrides(WriteFinality writeFinality_) internal {
        overrideParams.writeFinality = writeFinality_;
    }

    /// @notice Sets isParallelCall overrides
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(Parallel isParallelCall_) internal {
        overrideParams.isParallelCall = isParallelCall_;
    }

    /// @notice Sets isParallelCall overrides
    /// @param isParallelCall_ The sequential call flag
    /// @param readAtBlockNumber_ The read anchor value. Currently block number.
    function _setOverrides(Parallel isParallelCall_, uint256 readAtBlockNumber_) internal {
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.readAtBlockNumber = readAtBlockNumber_;
    }

    /// @notice Sets isReadCall overrides
    /// @param isReadCall_ The read call flag
    function _setOverrides(Read isReadCall_) internal {
        _setCallType(isReadCall_);
    }

    /// @notice Sets isReadCall overrides
    /// @param isReadCall_ The read call flag
    /// @param readAtBlockNumber_ The read anchor value. Currently block number.
    function _setOverrides(Read isReadCall_, uint256 readAtBlockNumber_) internal {
        _setCallType(isReadCall_);
        overrideParams.readAtBlockNumber = readAtBlockNumber_;
    }

    /// @notice Sets gasLimit overrides
    /// @param gasLimit_ The gas limit
    function _setOverrides(uint256 gasLimit_) internal {
        overrideParams.gasLimit = gasLimit_;
    }

    function _setCallType(Read isReadCall_) internal {
        overrideParams.callType = isReadCall_ == Read.OFF ? WRITE : READ;
    }

    function _setMsgValue(uint256 value_) internal {
        overrideParams.value = value_;
    }

    /// @notice Sets maxFees overrides
    /// @param fees_ The maxFees configuration
    function _setMaxFees(uint256 fees_) internal {
        maxFees = fees_;
    }

    function getOverrideParams() public view returns (OverrideParams memory, bytes32) {
        return (overrideParams, sbType);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// HOOKS /////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Callback in pd promise to be called after all contracts are deployed
    /// @param onCompleteData_ The on complete data
    /// @dev only payload delivery can call this
    /// @dev callback in pd promise to be called after all contracts are deployed
    function onRequestComplete(
        uint40,
        bytes calldata onCompleteData_
    ) external override onlyWatcher {
        if (onCompleteData_.length == 0) return;
        (uint32 chainSlug, bool isDeploy) = abi.decode(onCompleteData_, (uint32, bool));
        if (isDeploy) {
            initializeOnChain(chainSlug);
        }
    }

    /// @notice Initializes the contract after deployment
    /// @dev can be overridden by the app gateway to add custom logic
    /// @param chainSlug_ The chain slug
    function initializeOnChain(uint32 chainSlug_) public virtual {}

    /// @notice hook to handle the revert in callbacks or onchain executions
    /// @dev can be overridden by the app gateway to add custom logic
    /// @param payloadId_ The payload ID
    function handleRevert(bytes32 payloadId_) external override onlyPromises {}
}
