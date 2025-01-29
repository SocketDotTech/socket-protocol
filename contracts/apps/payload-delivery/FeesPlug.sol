// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "solmate/utils/SafeTransferLib.sol";
import "../../base/PlugBase.sol";
import {OwnableTwoStep} from "../../utils/OwnableTwoStep.sol";
import {ETH_ADDRESS} from "../../common/Constants.sol";

/// @title FeesManager
/// @notice Abstract contract for managing fees
contract FeesPlug is PlugBase, OwnableTwoStep {
    mapping(address => uint256) public balanceOf;
    mapping(bytes32 => bool) public feesRedeemed;

    /// @notice Error thrown when attempting to pay fees again
    error FeesAlreadyPaid();
    /// @notice Error thrown when balance is not enough to cover fees
    error InsufficientTokenBalance(address token_);
    /// @notice Error thrown when deposit amount does not match msg.value
    error InvalidDepositAmount();
    error InvalidTokenAddress();

    /// @notice Event emitted when fees are deposited
    event FeesDeposited(address appGateway, address token, uint256 amount);
    /// @notice Event emitted when fees are withdrawn
    event FeesWithdrawn(address token, uint256 amount, address receiver);

    modifier isFeesEnough(uint256 fee_, address feeToken_) {
        if (balanceOf[feeToken_] < fee_) revert InsufficientTokenBalance(feeToken_);
        _;
    }

    constructor(address socket_, address owner_) PlugBase(socket_) {
        _claimOwner(owner_);
    }

    function distributeFee(
        address feeToken_,
        uint256 fee_,
        address transmitter_,
        bytes32 feesId_
    ) external onlySocket isFeesEnough(fee_, feeToken_) {
        if (feesRedeemed[feesId_]) revert FeesAlreadyPaid();
        feesRedeemed[feesId_] = true;

        balanceOf[feeToken_] -= fee_;
        _transferTokens(feeToken_, fee_, transmitter_);
    }

    function withdrawFees(
        address token_,
        uint256 amount_,
        address receiver_
    ) external onlySocket isFeesEnough(amount_, token_) {
        balanceOf[token_] -= amount_;
        _transferTokens(token_, amount_, receiver_);

        emit FeesWithdrawn(token_, amount_, receiver_);
    }

    /// @notice Deposits funds
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param appGateway_ The app gateway address
    function deposit(address token_, address appGateway_, uint256 amount_) external payable {
        if (token_ == ETH_ADDRESS) {
            if (msg.value != amount_) revert InvalidDepositAmount();
        } else {
            if (token_.code.length == 0) revert InvalidTokenAddress();
        }

        balanceOf[token_] += amount_;

        if (token_ != ETH_ADDRESS) {
            SafeTransferLib.safeTransferFrom(ERC20(token_), msg.sender, address(this), amount_);
        }

        emit FeesDeposited(appGateway_, token_, amount_);
    }

    /// @notice Transfers tokens
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function _transferTokens(address token_, uint256 amount_, address receiver_) internal {
        if (token_ == ETH_ADDRESS) {
            SafeTransferLib.safeTransferETH(receiver_, amount_);
        } else {
            SafeTransferLib.safeTransfer(ERC20(token_), receiver_, amount_);
        }
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGateway_, socket_, switchboard_);
    }

    fallback() external payable {}

    receive() external payable {}
}
