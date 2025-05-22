// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./FeesStorage.sol";

/// @title UserUtils
/// @notice Contract for managing user utils
abstract contract Credit is FeesStorage, Initializable, Ownable, AddressResolverUtil {
    /// @notice Emitted when fees deposited are updated
    /// @param chainSlug The chain identifier
    /// @param appGateway The app gateway address
    /// @param token The token address
    /// @param amount The new amount deposited
    event CreditsDeposited(
        uint32 indexed chainSlug,
        address indexed appGateway,
        address indexed token,
        uint256 amount
    );

    /// @notice Emitted when credits are wrapped
    event CreditsWrapped(address indexed consumeFrom, uint256 amount);

    /// @notice Emitted when credits are unwrapped
    event CreditsUnwrapped(address indexed consumeFrom, uint256 amount);

    /// @notice Deposits credits and native tokens to a user
    /// @param depositTo_ The address to deposit the credits to
    /// @param chainSlug_ The chain slug
    /// @param token_ The token address
    /// @param nativeAmount_ The native amount
    /// @param creditAmount_ The credit amount
    function deposit(
        address depositTo_,
        uint32 chainSlug_,
        address token_,
        uint256 nativeAmount_,
        uint256 creditAmount_
    ) external payable onlyWatcher {
        if (creditAmount_ + nativeAmount_ != msg.value) revert InvalidAmount();

        UserCredits storage userCredit = userCredits[depositTo_];
        userCredit.totalCredits += creditAmount_;
        tokenPoolBalances[chainSlug_][token_] += creditAmount_;
        payable(depositTo_).transfer(nativeAmount_);

        emit CreditsDeposited(chainSlug_, depositTo_, token_, creditAmount_);
    }

    function wrap(address receiver_) external payable {
        UserCredits storage userCredit = userCredits[receiver_];
        userCredit.totalCredits += msg.value;
        emit CreditsWrapped(receiver_, msg.value);
    }

    function unwrap(uint256 amount_) external {
        UserCredits storage userCredit = userCredits[msg.sender];
        if (userCredit.totalCredits < amount_) revert InsufficientCreditsAvailable();
        userCredit.totalCredits -= amount_;

        if (address(this).balance < amount_) revert InsufficientBalance();
        payable(msg.sender).transfer(amount_);

        emit CreditsUnwrapped(msg.sender, amount_);
    }

    /// @notice Returns available (unblocked) credits for a gateway
    /// @param consumeFrom_ The app gateway address
    /// @return The available credit amount
    function getAvailableCredits(address consumeFrom_) public view returns (uint256) {
        UserCredits memory userCredit = userCredits[consumeFrom_];
        return userCredit.totalCredits - userCredit.blockedCredits;
    }

    /// @notice Checks if the user has enough credits
    /// @param from_ The app gateway address
    /// @param to_ The app gateway address
    /// @param amount_ The amount
    /// @return True if the user has enough credits, false otherwise
    function isUserCreditsEnough(
        address from_,
        address to_,
        uint256 amount_
    ) external view returns (bool) {
        // If from_ is not same as to_ or to_ is not watcher, check if it is whitelisted
        if (
            to_ != address(watcherPrecompile__()) &&
            from_ != to_ &&
            !isAppGatewayWhitelisted[from_][to_]
        ) revert AppGatewayNotWhitelisted();

        return getAvailableCredits(from_) >= amount_;
    }

    function transferCredits(address from_, address to_, uint256 amount_) external {
        if (!isUserCreditsEnough(from_, msg.sender, amount_)) revert InsufficientCreditsAvailable();
        userCredits[from_].totalCredits -= amount_;
        userCredits[to_].totalCredits += amount_;

        emit CreditsTransferred(from_, to_, amount_);
    }

    function whitelistAppGatewayWithSignature(
        bytes memory feeApprovalData_
    ) external returns (address consumeFrom, address appGateway, bool isApproved) {
        return _processFeeApprovalData(feeApprovalData_);
    }

    /// @notice Whitelists multiple app gateways for the caller
    /// @param params_ Array of app gateway addresses to whitelist
    function whitelistAppGateways(AppGatewayWhitelistParams[] calldata params_) external {
        for (uint256 i = 0; i < params_.length; i++) {
            isAppGatewayWhitelisted[msg.sender][params_[i].appGateway] = params_[i].isApproved;
        }
    }

    function _processFeeApprovalData(
        bytes memory feeApprovalData_
    ) internal returns (address, address, bool) {
        (
            address consumeFrom,
            address appGateway,
            bool isApproved,
            uint256 nonce,
            bytes memory signature_
        ) = abi.decode(feeApprovalData_, (address, address, bool, uint256, bytes));

        if (isNonceUsed[consumeFrom][nonce]) revert NonceUsed();
        // todo: check
        if (signature_.length == 0) {
            // If no signature, consumeFrom is appGateway
            return (appGateway, appGateway, isApproved);
        }

        bytes32 digest = keccak256(
            abi.encode(address(this), evmxSlug, consumeFrom, appGateway, nonce, isApproved)
        );
        if (_recoverSigner(digest, signature_) != consumeFrom) revert InvalidUserSignature();
        isAppGatewayWhitelisted[consumeFrom][appGateway] = isApproved;
        isNonceUsed[consumeFrom][nonce] = true;

        return (consumeFrom, appGateway, isApproved);
    }

    /// @notice Withdraws funds to a specified receiver
    /// @dev This function is used to withdraw fees from the fees plug
    /// @dev assumed that transmitter can bid for their request on AM
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param maxFees_ The fees needed for the request
    /// @param receiver_ The address of the receiver
    function withdrawCredits(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        uint256 maxFees_,
        address receiver_
    ) public {
        address consumeFrom = _getCoreAppGateway(msg.sender);

        // Check if amount is available in fees plug
        uint256 availableAmount = getAvailableCredits(consumeFrom);
        if (availableAmount < amount_) revert InsufficientCreditsAvailable();

        userCredits[consumeFrom].totalCredits -= amount_;
        tokenPoolBalances[chainSlug_][token_] -= amount_;

        // Add it to the queue and submit request
        _createRequest(
            chainSlug_,
            consumeFrom,
            maxFees_,
            abi.encodeCall(IFeesPlug.withdrawFees, (token_, receiver_, amount_))
        );
    }

    function _createRequest(
        uint32 chainSlug_,
        address consumeFrom_,
        uint256 maxFees_,
        bytes memory payload_
    ) internal {
        OverrideParams memory overrideParams;
        overrideParams.callType = WRITE;
        overrideParams.gasLimit = 10000000;
        overrideParams.writeFinality = WriteFinality.LOW;

        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;
        queueParams.transaction = Transaction({
            chainSlug: chainSlug_,
            target: _getFeesPlugAddress(chainSlug_),
            payload: payload_
        });
        queueParams.switchboardType = sbType;

        // queue and create request
        watcherPrecompile__().queueAndRequest(
            queueParams,
            maxFees_,
            address(0),
            consumeFrom_,
            bytes("")
        );
    }

    function _getFeesPlugAddress(uint32 chainSlug_) internal view returns (address) {
        return configuration__().feesPlug(chainSlug_);
    }

    function _getRequestParams(uint40 requestCount_) internal view returns (RequestParams memory) {
        return watcher__().getRequestParams(requestCount_);
    }

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }

    /// @notice hook called by watcher precompile when request is finished
    function onRequestComplete(uint40, bytes memory) external {}
}
