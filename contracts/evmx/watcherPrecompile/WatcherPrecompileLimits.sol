// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {AddressResolverUtil} from "../AddressResolverUtil.sol";
import "../interfaces/IWatcherPrecompileLimits.sol";
import {SCHEDULE, QUERY, FINALIZE, CALLBACK} from "../../utils/common/Constants.sol";

/// @title WatcherPrecompileLimits
/// @notice Contract for managing watcher precompile limits
contract WatcherPrecompileLimits is
    IWatcherPrecompileLimits,
    Initializable,
    Ownable,
    AddressResolverUtil
{
    // slots 0-49 (50) reserved for gauge
    // slots 50-100 (51) reserved for addr resolver util

    // slots [101-150]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 157: fees
    uint256 public queryFees;
    uint256 public finalizeFees;
    uint256 public timeoutFees;
    uint256 public callBackFees;

    /// @notice Emitted when the query fees are set
    event QueryFeesSet(uint256 queryFees);
    /// @notice Emitted when the finalize fees are set
    event FinalizeFeesSet(uint256 finalizeFees);
    /// @notice Emitted when the timeout fees are set
    event TimeoutFeesSet(uint256 timeoutFees);
    /// @notice Emitted when the call back fees are set
    event CallBackFeesSet(uint256 callBackFees);

    error WatcherFeesNotSet(bytes32 limitType);

    /// @notice Initial initialization (version 1)
    function initialize(address owner_, address addressResolver_, uint256) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
    }

    function setQueryFees(uint256 queryFees_) external onlyOwner {
        queryFees = queryFees_;
        emit QueryFeesSet(queryFees_);
    }

    function setFinalizeFees(uint256 finalizeFees_) external onlyOwner {
        finalizeFees = finalizeFees_;
        emit FinalizeFeesSet(finalizeFees_);
    }

    function setTimeoutFees(uint256 timeoutFees_) external onlyOwner {
        timeoutFees = timeoutFees_;
        emit TimeoutFeesSet(timeoutFees_);
    }

    function setCallBackFees(uint256 callBackFees_) external onlyOwner {
        callBackFees = callBackFees_;
        emit CallBackFeesSet(callBackFees_);
    }

    function getTotalFeesRequired(
        uint256 queryCount_,
        uint256 finalizeCount_,
        uint256 scheduleCount_,
        uint256 callbackCount_
    ) external view returns (uint256) {
        uint256 totalFees = 0;
        totalFees += callbackCount_ * callBackFees;
        totalFees += queryCount_ * queryFees;
        totalFees += finalizeCount_ * finalizeFees;
        totalFees += scheduleCount_ * timeoutFees;

        return totalFees;
    }
}
