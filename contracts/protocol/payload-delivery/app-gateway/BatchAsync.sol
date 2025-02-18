// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./QueueAsync.sol";

import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {IAuctionManager} from "../../../interfaces/IAuctionManager.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";

import {Bid, PayloadBatch, Fees, PayloadDetails} from "../../../protocol/utils/common/Structs.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW, QUERY, FINALIZE} from "../../../protocol/utils/common/Constants.sol";

/// @title BatchAsync
/// @notice Abstract contract for managing asynchronous payload batches
abstract contract BatchAsync is QueueAsync {
    /// @notice Error thrown when attempting to executed payloads after all have been executed
    error AllPayloadsExecuted();
    /// @notice Error thrown request did not come from Forwarder address
    error NotFromForwarder();
    /// @notice Error thrown when a payload call fails
    error CallFailed(bytes32 payloadId);
    /// @notice Error thrown if payload is too large
    error PayloadTooLarge();
    /// @notice Error thrown if trying to cancel a batch without being the application gateway
    error OnlyAppGateway();
    /// @notice Error thrown when a winning bid exists
    error WinningBidExists();
    /// @notice Error thrown when a bid is insufficient
    error InsufficientFees();

    event PayloadSubmitted(
        bytes32 indexed asyncId,
        address indexed appGateway,
        PayloadDetails[] payloads,
        Fees fees,
        address auctionManager
    );

    /// @notice Emitted when fees are increased
    event FeesIncreased(address indexed appGateway, bytes32 indexed asyncId, uint256 newMaxFees);

    /// @notice Emitted when a payload is requested asynchronously
    event PayloadAsyncRequested(
        bytes32 indexed asyncId,
        bytes32 indexed payloadId,
        bytes32 indexed root,
        PayloadDetails payloadDetails
    );

    /// @notice Emitted when a batch is cancelled
    event BatchCancelled(bytes32 indexed asyncId);

    /// @notice Initiates a batch of payloads
    /// @param fees_ The fees data
    /// @param auctionManager_ The auction manager address
    /// @return asyncId The ID of the batch
    function batch(
        Fees memory fees_,
        address auctionManager_,
        bytes memory onCompleteData_,
        bytes32 sbType_
    ) external returns (bytes32) {
        PayloadDetails[] memory payloadDetailsArray = _createPayloadDetailsArray(sbType_);

        if (payloadDetailsArray.length == 0) {
            return bytes32(0);
        }

        // Default flow for other cases (including mixed read/write)
        return _deliverPayload(payloadDetailsArray, fees_, auctionManager_, onCompleteData_);
    }

    /// @notice Callback function for handling promises
    /// @param asyncId_ The ID of the batch
    /// @param payloadDetails_ The payload details
    function callback(bytes memory asyncId_, bytes memory payloadDetails_) external virtual {}

    /// @notice Delivers a payload batch
    /// @param payloadDetails_ The payload details
    /// @param fees_ The fees data
    /// @param auctionManager_ The auction manager address
    /// @return asyncId The ID of the batch
    function _deliverPayload(
        PayloadDetails[] memory payloadDetails_,
        Fees memory fees_,
        address auctionManager_,
        bytes memory onCompleteData_
    ) internal returns (bytes32) {
        bytes32 asyncId = getCurrentAsyncId();
        asyncCounter++;


        if (!IFeesManager(addressResolver__.feesManager()).isFeesEnough(msg.sender, fees_))
            revert InsufficientFees();

        // Handle initial read operations first
        uint256 readEndIndex = _processReadOperations(payloadDetails_, asyncId);

        watcherPrecompile__().checkAndUpdateLimit(
            payloadDetails_[0].appGateway,
            QUERY,
            readEndIndex
        );

        // If only reads, return early
        if (readEndIndex == payloadDetails_.length) {
            return asyncId;
        }

        address appGateway = _processRemainingPayloads(payloadDetails_, readEndIndex, asyncId);
        _payloadBatches[asyncId].totalPayloadsRemaining = payloadDetails_.length - readEndIndex;

        _initializeBatch(
            asyncId,
            appGateway,
            fees_,
            auctionManager_,
            onCompleteData_,
            readEndIndex,
            payloadDetails_
        );

        return asyncId;
    }

    function _processReadOperations(
        PayloadDetails[] memory payloadDetails_,
        bytes32 asyncId
    ) internal returns (uint256) {
        uint256 readEndIndex = 0;

        // Find the end of parallel reads
        while (
            readEndIndex < payloadDetails_.length &&
            payloadDetails_[readEndIndex].callType == CallType.READ &&
            payloadDetails_[readEndIndex].isParallel == Parallel.ON
        ) {
            readEndIndex++;
        }

        // If we have parallel reads, process them as a batch
        if (readEndIndex > 0) {
            address[] memory lastBatchPromises = new address[](readEndIndex);
            address batchPromise = IAddressResolver(addressResolver__).deployAsyncPromiseContract(
                address(this)
            );
            isValidPromise[batchPromise] = true;

            for (uint256 i = 0; i < readEndIndex; i++) {
                payloadDetails_[i].next[1] = batchPromise;
                lastBatchPromises[i] = payloadDetails_[i].next[0];

                bytes32 payloadId = watcherPrecompile__().query(
                    payloadDetails_[i].chainSlug,
                    payloadDetails_[i].target,
                    payloadDetails_[i].appGateway,
                    payloadDetails_[i].next,
                    payloadDetails_[i].payload
                );
                payloadIdToBatchHash[payloadId] = asyncId;
                payloadBatchDetails[asyncId].push(payloadDetails_[i]);
                emit PayloadAsyncRequested(asyncId, payloadId, bytes32(0), payloadDetails_[i]);
            }

            _payloadBatches[asyncId].lastBatchPromises = lastBatchPromises;
            IPromise(batchPromise).then(this.callback.selector, abi.encode(asyncId));
        }

        return readEndIndex;
    }

    function _processRemainingPayloads(
        PayloadDetails[] memory payloadDetails_,
        uint256 readEndIndex,
        bytes32 asyncId
    ) internal returns (address) {
        address appGateway = msg.sender;

        uint256 writes = 0;
        for (uint256 i = readEndIndex; i < payloadDetails_.length; i++) {
            if (payloadDetails_[i].payload.length > 24.5 * 1024) revert PayloadTooLarge();

            if (payloadDetails_[i].callType == CallType.DEPLOY) {
                // contract factory plug deploys new contracts
                payloadDetails_[i].target = getDeliveryHelperPlugAddress(
                    address(this),
                    payloadDetails_[i].chainSlug
                );
                writes++;
            } else if (payloadDetails_[i].callType == CallType.WRITE) {
                appGateway = _getCoreAppGateway(appGateway);
                payloadDetails_[i].appGateway = appGateway;
                writes++;
            }

            payloadBatchDetails[asyncId].push(payloadDetails_[i]);
        }

        watcherPrecompile__().checkAndUpdateLimit(
            appGateway,
            QUERY,
            // remaining reads
            payloadDetails_.length - writes - readEndIndex
        );
        watcherPrecompile__().checkAndUpdateLimit(appGateway, FINALIZE, writes);

        return appGateway;
    }

    function _initializeBatch(
        bytes32 asyncId,
        address appGateway,
        Fees memory fees_,
        address auctionManager_,
        bytes memory onCompleteData_,
        uint256 readEndIndex,
        PayloadDetails[] memory payloadDetails_
    ) internal {
        _payloadBatches[asyncId] = PayloadBatch({
            appGateway: appGateway,
            fees: fees_,
            currentPayloadIndex: readEndIndex,
            auctionManager: auctionManager_,
            winningBid: Bid({fee: 0, transmitter: address(0), extraData: new bytes(0)}),
            isBatchCancelled: false,
            totalPayloadsRemaining: _payloadBatches[asyncId].totalPayloadsRemaining,
            lastBatchPromises: _payloadBatches[asyncId].lastBatchPromises,
            onCompleteData: onCompleteData_
        });

        emit PayloadSubmitted(asyncId, appGateway, payloadDetails_, fees_, auctionManager_);
    }

    function endTimeout(bytes32 asyncId_) external onlyWatcherPrecompile {
        IAuctionManager(_payloadBatches[asyncId_].auctionManager).endAuction(asyncId_);
    }

    /// @notice Cancels a transaction
    /// @param asyncId_ The ID of the batch
    function cancelTransaction(bytes32 asyncId_) external {
        if (msg.sender != _payloadBatches[asyncId_].appGateway) {
            revert OnlyAppGateway();
        }

        _payloadBatches[asyncId_].isBatchCancelled = true;

        if (_payloadBatches[asyncId_].winningBid.transmitter != address(0)) {
            IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
                asyncId_,
                _payloadBatches[asyncId_].winningBid.transmitter,
                _payloadBatches[asyncId_].appGateway
            );
        } else {
            IFeesManager(addressResolver__.feesManager()).unblockFees(
                asyncId_,
                _payloadBatches[asyncId_].appGateway
            );
        }

        emit BatchCancelled(asyncId_);
    }

    function increaseFees(bytes32 asyncId_, uint256 newMaxFees_) external override {
        address appGateway = _getCoreAppGateway(msg.sender);
        if (appGateway != _payloadBatches[asyncId_].appGateway) {
            revert OnlyAppGateway();
        }

        if (_payloadBatches[asyncId_].winningBid.transmitter != address(0))
            revert WinningBidExists();

        _payloadBatches[asyncId_].fees.amount = newMaxFees_;
        emit FeesIncreased(appGateway, asyncId_, newMaxFees_);
    }

    /// @notice Gets the payload delivery plug address
    /// @param chainSlug_ The chain identifier
    /// @return address The address of the payload delivery plug
    function getDeliveryHelperPlugAddress(
        address appGateway_,
        uint32 chainSlug_
    ) public view returns (address) {
        return watcherPrecompile__().appGatewayPlugs(appGateway_, chainSlug_);
    }

    /// @notice Gets the current async ID
    /// @return bytes32 The current async ID
    function getCurrentAsyncId() public view returns (bytes32) {
        return bytes32((uint256(uint160(address(this))) << 64) | asyncCounter);
    }

    /// @notice Withdraws funds to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param receiver_ The address of the receiver
    /// @param fees_ The fees data
    function withdrawTo(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_,
        address auctionManager_,
        Fees memory fees_
    ) external {
        PayloadDetails[] memory payloadDetailsArray = new PayloadDetails[](1);
        payloadDetailsArray[0] = IFeesManager(addressResolver__.feesManager()).getWithdrawToPayload(
            msg.sender,
            chainSlug_,
            token_,
            amount_,
            receiver_
        );
        _deliverPayload(payloadDetailsArray, fees_, auctionManager_, new bytes(0));
    }
}
