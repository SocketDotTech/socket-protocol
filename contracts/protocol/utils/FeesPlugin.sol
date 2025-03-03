// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Fees} from "../utils/common/Structs.sol";

/// @title FeesPlugin
/// @notice Abstract contract for managing fee configurations
/// @dev Provides base functionality for fee management in the system
abstract contract FeesPlugin {
    /// @notice Storage for the current fee configuration
    /// @dev Contains fee parameters like rates, limits, and recipient addresses
    Fees public fees;

    /// @notice Retrieves the current fee configuration
    /// @return Current fee configuration struct
    /// @dev Public view function accessible to any caller
    /// @dev Used by external contracts to verify fee parameters
    function getFees() public view returns (Fees memory) {
        return fees;
    }
}
