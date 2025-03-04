// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "solmate/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import "../../../../contracts/base/PlugBase.sol";

interface ISwitchboard {
    function checkAndConsume(address user_, uint256 amount_) external;
}

/**
 * @title SuperToken
 * @notice An ERC20 contract which enables bridging a token to its sibling chains.
 */
contract SuperToken is ERC20, Ownable, PlugBase {
    mapping(address => uint256) public lockedTokens;
    address public opSwitchboard;

    error InvalidSender();

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address initialSupplyHolder_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_, decimals_) {
        _mint(initialSupplyHolder_, initialSupply_);
    }

    function mint(address user_, uint256 amount_) external onlySocket {
        ISwitchboard(opSwitchboard).checkAndConsume(user_, amount_);
        _mint(user_, amount_);
    }

    function burn(address user_, uint256 amount_) external onlySocket {
        _burn(user_, amount_);
    }

    function setSocket(address newSocket_) external onlyOwner {
        _setSocket(newSocket_);
    }

    function setOpSwitchboard(address newOpSwitchboard_) external onlyOwner {
        opSwitchboard = newOpSwitchboard_;
    }

    function setupToken(address owner_, address opSwitchboard_) external {
        if (owner() != address(0) && owner() != msg.sender) revert InvalidSender();
        _initializeOwner(owner_);
        opSwitchboard = opSwitchboard_;
    }
}
