// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "solmate/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LimitHook} from "./LimitHook.sol";
import "../../base/PlugBase.sol";

/**
 * @title SuperToken
 * @notice An ERC20 contract which enables bridging a token to its sibling chains.
 */
contract SuperTokenLockable is ERC20, Ownable, PlugBase {
    LimitHook public limitHook__;
    mapping(address => uint256) public lockedTokens;

    error InsufficientBalance();
    error InsufficientLockedTokens();

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address initialSupplyHolder_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_, decimals_) {
        _mint(initialSupplyHolder_, initialSupply_);
    }

    function lockTokens(address user_, uint256 amount_) external onlySocket {
        if (balanceOf[user_] < amount_) revert InsufficientBalance();
        limitHook__.beforeBurn(amount_);

        lockedTokens[user_] += amount_;
        _burn(user_, amount_);
    }

    function mint(address receiver_, uint256 amount_) external onlySocket {
        limitHook__.beforeMint(amount_);
        _mint(receiver_, amount_);
    }

    function burn(address user_, uint256 amount_) external onlySocket {
        lockedTokens[user_] -= amount_;
    }

    function unlockTokens(address user_, uint256 amount_) external onlySocket {
        if (lockedTokens[user_] < amount_) revert InsufficientLockedTokens();
        lockedTokens[user_] -= amount_;
        _mint(user_, amount_);
    }

    function setSocket(address newSocket_) external onlyOwner {
        _setSocket(newSocket_);
    }

    function setLimitHook(address limitHook_) external onlyOwner {
        limitHook__ = LimitHook(limitHook_);
    }
}
