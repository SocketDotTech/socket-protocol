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

    error FeesAlreadyPaid();

    constructor(
        address socket_,
        address owner_
    ) Ownable(owner_) PlugBase(socket_) {}

    function distributeFee(
        address appGateway,
        address feeToken,
        uint256 fee,
        address transmitter,
        bytes32 feesId
    ) external onlySocket returns (bytes memory) {
        if (feesRedeemed[feesId]) revert FeesAlreadyPaid();
        feesRedeemed[feesId] = true;

        require(
            balanceOf[appGateway][feeToken] >= fee,
            "FeesPlug: Insufficient Balance for Fees"
        );
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
        require(
            balanceOf[appGateway][token] >= amount,
            "FeesPlug: Insufficient Balance for Withdrawal"
        );
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
            require(msg.value == amount, "FeesPlug: Invalid Deposit Amount");
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

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
