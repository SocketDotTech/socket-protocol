// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IPrecompile.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";
import "../../../utils/RescueFundsLib.sol";
import "../WatcherBase.sol";

/// @title Read
/// @notice Handles read precompile logic
contract ReadPrecompile is IPrecompile, WatcherBase {
    /// @notice Emitted when a new read is requested
    event ReadRequested(Transaction transaction, uint256 readAtBlockNumber, bytes32 payloadId);
    event ExpiryTimeSet(uint256 expiryTime);
    event ReadFeesSet(uint256 readFees);

    /// @notice The fees for a read and includes callback fees
    uint256 public readFees;
    uint256 public expiryTime;

    constructor(address watcher_, uint256 readFees_, uint256 expiryTime_) {
        readFees = readFees_;
        expiryTime = expiryTime_;
        _initializeWatcher(watcher_);
    }

    function getPrecompileFees(bytes memory) public view returns (uint256) {
        return readFees;
    }

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queueParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return estimatedFees Estimated fees required for processing
    function validateAndGetPrecompileData(
        QueueParams calldata queueParams_,
        address
    ) external view returns (bytes memory precompileData, uint256 estimatedFees) {
        if (queueParams_.transaction.target == address(0)) revert InvalidTarget();
        if (queueParams_.transaction.payload.length == 0) revert InvalidPayloadSize();

        // For read precompile, encode the payload parameters
        precompileData = abi.encode(
            queueParams_.transaction,
            queueParams_.overrideParams.readAtBlockNumber
        );
        estimatedFees = getPrecompileFees(precompileData);
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    /// @return deadline The deadline for the payload
    function handlePayload(
        address,
        PayloadParams calldata payloadParams
    )
        external
        onlyRequestHandler
        returns (uint256 fees, uint256 deadline, bytes memory precompileData)
    {
        deadline = block.timestamp + expiryTime;
        precompileData = payloadParams.precompileData;
        fees = getPrecompileFees(payloadParams.precompileData);

        (Transaction memory transaction, uint256 readAtBlockNumber) = abi.decode(
            payloadParams.precompileData,
            (Transaction, uint256)
        );
        emit ReadRequested(transaction, readAtBlockNumber, payloadParams.payloadId);
    }

    function resolvePayload(PayloadParams calldata payloadParams_) external onlyRequestHandler {}

    function setFees(uint256 readFees_) external onlyWatcher {
        readFees = readFees_;
        emit ReadFeesSet(readFees_);
    }

    /// @notice Sets the expiry time for payload execution
    /// @param expiryTime_ The expiry time in seconds
    /// @dev This function sets the expiry time for payload execution
    /// @dev Only callable by the contract owner
    function setExpiryTime(uint256 expiryTime_) external onlyWatcher {
        expiryTime = expiryTime_;
        emit ExpiryTimeSet(expiryTime_);
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(address token_, address rescueTo_, uint256 amount_) external onlyWatcher {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
