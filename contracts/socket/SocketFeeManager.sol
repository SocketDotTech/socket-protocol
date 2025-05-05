// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../utils/AccessControl.sol";
import {GOVERNANCE_ROLE, RESCUE_ROLE} from "../utils/common/AccessRoles.sol";
import {ExecuteParams, TransmissionParams} from "../utils/common/Structs.sol";
import "../interfaces/ISocketFeeManager.sol";
import "../utils/RescueFundsLib.sol";

/**
 * @title SocketFeeManager
 * @notice The SocketFeeManager contract is responsible for managing socket fees
 */
contract SocketFeeManager is ISocketFeeManager, AccessControl {
    // Current socket fees in native tokens
    uint256 public socketFees;

    error InsufficientFees();
    error FeeTooLow();

    event SocketFeesUpdated(uint256 oldFees, uint256 newFees);

    /**
     * @notice Initializes the SocketFeeManager contract
     * @param owner_ The owner of the contract with GOVERNANCE_ROLE
     * @param socketFees_ Initial socket fees amount
     */
    constructor(address owner_, uint256 socketFees_) {
        emit SocketFeesUpdated(0, socketFees_);
        socketFees = socketFees_;
        _grantRole(GOVERNANCE_ROLE, owner_);
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice Pays and validates fees for execution
     */
    function payAndCheckFees(ExecuteParams memory, TransmissionParams memory) external payable {
        if (msg.value < socketFees) revert InsufficientFees();
    }

    /**
     * @notice Gets minimum fees required for execution
     * @return nativeFees Minimum native token fees required
     */
    function getMinSocketFees() external view returns (uint256 nativeFees) {
        return socketFees;
    }

    /**
     * @notice Sets socket fees
     * @param socketFees_ New socket fees amount
     */
    function setSocketFees(uint256 socketFees_) external onlyRole(GOVERNANCE_ROLE) {
        emit SocketFeesUpdated(socketFees, socketFees_);
        socketFees = socketFees_;
    }

    /**
     * @notice Allows owner to rescue stuck funds
     * @param token_ Token address (address(0) for native tokens)
     * @param to_ Address to send funds to
     * @param amount_ Amount of tokens to rescue
     */
    function rescueFunds(
        address token_,
        address to_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib._rescueFunds(token_, to_, amount_);
    }
}
