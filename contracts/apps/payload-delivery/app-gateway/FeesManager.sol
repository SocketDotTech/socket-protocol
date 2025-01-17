// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "../../../utils/Ownable.sol";
import {SignatureVerifier} from "../../../socket/utils/SignatureVerifier.sol";
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {Bid, FeesData, PayloadDetails, CallType, FinalizeParams} from "../../../common/Structs.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW} from "../../../common/Constants.sol";
import {IFeesPlug} from "../../../interfaces/IFeesPlug.sol";

/// @title FeesManager
/// @notice Contract for managing fees
contract FeesManager is AddressResolverUtil, Ownable {
    uint256 public feesCounter;
    mapping(uint32 => uint256) public feeCollectionGasLimit;

    /// @notice Constructor for FeesManager
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the owner
    constructor(
        address addressResolver_,
        address owner_
    ) AddressResolverUtil(addressResolver_) Ownable(owner_) {}

    function distributeFees(
        address appGateway_,
        FeesData memory feesData_,
        Bid memory winningBid_
    )
        external
        onlyDeliveryHelper
        returns (bytes32 payloadId, bytes32 root, PayloadDetails memory payloadDetails)
    {
        bytes32 feesId = _encodeFeesId(feesCounter++);

        address appGateway = _getCoreAppGateway(appGateway_);
        // Create payload for pool contract
        bytes memory payload = abi.encodeCall(
            IFeesPlug.distributeFee,
            (appGateway, feesData_.feePoolToken, winningBid_.fee, winningBid_.transmitter, feesId)
        );

        payloadDetails = PayloadDetails({
            appGateway: address(this),
            chainSlug: feesData_.feePoolChain,
            target: _getFeesPlugAddress(feesData_.feePoolChain),
            payload: payload,
            callType: CallType.WRITE,
            executionGasLimit: 1000000,
            next: new address[](0),
            isSequential: true
        });

        FinalizeParams memory finalizeParams = FinalizeParams({
            payloadDetails: payloadDetails,
            transmitter: winningBid_.transmitter
        });

        (payloadId, root) = watcherPrecompile().finalize(finalizeParams, appGateway);
        return (payloadId, root, payloadDetails);
    }

    /// @notice Withdraws funds to a specified receiver
    /// @dev This function is used to withdraw fees from the fees plug
    /// @param appGateway_ The address of the app gateway
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
        address appGateway = _getCoreAppGateway(appGateway_);
        // Create payload for pool contract
        bytes memory payload = abi.encodeCall(
            IFeesPlug.withdrawFees,
            (appGateway, token_, amount_, receiver_)
        );

        return
            PayloadDetails({
                appGateway: address(this),
                chainSlug: chainSlug_,
                target: _getFeesPlugAddress(chainSlug_),
                payload: payload,
                callType: CallType.WITHDRAW,
                executionGasLimit: 1000000,
                next: new address[](2),
                isSequential: true
            });
    }

    function _encodeFeesId(uint256 feesCounter_) internal view returns (bytes32) {
        // watcher address (160 bits) | counter (64 bits)
        return bytes32((uint256(uint160(address(this))) << 64) | feesCounter_);
    }

    function _getFeesPlugAddress(uint32 chainSlug_) internal view returns (address) {
        return watcherPrecompile().appGatewayPlugs(address(this), chainSlug_);
    }
}
