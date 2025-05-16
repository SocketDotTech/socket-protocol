// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./FeesStorage.sol";

/// @title UserUtils
/// @notice Contract for managing user utils
abstract contract UserUtils is FeesStorage, Initializable, Ownable, AddressResolverUtil {
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

    /// @notice Adds the fees deposited for an app gateway on a chain
    /// @param depositTo_ The app gateway address
    // @dev only callable by watcher precompile
    // @dev will need tokenAmount_ and creditAmount_ when introduce tokens except stables
    function depositCredits(
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

    function wrap() external payable {
        UserCredits storage userCredit = userCredits[msg.sender];
        userCredit.totalCredits += msg.value;
        emit CreditsWrapped(msg.sender, msg.value);
    }

    function unwrap(uint256 amount_) external {
        UserCredits storage userCredit = userCredits[msg.sender];
        if (userCredit.totalCredits < amount_) revert InsufficientCreditsAvailable();
        userCredit.totalCredits -= amount_;

        // todo: if contract balance not enough, take from our pool?
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
    /// @param consumeFrom_ The app gateway address
    /// @param appGateway_ The app gateway address
    /// @param amount_ The amount
    /// @return True if the user has enough credits, false otherwise
    function isUserCreditsEnough(
        address consumeFrom_,
        address appGateway_,
        uint256 amount_
    ) external view returns (bool) {
        // If consumeFrom is not appGateway, check if it is whitelisted
        if (consumeFrom_ != appGateway_ && !isAppGatewayWhitelisted[consumeFrom_][appGateway_])
            revert AppGatewayNotWhitelisted();
        return getAvailableCredits(consumeFrom_) >= amount_;
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
        (address consumeFrom, address appGateway, bool isApproved, bytes memory signature_) = abi
            .decode(feeApprovalData_, (address, address, bool, bytes));

        if (signature_.length == 0) {
            // If no signature, consumeFrom is appGateway
            return (appGateway, appGateway, isApproved);
        }
        bytes32 digest = keccak256(
            abi.encode(
                address(this),
                evmxSlug,
                consumeFrom,
                appGateway,
                userNonce[consumeFrom],
                isApproved
            )
        );
        if (_recoverSigner(digest, signature_) != consumeFrom) revert InvalidUserSignature();
        isAppGatewayWhitelisted[consumeFrom][appGateway] = isApproved;
        userNonce[consumeFrom]++;

        return (consumeFrom, appGateway, isApproved);
    }

    /// @notice Withdraws funds to a specified receiver
    /// @dev This function is used to withdraw fees from the fees plug
    /// @param originAppGatewayOrUser_ The address of the app gateway
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param receiver_ The address of the receiver
    function withdrawCredits(
        address originAppGatewayOrUser_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        uint256 maxFees_,
        address receiver_
    ) public {
        if (msg.sender != address(deliveryHelper__())) originAppGatewayOrUser_ = msg.sender;
        address source = _getCoreAppGateway(originAppGatewayOrUser_);

        // Check if amount is available in fees plug
        uint256 availableAmount = getAvailableCredits(source);
        if (availableAmount < amount_) revert InsufficientCreditsAvailable();

        _useAvailableUserCredits(source, amount_);
        tokenPoolBalances[chainSlug_][token_] -= amount_;

        // Add it to the queue and submit request
        _createRequest(
            chainSlug_,
            msg.sender,
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
        QueueParams memory queueParams = QueueParams({
            overrideParams: OverrideParams({
                isPlug: IsPlug.NO,
                callType: WRITE,
                isParallelCall: Parallel.OFF,
                gasLimit: 10000000,
                value: 0,
                readAtBlockNumber: 0,
                writeFinality: WriteFinality.LOW,
                delayInSeconds: 0
            }),
            transaction: Transaction({
                chainSlug: chainSlug_,
                target: _getFeesPlugAddress(chainSlug_),
                payload: payload_
            }),
            asyncPromise: address(0),
            switchboardType: sbType
        });

        // queue and create request
        watcherPrecompile__().queueAndRequest(
            queueParams,
            maxFees_,
            address(0),
            consumeFrom_,
            bytes("")
        );
    }

    /// @notice hook called by watcher precompile when request is finished
    function onRequestComplete(uint40 requestCount_, bytes memory) external {}

    function _getFeesPlugAddress(uint32 chainSlug_) internal view returns (address) {
        return watcherPrecompileConfig().feesPlug(chainSlug_);
    }

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }
}
