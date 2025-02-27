// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import "../../base/PlugBase.sol";

contract LimitHook is Ownable, PlugBase {
    // Define any state variables or functions for the LimitHook contract here
    uint256 public burnLimit;
    uint256 public mintLimit;

    error BurnLimitExceeded();
    error MintLimitExceeded();
    error InvalidSender();

    constructor(uint256 _burnLimit_, uint256 _mintLimit_) {
        burnLimit = _burnLimit_;
        mintLimit = _mintLimit_;
    }

    function setLimits(uint256 _burnLimit_, uint256 _mintLimit_) external onlyOwner {
        burnLimit = _burnLimit_;
        mintLimit = _mintLimit_;
    }

    function beforeBurn(uint256 amount_) external view {
        if (amount_ > burnLimit) revert BurnLimitExceeded();
    }

    function beforeMint(uint256 amount_) external view {
        if (amount_ > mintLimit) revert MintLimitExceeded();
    }

    function setOwner(address owner_) external {
        if (owner() != address(0) && owner() != msg.sender) revert InvalidSender();
        _initializeOwner(owner_);
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
