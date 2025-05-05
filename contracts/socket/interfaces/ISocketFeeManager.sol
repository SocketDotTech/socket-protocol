// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ExecuteParams, TransmissionParams} from "../utils/common/Structs.sol";

interface ISocketFeeManager {
    /**
     * @notice Pays and validates fees for execution
     * @param executeParams_ Execute params
     * @param transmissionParams_ Transmission params
     */
    function payAndCheckFees(
        ExecuteParams memory executeParams_,
        TransmissionParams memory transmissionParams_
    ) external payable;

    /**
     * @notice Gets minimum fees required for execution
     * @return nativeFees Minimum native token fees required
     */
    function getMinSocketFees() external view returns (uint256 nativeFees);

    /**
     * @notice Sets socket fees
     * @param socketFees_ New socket fees amount
     */
    function setSocketFees(uint256 socketFees_) external;

    /**
     * @notice Gets current socket fees
     * @return Current socket fees amount
     */
    function socketFees() external view returns (uint256);
}
