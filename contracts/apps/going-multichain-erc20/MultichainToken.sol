// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solady/tokens/ERC20.sol";

/**
 * @title MultichainToken
 * @notice An ERC20 contract which enables bridging a token to its sibling chains.
 * @dev Implements a custom ERC20 token with minting and burning capabilities restricted to a socket address
 */
contract MultichainToken is ERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address public _SOCKET;

    // Custom Errors
    error NotSOCKET();

    modifier onlySOCKET() {
        if (msg.sender != _SOCKET) revert NotSOCKET();
        _;
    }

    /**
     * @notice Initialize the token with name, symbol, and decimals
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     * @param decimals_ The number of decimals for the token
     * @dev Sets the token parameters and sets the initial socket address to the contract deployer
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _SOCKET = msg.sender;
    }

    /**
     * @notice Mint tokens to a specified address
     * @dev Can only be called by the SOCKET address
     * @param to_ The address to mint tokens to
     * @param amount_ The amount of tokens to mint
     * @custom:modifier onlySOCKET Ensures only the SOCKET can call this function
     */
    function mint(address to_, uint256 amount_) external onlySOCKET {
        _mint(to_, amount_);
    }

    /**
     * @notice Burn tokens from the caller's balance
     * @dev Can only be called by the SOCKET address
     * @param amount_ The amount of tokens to burn
     * @custom:modifier onlySOCKET Ensures only the SOCKET can call this function
     */
    function burn(uint256 amount_) external onlySOCKET {
        _burn(msg.sender, amount_);
    }

    /**
     * @notice Returns the name of the token
     * @return The token's name
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token
     * @return The token's symbol
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the number of decimals for the token
     * @return The token's decimal places
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
