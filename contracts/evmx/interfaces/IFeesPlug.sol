// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

interface IFeesPlug {
    /// @notice Event emitted when fees are deposited
    event FeesDeposited(
        address token,
        address receiver,
        uint256 creditAmount,
        uint256 nativeAmount
    );
    /// @notice Event emitted when fees are withdrawn
    event FeesWithdrawn(address token, address receiver, uint256 amount);
    /// @notice Event emitted when a token is whitelisted
    event TokenWhitelisted(address token);
    /// @notice Event emitted when a token is removed from whitelist
    event TokenRemovedFromWhitelist(address token);

    function depositCredit(address token_, address receiver_, uint256 amount_) external;

    function depositCreditAndNative(address token_, address receiver_, uint256 amount_) external;

    function depositToNative(address token_, address receiver_, uint256 amount_) external;

    function withdrawFees(address token_, address receiver_, uint256 amount_) external;
}
