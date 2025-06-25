// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/SafeTransferLib.sol";
import "../../protocol/base/PlugBase.sol";
import "../../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../../utils/common/AccessRoles.sol";
import {IFeesPlug} from "../interfaces/IFeesPlug.sol";
import "../../utils/RescueFundsLib.sol";
import {InvalidTokenAddress} from "../../utils/common/Errors.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);
}

/// @title FeesPlug
/// @notice Contract for managing fees on a network
/// @dev The amount deposited here is locked and updated in the EVMx for an app gateway
/// @dev The fees are redeemed by the transmitters executing request or can be withdrawn by the owner
contract FeesPlug is IFeesPlug, PlugBase, AccessControl {
    using SafeTransferLib for address;

    /// @notice Mapping to store if a token is whitelisted
    mapping(address => bool) public whitelistedTokens;

    /// @notice Error thrown when balance is not enough to cover fees
    error InsufficientTokenBalance(address token_, uint256 balance_, uint256 fee_);
    /// @notice Error thrown when deposit amount does not match msg.value
    error InvalidDepositAmount();
    /// @notice Error thrown when token is not whitelisted
    error TokenNotWhitelisted(address token_);

    /// @notice Constructor for the FeesPlug contract
    /// @param socket_ The socket address
    /// @param owner_ The owner address
    constructor(address socket_, address owner_) {
        _setSocket(socket_);
        _initializeOwner(owner_);

        isSocketInitialized = 1;
    }

    /////////////////////// DEPOSIT AND WITHDRAWAL ///////////////////////
    function depositCredit(address token_, address receiver_, uint256 amount_) external override {
        _deposit(token_, receiver_, amount_, 0);
    }

    function depositCreditAndNative(
        address token_,
        address receiver_,
        uint256 amount_
    ) external override {
        uint256 nativeAmount_ = amount_ / 10;
        _deposit(token_, receiver_, amount_ - nativeAmount_, nativeAmount_);
    }

    function depositToNative(address token_, address receiver_, uint256 amount_) external override {
        _deposit(token_, receiver_, 0, amount_);
    }

    /// @notice Deposits funds
    /// @param token_ The token address
    /// @param creditAmount_ The amount of fees
    /// @param nativeAmount_ The amount of native tokens
    /// @param receiver_ The receiver address
    function _deposit(
        address token_,
        address receiver_,
        uint256 creditAmount_,
        uint256 nativeAmount_
    ) internal {
        if (!whitelistedTokens[token_]) revert TokenNotWhitelisted(token_);
        token_.safeTransferFrom(msg.sender, address(this), creditAmount_ + nativeAmount_);
        emit FeesDeposited(token_, receiver_, creditAmount_, nativeAmount_);
    }

    /// @notice Withdraws fees
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function withdrawFees(
        address token_,
        address receiver_,
        uint256 amount_
    ) external override onlySocket {
        uint256 balance = IERC20(token_).balanceOf(address(this));
        uint8 decimals = IERC20(token_).decimals();

        if (decimals < 18) {
            amount_ = amount_ / 10 ** (18 - decimals);
        } else if (decimals > 18) {
            amount_ = amount_ * 10 ** (decimals - 18);
        }
        if (balance < amount_) revert InsufficientTokenBalance(token_, balance, amount_);

        token_.safeTransfer(receiver_, amount_);
        emit FeesWithdrawn(token_, receiver_, amount_);
    }

    /////////////////////// ADMIN FUNCTIONS ///////////////////////

    /// @notice Adds a token to the whitelist
    /// @param token_ The token address to whitelist
    // TODO:GW: what is that toknen used for ? is it EVM specific ?
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

    // TODO:GW: what is calling this function ? - is it only EVM specific ?
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
