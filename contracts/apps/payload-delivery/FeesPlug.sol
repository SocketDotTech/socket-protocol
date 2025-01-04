// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solmate/utils/SafeTransferLib.sol";
import {PlugBase} from "../../base/PlugBase.sol";
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

    constructor(
        address socket_,
        uint32 chainSlug_,
        address owner_
    ) PlugBase(socket_, chainSlug_) Ownable(owner_) {}

    function distributeFee(
        address appGateway,
        address feeToken,
        uint256 fee,
        address transmitter,
        bytes32 feesId
    ) external onlySocket returns (bytes memory) {
        if (feesRedeemed[feesId]) revert FeesAlreadyPaid();
        feesRedeemed[feesId] = true;

        if (balanceOf[appGateway][feeToken] < fee) {
            revert InsufficientBalanceForFees();
        }

        balanceOf[appGateway][feeToken] -= fee;
        _transferTokens(feeToken, fee, transmitter);
        return bytes("");
    }

    function withdrawFees(
        address appGateway,
        address token,
        uint256 amount,
        address receiver
    ) external onlySocket returns (bytes memory) {
        if (balanceOf[appGateway][token] < amount) {
            revert InsufficientBalanceForWithdrawl();
        }

        balanceOf[appGateway][token] -= amount;
        _transferTokens(token, amount, receiver);
        return bytes("");
    }

    /// @notice Deposits funds
    /// @param token The token address
    /// @param amount The amount
    /// @param appGateway_ The app gateway address
    function deposit(
        address token,
        uint256 amount,
        address appGateway_
    ) external payable {
        if (token == ETH_ADDRESS) {
            if (msg.value != amount) revert InvalidDepositAmount();
        } else {
            SafeTransferLib.safeTransferFrom(
                ERC20(token),
                msg.sender,
                address(this),
                amount
            );
        }
        balanceOf[appGateway_][token] += amount;
    }

    /// @notice Transfers tokens
    /// @param token The token address
    /// @param amount The amount
    /// @param receiver The receiver address
    function _transferTokens(
        address token,
        uint256 amount,
        address receiver
    ) internal {
        if (token == ETH_ADDRESS) {
            SafeTransferLib.safeTransferETH(receiver, amount);
        } else {
            SafeTransferLib.safeTransfer(ERC20(token), receiver, amount);
        }
    }

    function connect(
        address appGateway_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGateway_, switchboard_);
    }
}
