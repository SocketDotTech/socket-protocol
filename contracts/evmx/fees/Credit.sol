// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";
import "solady/utils/ECDSA.sol";
import "../interfaces/IFeesManager.sol";
import "../interfaces/IFeesPlug.sol";
import "../watcher/WatcherBase.sol";
import {AddressResolverUtil} from "../helpers/AddressResolverUtil.sol";
import {NonceUsed, InvalidAmount, InsufficientCreditsAvailable, InsufficientBalance} from "../../utils/common/Errors.sol";
import {WriteFinality, UserCredits, AppGatewayApprovals, OverrideParams} from "../../utils/common/Structs.sol";
import {WRITE} from "../../utils/common/Constants.sol";

abstract contract FeesManagerStorage is IFeesManager, WatcherBase {
    /// @notice evmx slug
    uint32 public evmxSlug;

    /// @notice user credits => stores fees for user, app gateway, transmitters and watcher precompile
    mapping(address => UserCredits) public userCredits;

    /// @notice Mapping to track request credits details for each request count
    /// @dev requestCount => RequestFee
    mapping(uint40 => uint256) public requestBlockedCredits;

    // user approved app gateways
    // userAddress => appGateway => isApproved
    mapping(address => mapping(address => bool)) public isApproved;

    // token pool balances
    //  chainSlug => token address => amount
    mapping(uint32 => mapping(address => uint256)) public tokenOnChainBalances;

    /// @notice Mapping to track nonce to whether it has been used
    /// @dev address => signatureNonce => isNonceUsed
    /// @dev used by watchers or other users in signatures
    mapping(address => mapping(uint256 => bool)) public isNonceUsed;
}

/// @title UserUtils
/// @notice Contract for managing user utils
abstract contract Credit is FeesManagerStorage, Initializable, Ownable, AddressResolverUtil {
    /// @notice Emitted when fees deposited are updated
    /// @param chainSlug The chain identifier
    /// @param appGateway The app gateway address
    /// @param token The token address
    /// @param amount The new amount deposited
    event CreditsDeposited(
        uint32 indexed chainSlug,
        address indexed appGateway,
        address indexed token,
        uint256 amount
    );

    /// @notice Emitted when credits are wrapped
    event CreditsWrapped(address indexed consumeFrom, uint256 amount);

    /// @notice Emitted when credits are unwrapped
    event CreditsUnwrapped(address indexed consumeFrom, uint256 amount);

    /// @notice Emitted when credits are transferred
    event CreditsTransferred(address indexed from, address indexed to, uint256 amount);

    /// @notice Deposits credits and native tokens to a user
    /// @param depositTo_ The address to deposit the credits to
    /// @param chainSlug_ The chain slug
    /// @param token_ The token address
    /// @param nativeAmount_ The native amount
    /// @param creditAmount_ The credit amount
    function deposit(
        address depositTo_,
        uint32 chainSlug_,
        address token_,
        uint256 nativeAmount_,
        uint256 creditAmount_
    ) external payable onlyWatcher {
        if (creditAmount_ + nativeAmount_ != msg.value) revert InvalidAmount();
        tokenOnChainBalances[chainSlug_][token_] += nativeAmount_ + creditAmount_;

        UserCredits storage userCredit = userCredits[depositTo_];
        userCredit.totalCredits += creditAmount_;
        payable(depositTo_).transfer(nativeAmount_);

        emit CreditsDeposited(chainSlug_, depositTo_, token_, creditAmount_);
    }

    // todo: add safe eth transfer
    function wrap(address receiver_) external payable {
        UserCredits storage userCredit = userCredits[receiver_];
        userCredit.totalCredits += msg.value;
        emit CreditsWrapped(receiver_, msg.value);
    }

    function unwrap(uint256 amount_, address receiver_) external {
        UserCredits storage userCredit = userCredits[msg.sender];
        if (userCredit.totalCredits < amount_) revert InsufficientCreditsAvailable();
        userCredit.totalCredits -= amount_;

        if (address(this).balance < amount_) revert InsufficientBalance();
        payable(receiver_).transfer(amount_);

        emit CreditsUnwrapped(receiver_, amount_);
    }

    /// @notice Returns available (unblocked) credits for a gateway
    /// @param consumeFrom_ The app gateway address
    /// @return The available credit amount
    function getAvailableCredits(address consumeFrom_) public view returns (uint256) {
        UserCredits memory userCredit = userCredits[consumeFrom_];
        return userCredit.totalCredits - userCredit.blockedCredits;
    }

    /// @notice Checks if the user has enough credits
    /// @param consumeFrom_ address to consume from
    /// @param spender_ address to spend from
    /// @param amount_ amount to spend
    /// @return True if the user has enough credits, false otherwise
    function isCreditSpendable(
        address consumeFrom_,
        address spender_,
        uint256 amount_
    ) public view returns (bool) {
        // If consumeFrom_ is not same as spender_ or spender_ is not watcher, check if it is approved
        if (spender_ != address(watcher__()) && consumeFrom_ != spender_) {
            if (!isApproved[consumeFrom_][spender_]) return false;
        }

        return getAvailableCredits(consumeFrom_) >= amount_;
    }

    function transferCredits(address from_, address to_, uint256 amount_) external {
        if (!isCreditSpendable(from_, msg.sender, amount_)) revert InsufficientCreditsAvailable();
        userCredits[from_].totalCredits -= amount_;
        userCredits[to_].totalCredits += amount_;

        emit CreditsTransferred(from_, to_, amount_);
    }

    /// @notice Approves multiple app gateways for the caller
    /// @param params_ Array of app gateway addresses to approve
    function approveAppGateways(AppGatewayApprovals[] calldata params_) external {
        for (uint256 i = 0; i < params_.length; i++) {
            isApproved[msg.sender][params_[i].appGateway] = params_[i].approval;
        }
    }

    /// @notice Approves an app gateway for the caller
    /// @dev Approval data is encoded to make app gateways compatible with future changes
    /// @param feeApprovalData_ The fee approval data
    /// @return consumeFrom The consume from address
    /// @return spender The app gateway address
    /// @return approval The approval status
    function approveAppGatewayWithSignature(
        bytes memory feeApprovalData_
    ) external returns (address consumeFrom, address spender, bool approval) {
        uint256 nonce;
        bytes memory signature_;
        (spender, approval, nonce, signature_) = abi.decode(
            feeApprovalData_,
            (address, address, bool, uint256, bytes)
        );
        bytes32 digest = keccak256(abi.encode(address(this), evmxSlug, spender, nonce, approval));
        consumeFrom = _recoverSigner(digest, signature_);

        if (isNonceUsed[consumeFrom][nonce]) revert NonceUsed();
        isNonceUsed[consumeFrom][nonce] = true;
        isApproved[consumeFrom][spender] = approval;
        return (consumeFrom, spender, approval);
    }

    /// @notice Withdraws funds to a specified receiver
    /// @dev This function is used to withdraw fees from the fees plug
    /// @dev assumed that transmitter can bid for their request on AM
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param credits_ The amount of tokens to withdraw
    /// @param maxFees_ The fees needed to process the withdraw
    /// @param receiver_ The address of the receiver
    function withdrawCredits(
        uint32 chainSlug_,
        address token_,
        uint256 credits_,
        uint256 maxFees_,
        address receiver_
    ) public {
        address consumeFrom = _getCoreAppGateway(msg.sender);

        // Check if amount is available in fees plug
        uint256 availableCredits = getAvailableCredits(consumeFrom);
        if (availableCredits < credits_) revert InsufficientCreditsAvailable();

        userCredits[consumeFrom].totalCredits -= credits_;
        tokenOnChainBalances[chainSlug_][token_] -= credits_;

        // Add it to the queue and submit request
        _createRequest(
            chainSlug_,
            consumeFrom,
            maxFees_,
            abi.encodeCall(IFeesPlug.withdrawFees, (token_, receiver_, credits_))
        );
    }

    function _createRequest(
        uint32 chainSlug_,
        address consumeFrom_,
        uint256 maxFees_,
        bytes memory payload_
    ) internal {
        OverrideParams memory overrideParams;
        overrideParams.callType = WRITE;
        overrideParams.writeFinality = WriteFinality.LOW;

        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;
        queueParams.transaction = Transaction({
            chainSlug: chainSlug_,
            target: _getFeesPlugAddress(chainSlug_),
            payload: payload_
        });
        queueParams.switchboardType = sbType;

        // queue and create request
        watcher__().queueAndSubmit(queueParams, maxFees_, address(0), consumeFrom_, bytes(""));
    }

    function _getFeesPlugAddress(uint32 chainSlug_) internal view returns (address) {
        return configuration__().feesPlug(chainSlug_);
    }

    function _getRequestParams(uint40 requestCount_) internal view returns (RequestParams memory) {
        return watcher__().getRequestParams(requestCount_);
    }

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }

    /// @notice hook called by watcher precompile when request is finished
    function onRequestComplete(uint40, bytes memory) external {}
}
