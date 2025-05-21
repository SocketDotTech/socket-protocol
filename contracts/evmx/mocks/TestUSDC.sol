// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/tokens/ERC20.sol";

contract TestUSDC is ERC20 {
    address public immutable owner;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_,
        uint256 initialSupply_
    ) {
        owner = owner_;
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _mint(owner_, initialSupply_);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
