// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../protocol/utils/AddressResolverUtil.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IForwarder.sol";
import "../interfaces/IDeliveryHelper.sol";
import "../interfaces/IPromise.sol";

import {FeesPlugin} from "../protocol/utils/FeesPlugin.sol";
import {InvalidPromise, FeesNotSet} from "../protocol/utils/common/Errors.sol";
import {FAST} from "../protocol/utils/common/Constants.sol";

/// @title AppGatewayBase
/// @notice Abstract contract for the app gateway
abstract contract AppGatewayBase is AddressResolverUtil, IAppGateway, FeesPlugin {
    OverrideParams public overrideParams;
    address public auctionManager;
    bytes public onCompleteData;
    bytes32 public sbType;
    bool public isAsyncModifierSet;

    mapping(address => bool) public isValidPromise;
    mapping(bytes32 => mapping(uint32 => address)) public override forwarderAddresses;
    mapping(bytes32 => bytes) public creationCodeWithArgs;

    /// @notice Modifier to treat functions async
    modifier async() {
        if (fees.feePoolChain == 0) revert FeesNotSet();
        isAsyncModifierSet = true;
        deliveryHelper().clearQueue();
        addressResolver__.clearPromises();
        _clearOverrides();
        _;
        isAsyncModifierSet = false;
        deliveryHelper().batch(fees, auctionManager, onCompleteData, sbType);
        _markValidPromises();
        onCompleteData = bytes("");
    }

    /// @notice Modifier to ensure only valid promises can call the function
    /// @dev only valid promises can call the function
    modifier onlyPromises() {
        if (!isValidPromise[msg.sender]) revert InvalidPromise();
        // remove promise once resolved
        isValidPromise[msg.sender] = false;
        _;
    }

    /// @notice Constructor for AppGatewayBase
    /// @param addressResolver_ The address resolver address
    constructor(address addressResolver_) {
        _setAddressResolver(addressResolver_);
        sbType = FAST;
    }

    /// @notice Sets the switchboard type
    /// @param sbType_ The switchboard type
    function _setSbType(bytes32 sbType_) internal {
        sbType = sbType_;
    }

    /// @notice Creates a contract ID
    /// @param contractName_ The contract name
    /// @return bytes32 The contract ID
    function _createContractId(string memory contractName_) internal pure returns (bytes32) {
        return keccak256(abi.encode(contractName_));
    }

    /// @notice Gets the current async ID
    /// @return bytes32 The current async ID
    function _getCurrentAsyncId() internal view returns (bytes32) {
        return deliveryHelper().getCurrentAsyncId();
    }

    /// @notice Sets the auction manager
    /// @param auctionManager_ The auction manager
    function _setAuctionManager(address auctionManager_) internal {
        auctionManager = auctionManager_;
    }

    /// @notice Marks the promises as valid
    function _markValidPromises() internal {
        address[] memory promises = addressResolver__.getPromises();
        for (uint256 i = 0; i < promises.length; i++) {
            isValidPromise[promises[i]] = true;
        }
    }

    /// @notice Gets the socket address
    /// @param chainSlug_ The chain slug
    /// @return socketAddress_ The socket address
    function getSocketAddress(uint32 chainSlug_) public view returns (address) {
        return watcherPrecompile__().sockets(chainSlug_);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////   DEPLOY HELPERS ///////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploys a contract
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    function _deploy(bytes32 contractId_, uint32 chainSlug_, IsPlug isPlug_) internal {
        _deploy(contractId_, chainSlug_, isPlug_, new bytes(0));
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
        address asyncPromise = addressResolver__.deployAsyncPromiseContract(address(this));
        isValidPromise[asyncPromise] = true;
        IPromise(asyncPromise).then(this.setAddress.selector, abi.encode(chainSlug_, contractId_));

        onCompleteData = abi.encode(chainSlug_, true);

        QueuePayloadParams memory queuePayloadParams = QueuePayloadParams({
            chainSlug: chainSlug_,
            callType: CallType.DEPLOY,
            isParallel: overrideParams.isParallelCall,
            isPlug: isPlug_,
            writeFinality: overrideParams.writeFinality,
            asyncPromise: asyncPromise,
            switchboard: address(0),
            target: address(0),
            appGateway: address(this),
            gasLimit: overrideParams.gasLimit,
            value: 0,
            readAt: overrideParams.readAt,
            payload: creationCodeWithArgs[contractId_],
            initCallData: initCallData_
        });
        IDeliveryHelper(deliveryHelper()).queue(queuePayloadParams);
    }

    /// @notice Sets the address for a deployed contract
    /// @param data_ The data
    /// @param returnData_ The return data
    function setAddress(bytes memory data_, bytes memory returnData_) external onlyPromises {
        (uint32 chainSlug, bytes32 contractId) = abi.decode(data_, (uint32, bytes32));

        address forwarderContractAddress = addressResolver__.getOrDeployForwarderContract(
            address(this),
            abi.decode(returnData_, (address)),
            chainSlug
        );

        forwarderAddresses[contractId][chainSlug] = forwarderContractAddress;
    }

    /// @notice Gets the on-chain address
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    /// @return onChainAddress The on-chain address
    function getOnChainAddress(
        bytes32 contractId_,
        uint32 chainSlug_
    ) public view returns (address onChainAddress) {
        if (forwarderAddresses[contractId_][chainSlug_] == address(0)) {
            return address(0);
        }

        onChainAddress = IForwarder(forwarderAddresses[contractId_][chainSlug_])
            .getOnChainAddress();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// TX OVERRIDE HELPERS ///////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Sets multiple overrides in one call
    /// @param isReadCall_ The read call flag
    /// @param fees_ The fees configuration
    /// @param gasLimit_ The gas limit
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(
        Read isReadCall_,
        Parallel isParallelCall_,
        uint256 gasLimit_,
        Fees memory fees_
    ) internal {
        overrideParams.isReadCall = isReadCall_;
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.gasLimit = gasLimit_;
        fees = fees_;
    }

    function _clearOverrides() internal {
        overrideParams.isReadCall = Read.OFF;
        overrideParams.isParallelCall = Parallel.OFF;
        overrideParams.gasLimit = 0;
        overrideParams.readAt = 0;
        overrideParams.writeFinality = WriteFinality.LOW;
    }

    /// @notice Sets isReadCall, fees and gasLimit overrides
    /// @param isReadCall_ The read call flag
    /// @param isParallelCall_ The sequential call flag
    /// @param gasLimit_ The gas limit
    function _setOverrides(Read isReadCall_, Parallel isParallelCall_, uint256 gasLimit_) internal {
        overrideParams.isReadCall = isReadCall_;
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.gasLimit = gasLimit_;
    }

    /// @notice Sets isReadCall and isParallelCall overrides
    /// @param isReadCall_ The read call flag
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(Read isReadCall_, Parallel isParallelCall_) internal {
        overrideParams.isReadCall = isReadCall_;
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
    /// @param readAt_ The read anchor value. Currently block number.
    function _setOverrides(Parallel isParallelCall_, uint256 readAt_) internal {
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.readAt = readAt_;
    }

    /// @notice Sets isReadCall overrides
    /// @param isReadCall_ The read call flag
    function _setOverrides(Read isReadCall_) internal {
        overrideParams.isReadCall = isReadCall_;
    }

    /// @notice Sets isReadCall overrides
    /// @param isReadCall_ The read call flag
    /// @param readAt_ The read anchor value. Currently block number.
    function _setOverrides(Read isReadCall_, uint256 readAt_) internal {
        overrideParams.isReadCall = isReadCall_;
        overrideParams.readAt = readAt_;
    }

    /// @notice Sets gasLimit overrides
    /// @param gasLimit_ The gas limit
    function _setOverrides(uint256 gasLimit_) internal {
        overrideParams.gasLimit = gasLimit_;
    }

    /// @notice Sets fees overrides
    /// @param fees_ The fees configuration
    function _setOverrides(Fees memory fees_) internal {
        fees = fees_;
    }

    function getOverrideParams()
        public
        view
        returns (Read, Parallel, WriteFinality, uint256, uint256)
    {
        return (
            overrideParams.isReadCall,
            overrideParams.isParallelCall,
            overrideParams.writeFinality,
            overrideParams.readAt,
            overrideParams.gasLimit
        );
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// ASYNC BATCH HELPERS /////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Reverts the transaction
    /// @param asyncId_ The async ID
    function _revertTx(bytes32 asyncId_) internal {
        deliveryHelper().cancelTransaction(asyncId_);
    }

    /// @notice increases the transaction fees
    /// @param asyncId_ The async ID
    function _increaseFees(bytes32 asyncId_, uint256 newMaxFees_) internal {
        deliveryHelper().increaseFees(asyncId_, newMaxFees_);
    }

    /// @notice Withdraws fee tokens
    /// @param chainSlug_ The chain slug
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function _withdrawFeeTokens(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) internal {
        deliveryHelper().withdrawTo(chainSlug_, token_, amount_, receiver_, auctionManager, fees);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// HOOKS /////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Callback in pd promise to be called after all contracts are deployed
    /// @param payloadRequest_ The payload batch
    /// @dev only payload delivery can call this
    /// @dev callback in pd promise to be called after all contracts are deployed
    function onRequestComplete(
        bytes32,
        PayloadRequest memory payloadRequest_
    ) external override onlyDeliveryHelper {
        if (payloadRequest_.onCompleteData.length == 0) return;

        (uint32 chainSlug, bool isDeploy) = abi.decode(
            payloadRequest_.onCompleteData,
            (uint32, bool)
        );
        if (isDeploy) {
            initialize(chainSlug);
        }
    }

    function callFromChain(
        uint32 chainSlug_,
        address plug_,
        bytes calldata payload_,
        bytes32 params_
    ) external virtual onlyWatcherPrecompile {}

    /// @notice Initializes the contract
    /// @param chainSlug_ The chain slug
    function initialize(uint32 chainSlug_) public virtual {}

    /// @notice hook to handle the revert in callbacks or onchain executions
    /// @dev can be overridden by the app gateway to add custom logic
    /// @param asyncId_ The async ID
    /// @param payloadId_ The payload ID
    function handleRevert(bytes32 asyncId_, bytes32 payloadId_) external override onlyPromises {}
}
