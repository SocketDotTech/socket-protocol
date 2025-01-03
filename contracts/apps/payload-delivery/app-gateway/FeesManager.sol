// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "../../../utils/Ownable.sol";
import {SignatureVerifier} from "../../../socket/utils/SignatureVerifier.sol";
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {Bid, FeesData, PayloadDetails, CallType, FinalizeParams} from "../../../common/Structs.sol";
import {IAuctionContract} from "../../../interfaces/IAuctionContract.sol";
import {IAuctionHouse} from "../../../interfaces/IAuctionHouse.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW} from "../../../common/Constants.sol";
import {IFeesPlug} from "../../../interfaces/IFeesPlug.sol";

/// @title AuctionHouse
/// @notice Contract for managing auctions and placing bids
contract FeesManager is AddressResolverUtil, Ownable(msg.sender) {
    uint256 public feesCounter;
    mapping(uint32 => uint256) public feeCollectionGasLimit;

    /// @notice Constructor for AuctionHouse
    /// @param addressResolver_ The address of the address resolver
    constructor(
        address addressResolver_
    ) AddressResolverUtil(addressResolver_) {}
    function distributeFees(
        address appGateway_,
        FeesData memory feesData_,
        Bid memory winningBid_
    ) external returns (bytes32 payloadId, bytes32 root) {
        bytes32 feesId = _encodeFeesId(feesCounter++);
        // Create payload for pool contract
        bytes memory payload = abi.encodeCall(
            IFeesPlug.distributeFee,
            (
                appGateway_,
                feesData_.feePoolToken,
                winningBid_.fee,
                winningBid_.transmitter,
                feesId
            )
        );

        PayloadDetails memory payloadDetails = PayloadDetails({
            chainSlug: feesData_.feePoolChain,
            target: _getFeesPlugAddress(feesData_.feePoolChain),
            payload: payload,
            callType: CallType.WRITE,
            executionGasLimit: feeCollectionGasLimit[feesData_.feePoolChain],
            next: new address[](0)
        });

        FinalizeParams memory finalizeParams = FinalizeParams({
            payloadDetails: payloadDetails,
            transmitter: winningBid_.transmitter
        });

        return watcherPrecompile().finalize(finalizeParams);
    }

    /// @notice Withdraws funds to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param receiver_ The address of the receiver
    function getWithdrawToPayload(
        address appGateway_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) public view returns (PayloadDetails memory) {
        // Create payload for pool contract
        bytes memory payload = abi.encodeCall(
            IFeesPlug.withdrawFees,
            (appGateway_, token_, amount_, receiver_)
        );

        return
            PayloadDetails({
                chainSlug: chainSlug_,
                target: _getFeesPlugAddress(chainSlug_),
                payload: payload,
                callType: CallType.WITHDRAW,
                executionGasLimit: feeCollectionGasLimit[chainSlug_],
                next: new address[](0)
            });
    }

    function _encodeFeesId(
        uint256 feesCounter_
    ) internal view returns (bytes32) {
        // watcher address (160 bits) | counter (64 bits)
        return bytes32((uint256(uint160(address(this))) << 64) | feesCounter_);
    }

    function _getFeesPlugAddress(
        uint32 chainSlug_
    ) internal view returns (address) {
        return watcherPrecompile().appGatewayPlugs(address(this), chainSlug_);
    }
}
