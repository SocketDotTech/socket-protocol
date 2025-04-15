// SPDX-License-Identifier: MIT
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
    event FeesDeposited(address appGateway, address token, uint256 amount);
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

        // ETH is whitelisted by default
        whitelistedTokens[ETH_ADDRESS] = true;
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

    /// @notice Deposits funds
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param appGateway_ The app gateway address
    function deposit(
        address token_,
        address appGateway_,
        uint256 amount_
    ) external payable override {
        if (!whitelistedTokens[token_]) revert TokenNotWhitelisted(token_);

        if (token_ == ETH_ADDRESS) {
            if (msg.value != amount_) revert InvalidDepositAmount();
        } else {
            if (token_.code.length == 0) revert InvalidTokenAddress();
        }

        balanceOf[token_] += amount_;

        if (token_ != ETH_ADDRESS) {
            SafeTransferLib.safeTransferFrom(token_, msg.sender, address(this), amount_);
        }

        emit FeesDeposited(appGateway_, token_, amount_);
    }

    /// @notice Transfers tokens
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function _transferTokens(address token_, uint256 amount_, address receiver_) internal {
        if (token_ == ETH_ADDRESS) {
            SafeTransferLib.forceSafeTransferETH(receiver_, amount_);
        } else {
            SafeTransferLib.safeTransfer(token_, receiver_, amount_);
        }
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
        if (token_ == ETH_ADDRESS) revert(); // Cannot remove ETH from whitelist
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

    receive() external payable {}
}
