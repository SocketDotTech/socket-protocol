// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

interface IFeesPlug {
    function depositToFee(address token_, address receiver_, uint256 amount_) external;

    function depositToFeeAndNative(address token_, address receiver_, uint256 amount_) external;

    function depositToNative(address token_, address receiver_, uint256 amount_) external;

    function withdrawFees(address token_, address receiver_, uint256 amount_) external;
}
