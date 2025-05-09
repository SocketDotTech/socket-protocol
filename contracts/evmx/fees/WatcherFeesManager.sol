// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {AddressResolverUtil} from "../AddressResolverUtil.sol";
import "../interfaces/IWatcherFeesManager.sol";
import {SCHEDULE, QUERY, FINALIZE, CALLBACK} from "../../utils/common/Constants.sol";

/// @title WatcherFeesManager
/// @notice Contract for managing watcher fees
contract WatcherFeesManager is IWatcherFeesManager, Initializable, Ownable, AddressResolverUtil {
    // slots 0-49 (50) reserved for gauge
    // slots 50-100 (51) reserved for addr resolver util

    // slots [101-150]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 157: fees
    mapping(bytes32 => uint256) public watcherFees;

    /// @notice Emitted when the query fees are set
    event WatcherFeesSet(bytes32 feeType, uint256 fees);

    error WatcherFeesNotSet(bytes32 feeType);

    /// @notice Initial initialization (version 1)
    function initialize(address owner_, address addressResolver_, uint256) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
    }

    function setWatcherFees(bytes32 feeType, uint256 fees) external onlyOwner {
        watcherFees[feeType] = fees;
        emit WatcherFeesSet(feeType, fees);
    }

    function getWatcherFees(bytes32 feeType) external view returns (uint256) {
        return watcherFees[feeType];
    }

    function getTotalWatcherFeesRequired(
        bytes32[] memory feeTypes_,
        uint256[] memory counts_
    ) external view returns (uint256) {
        uint256 totalFees = 0;
        for (uint256 i = 0; i < feeTypes_.length; i++) {
            totalFees += watcherFees[feeTypes_[i]] * counts_[i];
        }
        return totalFees;
    }

    function payWatcherFees(
        bytes32[] memory feeTypes_,
        uint256[] memory counts_,
        address consumeFrom_
    ) external {
        uint256 totalFees = 0;
        for (uint256 i = 0; i < feeTypes_.length; i++) {
            totalFees += watcherFees[feeTypes_[i]] * counts_[i];
        }

        // call to fees manager to pay fees
    }
}
