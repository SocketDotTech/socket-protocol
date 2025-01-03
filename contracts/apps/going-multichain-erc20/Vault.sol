// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "solady/utils/SafeTransferLib.sol";
import "solady/tokens/ERC20.sol";
import "solady/auth/Ownable.sol";

contract Vault is Ownable {
    // Custom Errors
    error ZeroDepositAmount();
    error ZeroWithdrawAmount();
    error NotSOCKET();

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    uint256 public balance;
    address public _SOCKET;
    address public token;

    modifier onlySOCKET() {
        if (msg.sender != _SOCKET) revert NotSOCKET();
        _;
    }

    constructor(address owner_, address token_) Ownable() {
        _initializeOwner(owner_);
        token = token_;
        _SOCKET = msg.sender;
    }

    /**
     * @notice Deposit ERC20 tokens into the vault
     * @param amount Amount of tokens to deposit
     * @param user Address of the user whose tokens are being deposited
     */
    function deposit(uint256 amount, address user) external onlySOCKET {
        if (amount == 0) revert ZeroDepositAmount();

        balance += amount;
        SafeTransferLib.safeTransferFrom(token, user, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Withdraw ERC20 tokens from the vault
     * @param amount Amount of tokens to withdraw
     * @param user Address of the user to receive the tokens
     */
    function withdraw(uint256 amount, address user) external onlySOCKET {
        if (amount == 0) revert ZeroWithdrawAmount();

        balance -= amount;
        SafeTransferLib.safeTransfer(token, user, amount);

        emit Withdrawn(user, amount);
    }

    /**
     * @notice Allows the owner to rescue tokens accidentally sent to the contract
     * @param token_ Address of the token to rescue
     * @param amount Amount of tokens to rescue
     * @param recipient Address to send rescued tokens to
     */
    function rescueTokens(
        address token_,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        SafeTransferLib.safeTransfer(token_, recipient, amount);
    }
}
