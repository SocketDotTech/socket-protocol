// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/SafeTransferLib.sol";
import {ZeroAddress, InvalidTokenAddress} from "./common/Errors.sol";
import {ETH_ADDRESS} from "./common/Constants.sol";

/**
 * @title RescueFundsLib
 * @dev A library that provides a function to rescue funds from a contract.
 */
library RescueFundsLib {
    /**
     * @dev Rescues funds from a contract.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address of the user.
     * @param amount_ The amount of tokens to be rescued.
     */
    function _rescueFunds(address token_, address rescueTo_, uint256 amount_) internal {
        if (rescueTo_ == address(0)) revert ZeroAddress();

        if (token_ == ETH_ADDRESS) {
            SafeTransferLib.forceSafeTransferETH(rescueTo_, amount_);
        } else {
            if (token_.code.length == 0) revert InvalidTokenAddress();
            SafeTransferLib.safeTransfer(token_, rescueTo_, amount_);
        }
    }
}
