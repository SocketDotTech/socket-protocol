// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/SafeTransferLib.sol";
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
    /// @notice Mapping to store the balance of each token
    mapping(address => uint256) public override balanceOf;
    /// @notice Mapping to store if fees have been redeemed for a given fees ID
    mapping(bytes32 => bool) public override feesRedeemed;
    /// @notice Mapping to store if a token is whitelisted
    mapping(address => bool) public whitelistedTokens;

    /// @notice Error thrown when balance is not enough to cover fees
    error InsufficientTokenBalance(address token_);
    /// @notice Error thrown when deposit amount does not match msg.value
    error InvalidDepositAmount();
    /// @notice Error thrown when token is not whitelisted
    error TokenNotWhitelisted(address token_);

    /// @notice Event emitted when fees are deposited
    event FeesDeposited(address receiver, address token, uint256 feeAmount, uint256 nativeAmount);
    /// @notice Event emitted when fees are withdrawn
    event FeesWithdrawn(address token, uint256 amount, address receiver);
    /// @notice Event emitted when a token is whitelisted
    event TokenWhitelisted(address token);
    /// @notice Event emitted when a token is removed from whitelist
    event TokenRemovedFromWhitelist(address token);

    /// @notice Modifier to check if the balance of a token is enough to withdraw
    modifier isFeesEnough(uint256 fee_, address feeToken_) {
        if (balanceOf[feeToken_] < fee_) revert InsufficientTokenBalance(feeToken_);
        _;
    }

    /// @notice Constructor for the FeesPlug contract
    /// @param socket_ The socket address
    /// @param owner_ The owner address
    constructor(address socket_, address owner_) {
        _setSocket(socket_);
        _initializeOwner(owner_);
    }

    /// @notice Distributes fees to the transmitter
    /// @param feeToken_ The token address
    /// @param fee_ The amount of fees
    /// @param transmitter_ The transmitter address
    /// @param feesId_ The fees ID
    function distributeFee(
        address feeToken_,
        uint256 fee_,
        address transmitter_,
        bytes32 feesId_
    ) external override onlySocket isFeesEnough(fee_, feeToken_) {
        if (feesRedeemed[feesId_]) revert FeesAlreadyPaid();
        feesRedeemed[feesId_] = true;
        balanceOf[feeToken_] -= fee_;

        _transferTokens(feeToken_, fee_, transmitter_);
    }

    /// @notice Withdraws fees
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function withdrawFees(
        address token_,
        uint256 amount_,
        address receiver_
    ) external override onlySocket isFeesEnough(amount_, token_) {
        balanceOf[token_] -= amount_;

        _transferTokens(token_, amount_, receiver_);
        emit FeesWithdrawn(token_, amount_, receiver_);
    }

    function depositToFee(address token_, uint256 amount_, address receiver_) external override {
        _deposit(token_, receiver_, amount_, 0);
    }

    function depositToFeeAndNative(
        address token_,
        uint256 amount_,
        address receiver_
    ) external override {
        uint256 nativeAmount_ = amount_ / 10;
        uint256 feeAmount_ = amount_ - nativeAmount_;
        _deposit(token_, receiver_, feeAmount_, nativeAmount_);
    }

    function depositToNative(address token_, uint256 amount_, address receiver_) external override {
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
    ) internal override {
        uint256 totalAmount_ = feeAmount_ + nativeAmount_;
        if (!whitelistedTokens[token_]) revert TokenNotWhitelisted(token_);
        if (token_.code.length == 0) revert InvalidTokenAddress();

        balanceOf[token_] += totalAmount_;
        emit FeesDeposited(receiver_, token_, feeAmount_, nativeAmount_);
    }

    /// @notice Transfers tokens
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function _transferTokens(address token_, uint256 amount_, address receiver_) internal {
        SafeTransferLib.safeTransfer(token_, receiver_, amount_);
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGateway_, socket_, switchboard_);
    }

    /// @notice Adds a token to the whitelist
    /// @param token_ The token address to whitelist
    function whitelistToken(address token_) external onlyOwner {
        whitelistedTokens[token_] = true;
        emit TokenWhitelisted(token_);
    }

    /// @notice Removes a token from the whitelist
    /// @param token_ The token address to remove
    function removeTokenFromWhitelist(address token_) external onlyOwner {
        whitelistedTokens[token_] = false;
        emit TokenRemovedFromWhitelist(token_);
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
