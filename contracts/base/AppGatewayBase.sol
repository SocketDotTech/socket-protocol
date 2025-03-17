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
    Read public override isReadCall;
    Parallel public override isParallelCall;
    uint256 public override gasLimit;

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

    /// @notice Sets the validity of an onchain contract (plug) to authorize it to send information to a specific AppGateway
    /// @param chainSlug_ The unique identifier of the chain where the contract resides
    /// @param contractId The bytes32 identifier of the contract to be validated
    /// @param isValid Boolean flag indicating whether the contract is authorized (true) or not (false)
    /// @dev This function retrieves the onchain address using the contractId and chainSlug, then calls the watcher precompile to update the plug's validity status
    function _setValidPlug(uint32 chainSlug_, bytes32 contractId, bool isValid) internal {
        address onchainAddress = getOnChainAddress(contractId, chainSlug_);
        watcherPrecompile__().setIsValidPlug(chainSlug_, onchainAddress, isValid);
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
        IDeliveryHelper(deliveryHelper()).queue(
            isPlug_,
            isParallelCall,
            chainSlug_,
            address(0),
            asyncPromise,
            0,
            CallType.DEPLOY,
            creationCodeWithArgs[contractId_],
            initCallData_
        );
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
        isReadCall = isReadCall_;
        isParallelCall = isParallelCall_;
        gasLimit = gasLimit_;
        fees = fees_;
    }

    /// @notice Sets isReadCall, fees and gasLimit overrides
    /// @param isReadCall_ The read call flag
    /// @param isParallelCall_ The sequential call flag
    /// @param gasLimit_ The gas limit
    function _setOverrides(Read isReadCall_, Parallel isParallelCall_, uint256 gasLimit_) internal {
        isReadCall = isReadCall_;
        isParallelCall = isParallelCall_;
        gasLimit = gasLimit_;
    }

    /// @notice Sets isReadCall and isParallelCall overrides
    /// @param isReadCall_ The read call flag
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(Read isReadCall_, Parallel isParallelCall_) internal {
        isReadCall = isReadCall_;
        isParallelCall = isParallelCall_;
    }

    /// @notice Sets isParallelCall overrides
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(Parallel isParallelCall_) internal {
        isParallelCall = isParallelCall_;
    }

    /// @notice Sets isReadCall overrides
    /// @param isReadCall_ The read call flag
    function _setOverrides(Read isReadCall_) internal {
        isReadCall = isReadCall_;
    }

    /// @notice Sets gasLimit overrides
    /// @param gasLimit_ The gas limit
    function _setOverrides(uint256 gasLimit_) internal {
        gasLimit = gasLimit_;
    }

    /// @notice Sets fees overrides
    /// @param fees_ The fees configuration
    function _setOverrides(Fees memory fees_) internal {
        fees = fees_;
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
    /// @param payloadBatch_ The payload batch
    /// @dev only payload delivery can call this
    /// @dev callback in pd promise to be called after all contracts are deployed
    function onBatchComplete(
        bytes32,
        PayloadBatch memory payloadBatch_
    ) external override onlyDeliveryHelper {
        if (payloadBatch_.onCompleteData.length == 0) return;

        (uint32 chainSlug, bool isDeploy) = abi.decode(
            payloadBatch_.onCompleteData,
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
