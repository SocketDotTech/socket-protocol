// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcherPrecompile.sol";
import "../../interfaces/IFeesManager.sol";
import "../../interfaces/IMiddleware.sol";
import "../../libs/PayloadHeaderDecoder.sol";
import "../../core/WatcherIdUtils.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";

/// @title Finalize
/// @notice Library that handles finalization logic for the WatcherPrecompile system
/// @dev This library contains pure functions for finalization operations
library Finalize {
    using PayloadHeaderDecoder for bytes32;

    /// @notice Calculates the digest hash of payload parameters
    /// @param params_ The payload parameters to calculate the digest for
    /// @return digest The calculated digest hash
    /// @dev This function creates a keccak256 hash of the payload parameters
    function getDigest(DigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            abi.encode(
                params_.socket,
                params_.transmitter,
                params_.payloadId,
                params_.deadline,
                params_.callType,
                params_.gasLimit,
                params_.value,
                params_.payload,
                params_.target,
                params_.appGatewayId,
                params_.prevDigestsHash,
                bytes("")
            )
        );
    }

    /// @notice Prepares the parameters needed for finalization
    /// @param params_ The payload parameters to be finalized
    /// @param transmitter_ The address of the transmitter
    /// @param chainSlug The chain slug where the finalization is happening
    /// @param evmxSlug The EVMx chain slug
    /// @param deadline The deadline for the finalization
    /// @param socketsAddress The address of the sockets contract
    /// @param middleware The address of the middleware contract
    /// @param prevDigestsHash The hash of previous batch digests
    /// @return digestParams The digest parameters for the finalization
    function prepareDigestParams(
        PayloadParams memory params_,
        address transmitter_,
        uint32 chainSlug,
        uint32 evmxSlug,
        uint256 deadline,
        address socketsAddress,
        address middleware,
        bytes32 prevDigestsHash
    ) public pure returns (DigestParams memory digestParams) {
        // Verify that the app gateway is properly configured for this chain and target
        // This verification would happen in the storage contract

        // Construct parameters for digest calculation
        digestParams = DigestParams(
            socketsAddress,
            transmitter_,
            params_.payloadId,
            deadline,
            params_.payloadHeader.getCallType(),
            params_.gasLimit,
            params_.value,
            params_.payload,
            params_.target,
            WatcherIdUtils.encodeAppGatewayId(params_.appGateway),
            prevDigestsHash
        );
    }

    /// @notice Processes the finalization of a proof
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    /// @param signatureData Encoded signature data for verification
    /// @return The verification result indicating whether the finalization was successful
    function processFinalization(
        bytes32 payloadId_,
        bytes memory proof_,
        bytes memory signatureData
    ) public pure returns (bool) {
        // This is just the logic for processing finalization
        // Actual storage updates would happen in the storage contract

        // The return value indicates whether the verification was successful
        // In the actual implementation, this would be used to determine whether to update storage
        return signatureData.length > 0 && proof_.length > 0 && payloadId_ != bytes32(0);
    }

    /// @notice Creates the event data for finalization
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    /// @return The encoded event data for finalization
    function createFinalizedEventData(
        bytes32 payloadId_,
        bytes memory proof_
    ) public pure returns (bytes memory) {
        return abi.encode(payloadId_, proof_);
    }
}
