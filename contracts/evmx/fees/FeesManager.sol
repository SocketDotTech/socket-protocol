// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./Credit.sol";

/// @title FeesManager
/// @notice Contract for managing fees
abstract contract FeesManager is Credit {
    /// @notice Emitted when fees are blocked for a batch
    /// @param requestCount The batch identifier
    /// @param consumeFrom The consume from address
    /// @param amount The blocked amount
    event CreditsBlocked(uint40 indexed requestCount, address indexed consumeFrom, uint256 amount);

    /// @notice Emitted when transmitter fees are updated
    /// @param requestCount The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The new amount deposited
    event TransmitterCreditsUpdated(
        uint40 indexed requestCount,
        address indexed transmitter,
        uint256 amount
    );
    event WatcherPrecompileCreditsAssigned(uint256 amount, address consumeFrom);

    /// @notice Emitted when fees are unblocked and assigned to a transmitter
    /// @param requestCount The batch identifier
    /// @param consumeFrom The consume from address
    /// @param transmitter The transmitter address
    /// @param amount The unblocked amount
    event CreditsUnblockedAndAssigned(
        uint40 indexed requestCount,
        address indexed consumeFrom,
        address indexed transmitter,
        uint256 amount
    );

    /// @notice Emitted when fees are unblocked
    /// @param requestCount The batch identifier
    /// @param appGateway The app gateway address
    event CreditsUnblocked(uint40 indexed requestCount, address indexed appGateway);

    /// @notice Emitted when insufficient watcher precompile fees are available
    event InsufficientWatcherPrecompileCreditsAvailable(
        uint32 chainSlug,
        address token,
        address consumeFrom
    );

    modifier onlyRequestHandler() {
        if (msg.sender != address(watcher__().requestHandler__())) revert NotRequestHandler();
        _;
    }

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the owner
    /// @param evmxSlug_ The evmx chain slug
    function initialize(
        address addressResolver_,
        address owner_,
        uint32 evmxSlug_,
        bytes32 sbType_
    ) public reinitializer(1) {
        evmxSlug = evmxSlug_;
        sbType = sbType_;
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
    }

    /////////////////////// FEES MANAGEMENT ///////////////////////

    /// @notice Blocks fees for a request count
    /// @param requestCount_ The batch identifier
    /// @param consumeFrom_ The fees payer address
    /// @param credits_ The total fees to block
    /// @dev Only callable by delivery helper
    function blockCredits(
        uint40 requestCount_,
        address consumeFrom_,
        uint256 credits_
    ) external override onlyRequestHandler {
        if (getAvailableCredits(consumeFrom_) < credits_) revert InsufficientCreditsAvailable();

        UserCredits storage userCredit = userCredits[consumeFrom_];
        userCredit.blockedCredits += credits_;
        requestBlockedCredits[requestCount_] = credits_;
        emit CreditsBlocked(requestCount_, consumeFrom_, credits_);
    }

    /// @notice Unblocks fees after successful execution and assigns them to the transmitter
    /// @param requestCount_ The async ID of the executed batch
    /// @param assignTo_ The address of the transmitter
    function unblockAndAssignCredits(
        uint40 requestCount_,
        address assignTo_
    ) external override onlyRequestHandler {
        uint256 blockedCredits = requestBlockedCredits[requestCount_];
        if (blockedCredits == 0) return;

        address consumeFrom = _getRequestParams(requestCount_).requestFeesDetails.consumeFrom;
        // Unblock fees from deposit
        UserCredits storage userCredit = userCredits[consumeFrom];
        userCredit.blockedCredits -= blockedCredits;
        userCredit.totalCredits -= blockedCredits;

        // Assign fees to transmitter
        userCredits[assignTo_].totalCredits += blockedCredits;

        // Clean up storage
        delete requestBlockedCredits[requestCount_];
        emit CreditsUnblockedAndAssigned(requestCount_, consumeFrom, assignTo_, blockedCredits);
    }

    function unblockCredits(uint40 requestCount_) external override onlyRequestHandler {
        uint256 blockedCredits = requestBlockedCredits[requestCount_];
        if (blockedCredits == 0) return;

        // Unblock fees from deposit
        address consumeFrom = _getRequestParams(requestCount_).requestFeesDetails.consumeFrom;
        UserCredits storage userCredit = userCredits[consumeFrom];
        userCredit.blockedCredits -= blockedCredits;

        delete requestBlockedCredits[requestCount_];
        emit CreditsUnblocked(requestCount_, consumeFrom);
    }
}
