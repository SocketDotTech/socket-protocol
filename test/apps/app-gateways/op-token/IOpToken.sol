// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IOpToken {
    function burn(address user_, uint256 amount_) external;

    function mint(address receiver_, uint256 amount_) external;
}
