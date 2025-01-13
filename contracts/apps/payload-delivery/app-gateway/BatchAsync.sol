// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./QueueAsync.sol";

import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {IAuctionManager} from "../../../interfaces/IAuctionManager.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";

import {Bid, PayloadBatch, FeesData, PayloadDetails} from "../../../common/Structs.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW} from "../../../common/Constants.sol";

/// @title BatchAsync
/// @notice Abstract contract for managing asynchronous payload batches
abstract contract BatchAsync is QueueAsync {
    error AllPayloadsExecuted();
    error NotFromForwarder();
    error CallFailed(bytes32 payloadId);
    error PayloadTooLarge();
    event PayloadSubmitted(
        bytes32 indexed asyncId,
        address indexed appGateway,
        PayloadDetails[] payloads,
        FeesData feesData,
        address auctionManager
    );

    event PayloadAsyncRequested(
        bytes32 indexed asyncId,
        bytes32 indexed payloadId,
        bytes32 indexed root,
        PayloadDetails payloadDetails
    );
    event BatchCancelled(bytes32 indexed asyncId);

    /// @notice Initiates a batch of payloads
    /// @param feesData_ The fees data
    /// @param auctionManager_ The auction manager address
    /// @return asyncId The ID of the batch
    function batch(
        FeesData memory feesData_,
        address auctionManager_,
        bytes memory onCompleteData_,
        bytes32 sbType_
    ) external returns (bytes32) {
        PayloadDetails[] memory payloadDetailsArray = createPayloadDetailsArray(sbType_);

        if (payloadDetailsArray.length == 0) {
            return bytes32(0);
        }

        // Default flow for other cases (including mixed read/write)
        return deliverPayload(payloadDetailsArray, feesData_, auctionManager_, onCompleteData_);
    }

    /// @notice Callback function for handling promises
    /// @param asyncId_ The ID of the batch
    /// @param payloadDetails_ The payload details
    function callback(bytes memory asyncId_, bytes memory payloadDetails_) external virtual {}

    /// @notice Delivers a payload batch
    /// @param payloadDetails_ The payload details
    /// @param feesData_ The fees data
    /// @param auctionManager_ The auction manager address
    /// @return asyncId The ID of the batch
    function deliverPayload(
        PayloadDetails[] memory payloadDetails_,
        FeesData memory feesData_,
        address auctionManager_,
        bytes memory onCompleteData_
    ) internal returns (bytes32) {
        bytes32 asyncId = getCurrentAsyncId();
        asyncCounter++;

        // Handle initial read operations first
        uint256 readEndIndex = processReadOperations(payloadDetails_, asyncId);

        // If only reads, return early
        if (readEndIndex == payloadDetails_.length) {
            return asyncId;
        }

        address appGateway = processRemainingPayloads(payloadDetails_, readEndIndex, asyncId);

        initializeBatch(
            asyncId,
            appGateway,
            feesData_,
            auctionManager_,
            onCompleteData_,
            readEndIndex,
            payloadDetails_
        );

        return asyncId;
    }

    function processReadOperations(
        PayloadDetails[] memory payloadDetails_,
        bytes32 asyncId
    ) internal returns (uint256) {
        uint256 readEndIndex = 0;
        while (
            readEndIndex < payloadDetails_.length &&
            payloadDetails_[readEndIndex].callType == CallType.READ
        ) {
            readEndIndex++;
        }

        if (readEndIndex > 0) {
            address[] memory lastBatchPromises = new address[](readEndIndex);
            address batchPromise = IAddressResolver(addressResolver).deployAsyncPromiseContract(
                address(this)
            );
            isValidPromise[batchPromise] = true;

            for (uint256 i = 0; i < readEndIndex; i++) {
                payloadDetails_[i].next[1] = batchPromise;
                lastBatchPromises[i] = payloadDetails_[i].next[0];

                bytes32 payloadId = watcherPrecompile().query(
                    payloadDetails_[i].chainSlug,
                    payloadDetails_[i].target,
                    payloadDetails_[i].appGateway,
                    payloadDetails_[i].next,
                    payloadDetails_[i].payload
                );
                payloadIdToBatchHash[payloadId] = asyncId;
                emit PayloadAsyncRequested(asyncId, payloadId, bytes32(0), payloadDetails_[i]);
            }

            IPromise(batchPromise).then(this.callback.selector, abi.encode(asyncId));
        }

        return readEndIndex;
    }

    function processRemainingPayloads(
        PayloadDetails[] memory payloadDetails_,
        uint256 readEndIndex,
        bytes32 asyncId
    ) internal returns (address) {
        address appGateway = msg.sender;

        for (uint256 i = readEndIndex; i < payloadDetails_.length; i++) {
            if (payloadDetails_[i].payload.length > 24.5 * 1024) revert PayloadTooLarge();

            if (payloadDetails_[i].callType == CallType.DEPLOY) {
                // contract factory plug deploys new contracts
                payloadDetails_[i].target = getPlugAddress(
                    address(this),
                    payloadDetails_[i].chainSlug
                );
            } else if (payloadDetails_[i].callType == CallType.WRITE) {
                appGateway = _getCoreAppGateway(appGateway);
                payloadDetails_[i].appGateway = appGateway;
            }
            payloadBatchDetails[asyncId].push(payloadDetails_[i]);
        }

        return appGateway;
    }

    function initializeBatch(
        bytes32 asyncId,
        address appGateway,
        FeesData memory feesData_,
        address auctionManager_,
        bytes memory onCompleteData_,
        uint256 readEndIndex,
        PayloadDetails[] memory payloadDetails_
    ) internal {
        payloadBatches[asyncId] = PayloadBatch({
            appGateway: appGateway,
            feesData: feesData_,
            currentPayloadIndex: readEndIndex,
            auctionManager: auctionManager_,
            winningBid: Bid({fee: 0, transmitter: address(0), extraData: new bytes(0)}),
            isBatchCancelled: false,
            totalPayloadsRemaining: payloadDetails_.length - readEndIndex,
            lastBatchPromises: new address[](readEndIndex),
            onCompleteData: onCompleteData_
        });

        uint256 delayInSeconds = IAuctionManager(auctionManager_).startAuction(asyncId);
        watcherPrecompile().setTimeout(
            appGateway,
            abi.encodeWithSelector(this.endTimeout.selector, asyncId),
            delayInSeconds
        );

        emit PayloadSubmitted(asyncId, appGateway, payloadDetails_, feesData_, auctionManager_);
    }

    function endTimeout(bytes32 asyncId_) external onlyWatcherPrecompile {
        IAuctionManager(payloadBatches[asyncId_].auctionManager).endAuction(asyncId_);
    }

    /// @notice Cancels a transaction
    /// @param asyncId_ The ID of the batch
    function cancelTransaction(bytes32 asyncId_) external {
        if (msg.sender != payloadBatches[asyncId_].appGateway)
            revert("Only app gateway can cancel batch");

        payloadBatches[asyncId_].isBatchCancelled = true;
        emit BatchCancelled(asyncId_);
    }

    /// @notice Gets the payload delivery plug address
    /// @param chainSlug_ The chain identifier
    /// @return address The address of the payload delivery plug
    function getPlugAddress(address appGateway_, uint32 chainSlug_) public view returns (address) {
        return watcherPrecompile().appGatewayPlugs(appGateway_, chainSlug_);
    }

    /// @notice Gets the current async ID
    /// @return bytes32 The current async ID
    function getCurrentAsyncId() public view returns (bytes32) {
        return bytes32((uint256(uint160(address(this))) << 64) | asyncCounter);
    }

    /// @notice Gets the payload details for a given index
    /// @param asyncId_ The ID of the batch
    /// @param index_ The index of the payload
    /// @return PayloadDetails The payload details
    function getPayloadDetails(
        bytes32 asyncId_,
        uint256 index_
    ) external view returns (PayloadDetails memory) {
        return payloadBatchDetails[asyncId_][index_];
    }

    /// @notice Withdraws funds to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param receiver_ The address of the receiver
    /// @param feesData_ The fees data
    function withdrawTo(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_,
        address auctionManager_,
        FeesData memory feesData_
    ) external {
        PayloadDetails[] memory payloadDetailsArray = new PayloadDetails[](1);
        payloadDetailsArray[0] = IFeesManager(feesManager).getWithdrawToPayload(
            msg.sender,
            chainSlug_,
            token_,
            amount_,
            receiver_
        );
        deliverPayload(payloadDetailsArray, feesData_, auctionManager_, new bytes(0));
    }
}
