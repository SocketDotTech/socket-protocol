// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ERC20.sol";
import {Ownable} from "../../utils/Ownable.sol";
import "../../base/PlugBase.sol";

/**
 * @title SuperToken
 * @notice An ERC20 contract which enables bridging a token to its sibling chains.
 */
contract SuperToken is ERC20, Ownable, PlugBase {
    mapping(address => uint256) public lockedTokens;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address initialSupplyHolder_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_, decimals_) PlugBase(msg.sender) {
        _mint(initialSupplyHolder_, initialSupply_);
        _claimOwner(msg.sender);
    }

    function mint(address receiver_, uint256 amount_) external onlySocket {
        _mint(receiver_, amount_);
    }

    function burn(address user_, uint256 amount_) external onlySocket {
        _burn(user_, amount_);
    }

    function setSocket(address newSocket_) external onlyOwner {
        _setSocket(newSocket_);
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _claimOwner(socket_);
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
