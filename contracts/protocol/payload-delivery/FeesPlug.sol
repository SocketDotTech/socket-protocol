// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "solmate/utils/SafeTransferLib.sol";
import "../../base/PlugBase.sol";
import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/common/AccessRoles.sol";
import "../utils/RescueFundsLib.sol";
import {ETH_ADDRESS} from "../utils/common/Constants.sol";

/// @title FeesManager
/// @notice Abstract contract for managing fees
contract FeesPlug is PlugBase, AccessControl {
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

    constructor(address socket_, address owner_) {
        _setSocket(socket_);
        _initializeOwner(owner_);
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
            SafeTransferLib.safeTransferETH(payable(receiver_), amount_);
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

    fallback() external payable {}

    receive() external payable {}
}
