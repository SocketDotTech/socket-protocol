// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./QueueAsync.sol";

import {IAuctionHouse} from "../../../interfaces/IAuctionHouse.sol";
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
        uint256 auctionEndDelay
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
    /// @param auctionEndDelayMS_ The auction end delay in milliseconds
    /// @return asyncId The ID of the batch
    function batch(
        FeesData memory feesData_,
        address auctionManager_
    ) external returns (bytes32) {
        PayloadDetails[]
            memory payloadDetailsArray = createPayloadDetailsArray();

        // Default flow for other cases (including mixed read/write)
        return deliverPayload(payloadDetailsArray, feesData_, auctionManager_);
    }

    /// @notice Callback function for handling promises
    /// @param asyncId_ The ID of the batch
    /// @param payloadDetails_ The payload details
    function callback(
        bytes memory asyncId_,
        bytes memory payloadDetails_
    ) external virtual onlyPromises {}

    /// @notice Delivers a payload batch
    /// @param payloadDetails_ The payload details
    /// @param feesData_ The fees data
    /// @param auctionEndDelayMS_ The auction end delay in milliseconds
    /// @return asyncId The ID of the batch
    function deliverPayload(
        PayloadDetails[] memory payloadDetails_,
        FeesData memory feesData_,
        address auctionManager_
    ) internal returns (bytes32) {
        address forwarderAppGateway = msg.sender;
        bytes32 asyncId = getCurrentAsyncId();
        asyncCounter++;

        // Check for consecutive reads at the start
        uint256 readEndIndex = 0;
        while (
            readEndIndex < payloadDetails_.length &&
            payloadDetails_[readEndIndex].callType == CallType.READ
        ) {
            readEndIndex++;
        }

        // Process consecutive reads together if there are 1 or more
        if (readEndIndex >= 1) {
            // Create a batched read promise
            address batchPromise = IAddressResolver(addressResolver)
                .deployAsyncPromiseContract(address(this));
            isValidPromise[batchPromise] = true;

            // Process all reads in the batch
            for (uint256 i = 0; i < readEndIndex; i++) {
                bytes32 payloadId = watcherPrecompile().query(
                    payloadDetails_[i].chainSlug,
                    payloadDetails_[i].target,
                    [batchPromise, address(0)], // Use same promise for all reads in batch
                    payloadDetails_[i].payload
                );
                payloadIdToBatchHash[payloadId] = asyncId;

                emit PayloadAsyncRequested(
                    asyncId,
                    payloadId,
                    bytes32(0),
                    payloadDetails_[i]
                );
            }

            // Setup callback for the entire batch of reads
            IPromise(batchPromise).then(
                this.callback.selector,
                abi.encode(asyncId)
            );
        }

        if (readEndIndex == payloadDetails_.length) {
            return asyncId;
        }

        // Process remaining payloads normally
        for (uint256 i = readEndIndex; i < payloadDetails_.length; i++) {
            if (payloadDetails_[i].payload.length > 24.5 * 1024)
                revert PayloadTooLarge();

            // Rest of the existing deliverPayload logic for each payload
            if (payloadDetails_[i].callType == CallType.DEPLOY) {
                // considering contract factory as plug of delivery helper
                payloadDetails_[i].target = getPlugAddress(
                    address(this),
                    payloadDetails_[i].chainSlug
                );
            } else if (payloadDetails_[i].callType == CallType.WRITE) {
                // todo: if need to remove this
                forwarderAppGateway = IAddressResolver(addressResolver)
                    .contractsToGateways(msg.sender);

                if (forwarderAppGateway == address(0))
                    forwarderAppGateway = msg.sender;
            }

            payloadDetails_[i].next[1] = IAddressResolver(addressResolver)
                .deployAsyncPromiseContract(address(this));

            isValidPromise[payloadDetails_[i].next[1]] = true;
            IPromise(payloadDetails_[i].next[1]).then(
                this.callback.selector,
                abi.encode(asyncId)
            );

            payloadBatchDetails[asyncId].push(payloadDetails_[i]);
        }

        payloadBatches[asyncId] = PayloadBatch({
            appGateway: forwarderAppGateway,
            feesData: feesData_,
            currentPayloadIndex: readEndIndex,
            auctionManager: auctionManager_,
            winningBid: Bid({
                fee: 0,
                transmitter: address(0),
                extraData: new bytes(0)
            }),
            isBatchCancelled: false,
            totalPayloadsRemaining: payloadDetails_.length - readEndIndex
        });

        IAuctionManager(auctionManager_).startAuction(asyncId);
        emit PayloadSubmitted(
            asyncId,
            forwarderAppGateway,
            payloadDetails_,
            feesData_,
            auctionManager_
        );
        return asyncId;
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
    function getPlugAddress(
        address appGateway_,
        uint32 chainSlug_
    ) public view returns (address) {
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
        deliverPayload(payloadDetailsArray, feesData_, 0);
    }
}
