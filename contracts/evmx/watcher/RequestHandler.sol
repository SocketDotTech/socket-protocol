// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcherPrecompile.sol";
import "../../libs/PayloadHeaderDecoder.sol";
import "../../utils/common/Structs.sol";
import "../../utils/common/Errors.sol";

/// @title RequestHandler
/// @notice Contract that handles request processing and management
/// @dev This contract interacts with the WatcherPrecompileStorage for storage access
contract RequestHandler {
    using PayloadHeaderDecoder for bytes32;

    // The address of the WatcherPrecompileStorage contract
    address public watcherStorage;

    // Only WatcherPrecompileStorage can call functions
    modifier onlyWatcherStorage() {
        require(msg.sender == watcherStorage, "Only WatcherStorage can call");
        _;
    }

    /// @notice Sets the WatcherPrecompileStorage address
    /// @param watcherStorage_ The address of the WatcherPrecompileStorage contract
    constructor(address watcherStorage_) {
        watcherStorage = watcherStorage_;
    }

    /// @notice Updates the WatcherPrecompileStorage address
    /// @param watcherStorage_ The new address of the WatcherPrecompileStorage contract
    function setWatcherStorage(address watcherStorage_) external onlyWatcherStorage {
        watcherStorage = watcherStorage_;
    }

    /// @notice Increases the fees for a request if no bid is placed
    /// @param requestCount_ The ID of the request
    /// @param newMaxFees_ The new maximum fees
    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) external override {
        address appGateway = _getCoreAppGateway(msg.sender);
        // todo: should we allow core app gateway too?
        if (appGateway != requests[requestCount_].appGateway) {
            revert OnlyAppGateway();
        }
        if (requests[requestCount_].winningBid.transmitter != address(0)) revert WinningBidExists();
        if (requests[requestCount_].maxFees >= newMaxFees_)
            revert NewMaxFeesLowerThanCurrent(requests[requestCount_].maxFees, newMaxFees_);
        requests[requestCount_].maxFees = newMaxFees_;
        emit FeesIncreased(appGateway, requestCount_, newMaxFees_);
    }

    /// @notice Updates the transmitter for a request
    /// @param requestCount The request count to update
    /// @param transmitter The new transmitter address
    /// @dev This function updates the transmitter for a request
    /// @dev It verifies that the caller is the middleware and that the request hasn't been started yet
    function updateTransmitter(uint40 requestCount, address transmitter) public {
        RequestParams storage r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestCancelled();
        if (r.payloadsRemaining == 0) revert RequestAlreadyExecuted();
        if (r.middleware != msg.sender) revert InvalidCaller();
        if (r.transmitter != address(0)) revert RequestNotProcessing();
        r.transmitter = transmitter;

        _processBatch(requestCount, r.currentBatch);
    }

    /// @notice Cancels a request
    /// @param requestCount The request count to cancel
    /// @dev This function cancels a request
    /// @dev It verifies that the caller is the middleware and that the request hasn't been cancelled yet
    function cancelRequest(uint40 requestCount) external {
        RequestParams storage r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestAlreadyCancelled();
        if (r.middleware != msg.sender) revert InvalidCaller();

        r.isRequestCancelled = true;
        emit RequestCancelledFromGateway(requestCount);
    }

    /// @notice Ends the timeouts and calls the target address with the callback payload
    /// @param timeoutId_ The unique identifier for the timeout
    /// @param signatureNonce_ The nonce used in the watcher's signature
    /// @param signature_ The watcher's signature
    /// @dev It verifies if the signature is valid and the timeout hasn't been resolved yet
    function resolveTimeout(
        bytes32 timeoutId_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.resolveTimeout.selector, timeoutId_),
            signatureNonce_,
            signature_
        );

        TimeoutRequest storage timeoutRequest_ = timeoutRequests[timeoutId_];
        if (timeoutRequest_.target == address(0)) revert InvalidTimeoutRequest();
        if (timeoutRequest_.isResolved) revert TimeoutAlreadyResolved();
        if (block.timestamp < timeoutRequest_.executeAt) revert ResolvingTimeoutTooEarly();

        (bool success, , bytes memory returnData) = timeoutRequest_.target.tryCall(
            0,
            gasleft(),
            0, // setting max_copy_bytes to 0 as not using returnData right now
            timeoutRequest_.payload
        );
        if (!success) revert CallFailed();

        timeoutRequest_.isResolved = true;
        timeoutRequest_.executedAt = block.timestamp;

        emit TimeoutResolved(
            timeoutId_,
            timeoutRequest_.target,
            timeoutRequest_.payload,
            block.timestamp,
            returnData
        );
    }
}
