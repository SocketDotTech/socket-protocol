// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../protocol/utils/AddressResolverUtil.sol";
import "../interfaces/IDeliveryHelper.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IPromise.sol";
import {Fees, Read, Parallel} from "../protocol/utils/common/Structs.sol";
import {FeesPlugin} from "../protocol/utils/FeesPlugin.sol";
import {InvalidPromise, FeesNotSet} from "../protocol/utils/common/Errors.sol";

/// @title AppGatewayBase
/// @notice Abstract contract for the app gateway
abstract contract AppGatewayBase is AddressResolverUtil, IAppGateway, FeesPlugin {
    Read public override isReadCall;
    Parallel public override isParallelCall;
    uint256 public override gasLimit;

    address public auctionManager;
    bytes public onCompleteData;
    bytes32 public sbType;

    mapping(address => bool) public isValidPromise;

    /// @notice Modifier to treat functions async
    modifier async() {
        if (fees.feePoolChain == 0) revert FeesNotSet();
        deliveryHelper().clearQueue();
        addressResolver__.clearPromises();
        _;
        deliveryHelper().batch(fees, auctionManager, onCompleteData, sbType);
        _markValidPromises();
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
    constructor(address addressResolver_, address auctionManager_) {
        _setAddressResolver(addressResolver_);
        auctionManager = auctionManager_;
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
    /// @param asyncId_ The async ID
    /// @param payloadBatch_ The payload batch
    function onBatchComplete(
        bytes32 asyncId_,
        PayloadBatch memory payloadBatch_
    ) external virtual onlyDeliveryHelper {}

    function callFromInbox(
        uint32 chainSlug_,
        address plug_,
        bytes calldata payload_,
        bytes32 params_
    ) external virtual onlyWatcherPrecompile {}

    /// @notice hook to handle the revert in callbacks or onchain executions
    /// @dev can be overridden by the app gateway to add custom logic
    /// @param asyncId_ The async ID
    /// @param payloadId_ The payload ID
    function handleRevert(bytes32 asyncId_, bytes32 payloadId_) external override onlyPromises {}
}
