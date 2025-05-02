// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import "../../../../contracts/base/PlugBase.sol";

/**
 * @title SuperToken
 * @notice An ERC20 contract which enables bridging a token to its sibling chains.
 */
contract SuperToken is ERC20, Ownable, PlugBase {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    mapping(address => uint256) public lockedTokens;

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

    function mint(address receiver_, uint256 amount_) external onlySocket {
        _mint(receiver_, amount_);
    }

    function burn(address user_, uint256 amount_) external onlySocket {
        _burn(user_, amount_);
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

    function setSocket(address newSocket_) external onlyOwner {
        _setSocket(newSocket_);
    }

    function setOwner(address owner_) external {
        if (owner() != address(0) && owner() != msg.sender) revert InvalidSender();
        _initializeOwner(owner_);
    }
}
