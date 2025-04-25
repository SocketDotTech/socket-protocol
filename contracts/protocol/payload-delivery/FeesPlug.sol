// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/SafeTransferLib.sol";
import "solady/tokens/ERC20.sol";
import "../../base/PlugBase.sol";
import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/common/AccessRoles.sol";
import {IFeesPlug} from "../../interfaces/IFeesPlug.sol";
import "../utils/RescueFundsLib.sol";
import {ETH_ADDRESS} from "../utils/common/Constants.sol";
import {InvalidTokenAddress, FeesAlreadyPaid} from "../utils/common/Errors.sol";

/// @title FeesManager
/// @notice Contract for managing fees on a network
/// @dev The amount deposited here is locked and updated in the EVMx for an app gateway
/// @dev The fees are redeemed by the transmitters executing request or can be withdrawn by the owner
contract FeesPlug is IFeesPlug, PlugBase, AccessControl {
    /// @notice Mapping to store if a token is whitelisted
    mapping(address => bool) public whitelistedTokens;

    /// @notice Error thrown when balance is not enough to cover fees
    error InsufficientTokenBalance(address token_, uint256 balance_, uint256 fee_);
    /// @notice Error thrown when deposit amount does not match msg.value
    error InvalidDepositAmount();
    /// @notice Error thrown when token is not whitelisted
    error TokenNotWhitelisted(address token_);

    /// @notice Event emitted when fees are deposited
    event FeesDeposited(address token, address receiver, uint256 feeAmount, uint256 nativeAmount);
    /// @notice Event emitted when fees are withdrawn
    event FeesWithdrawn(address token, address receiver, uint256 amount);
    /// @notice Event emitted when a token is whitelisted
    event TokenWhitelisted(address token);
    /// @notice Event emitted when a token is removed from whitelist
    event TokenRemovedFromWhitelist(address token);

    /// @notice Modifier to check if the balance of a token is enough to withdraw
    modifier isUserCreditsEnough(address feeToken_, uint256 fee_) {
        uint balance_ = ERC20(feeToken_).balanceOf(address(this));
        if (balance_ < fee_) revert InsufficientTokenBalance(feeToken_, balance_, fee_);
        _;
    }

    /// @notice Constructor for the FeesPlug contract
    /// @param socket_ The socket address
    /// @param owner_ The owner address
    constructor(address socket_, address owner_) {
        _setSocket(socket_);
        _initializeOwner(owner_);
    }

    /// @notice Withdraws fees
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function withdrawFees(
        address token_,
        address receiver_,
        uint256 amount_
    ) external override onlySocket isUserCreditsEnough(token_, amount_) {
        SafeTransferLib.safeTransfer(token_, receiver_, amount_);
        emit FeesWithdrawn(token_, receiver_, amount_);
    }

    function depositToFee(address token_, address receiver_, uint256 amount_) external override {
        _deposit(token_, receiver_, amount_, 0);
    }

    function depositToFeeAndNative(
        address token_,
        address receiver_,
        uint256 amount_
    ) external override {
        uint256 nativeAmount_ = amount_ / 10;
        uint256 feeAmount_ = amount_ - nativeAmount_;
        _deposit(token_, receiver_, feeAmount_, nativeAmount_);
    }

    function depositToNative(address token_, address receiver_, uint256 amount_) external override {
        _deposit(token_, receiver_, 0, amount_);
    }

    /// @notice Deposits funds
    /// @param token_ The token address
    /// @param feeAmount_ The amount of fees
    /// @param nativeAmount_ The amount of native tokens
    /// @param receiver_ The receiver address
    function _deposit(
        address token_,
        address receiver_,
        uint256 feeAmount_,
        uint256 nativeAmount_
    ) internal {
        uint256 totalAmount_ = feeAmount_ + nativeAmount_;
        if (!whitelistedTokens[token_]) revert TokenNotWhitelisted(token_);
        SafeTransferLib.safeTransferFrom(token_, msg.sender, address(this), totalAmount_);
        emit FeesDeposited(receiver_, token_, feeAmount_, nativeAmount_);
    }

    /// @notice Adds a token to the whitelist
    /// @param token_ The token address to whitelist
    function whitelistToken(address token_) external onlyOwner {
        if (token_.code.length == 0) revert InvalidTokenAddress();
        whitelistedTokens[token_] = true;
        emit TokenWhitelisted(token_);
    }

    /// @notice Removes a token from the whitelist
    /// @param token_ The token address to remove
    function removeTokenFromWhitelist(address token_) external onlyOwner {
        whitelistedTokens[token_] = false;
        emit TokenRemovedFromWhitelist(token_);
    }

    function connectSocket(
        bytes32 appGatewayId_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGatewayId_, socket_, switchboard_);
    }
    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
