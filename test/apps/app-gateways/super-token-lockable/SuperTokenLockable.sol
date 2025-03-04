// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LimitHook} from "./LimitHook.sol";
import "../../../../contracts/base/PlugBase.sol";

/**
 * @title SuperToken
 * @notice An ERC20 contract which enables bridging a token to its sibling chains.
 */
contract SuperTokenLockable is ERC20, Ownable, PlugBase {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    LimitHook public limitHook__;
    mapping(address => uint256) public lockedTokens;

    error InsufficientLockedTokens();
    error InvalidSender();

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address initialSupplyHolder_,
        uint256 initialSupply_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _mint(initialSupplyHolder_, initialSupply_);
    }

    function lockTokens(address user_, uint256 amount_) external onlySocket {
        if (balanceOf(user_) < amount_) revert InsufficientBalance();
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

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function unlockTokens(address user_, uint256 amount_) external onlySocket {
        if (lockedTokens[user_] < amount_) revert InsufficientLockedTokens();
        lockedTokens[user_] -= amount_;
        _mint(user_, amount_);
    }

    function setSocket(address newSocket_) external onlyOwner {
        _setSocket(newSocket_);
    }

    function setLimitHook(address limitHook_) external onlySocket {
        limitHook__ = LimitHook(limitHook_);
    }

    function setOwner(address owner_) external {
        if (owner() != address(0) && owner() != msg.sender) revert InvalidSender();
        _initializeOwner(owner_);
    }
}
