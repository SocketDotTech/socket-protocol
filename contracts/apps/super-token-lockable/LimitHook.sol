// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableTwoStep} from "../../utils/OwnableTwoStep.sol";
import "../../base/PlugBase.sol";

contract LimitHook is OwnableTwoStep, PlugBase {
    // Define any state variables or functions for the LimitHook contract here
    uint256 public burnLimit;
    uint256 public mintLimit;

    error BurnLimitExceeded();
    error MintLimitExceeded();

    constructor(uint256 _burnLimit_, uint256 _mintLimit_) PlugBase(msg.sender) {
        burnLimit = _burnLimit_;
        mintLimit = _mintLimit_;
        _claimOwner(msg.sender);
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

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _claimOwner(socket_);
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
