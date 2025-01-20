// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solmate/utils/SafeTransferLib.sol";
import "../../base/PlugBase.sol";
import {Ownable} from "../../utils/Ownable.sol";
import {ETH_ADDRESS} from "../../common/Constants.sol";

/// @title FeesManager
/// @notice Abstract contract for managing fees
contract FeesPlug is PlugBase, Ownable {
    mapping(address => mapping(address => uint256)) public balanceOf;
    mapping(bytes32 => bool) public feesRedeemed;

    /// @notice Error thrown when attempting to pay fees again
    error FeesAlreadyPaid();
    /// @notice Error thrown when balance is not enough to cover fees
    error InsufficientBalanceForFees();
    /// @notice Error thrown when there is not enough balance for withdrawl
    error InsufficientBalanceForWithdrawl();
    /// @notice Error thrown when deposit amount does not match msg.value
    error InvalidDepositAmount();

    constructor(address socket_, address owner_) PlugBase(socket_) {
        _claimOwner(owner_);
    }

    function distributeFee(
        address appGateway_,
        address feeToken_,
        uint256 fee_,
        address transmitter_,
        bytes32 feesId_
    ) external onlySocket returns (bytes memory) {
        if (feesRedeemed[feesId_]) revert FeesAlreadyPaid();
        feesRedeemed[feesId_] = true;

        if (balanceOf[appGateway_][feeToken_] < fee_) {
            revert InsufficientBalanceForFees();
        }

        balanceOf[appGateway_][feeToken_] -= fee_;

        _transferTokens(feeToken_, fee_, transmitter_);
        return bytes("");
    }

    function withdrawFees(
        address appGateway_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external onlySocket returns (bytes memory) {
        if (balanceOf[appGateway_][token_] < amount_) {
            revert InsufficientBalanceForWithdrawl();
        }

        balanceOf[appGateway_][token_] -= amount_;
        _transferTokens(token_, amount_, receiver_);
        return bytes("");
    }

    /// @notice Deposits funds
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param appGateway_ The app gateway address
    function deposit(address token_, uint256 amount_, address appGateway_) external payable {
        if (token_ == ETH_ADDRESS) {
            if (msg.value != amount_) revert InvalidDepositAmount();
        } else {
            SafeTransferLib.safeTransferFrom(ERC20(token_), msg.sender, address(this), amount_);
        }
        balanceOf[appGateway_][token_] += amount_;
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
