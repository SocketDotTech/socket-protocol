// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

interface ISuperToken {
    function burn(address user_, uint256 amount_) external;

    function mint(address receiver_, uint256 amount_) external;

    function lockTokens(address user_, uint256 amount_) external;

    function unlockTokens(address user_, uint256 amount_) external;

    // Public variable
    function controller() external returns (address);

    function setController(address controller_) external;

    function balanceOf(address account_) external;
}
