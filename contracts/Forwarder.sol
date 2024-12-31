// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/IAddressResolver.sol";
import "./interfaces/IAuctionHouse.sol";
import "./interfaces/IAppGateway.sol";
import "./interfaces/IPromise.sol";
import "./AsyncPromise.sol";
import "./interfaces/IForwarder.sol";

/// @title Forwarder Contract
/// @notice This contract acts as a forwarder for async calls to the on-chain contracts.
contract Forwarder is IForwarder {
    uint32 immutable chainSlug; // Chain ID
    address immutable onChainAddress; // On-chain address associated with this forwarder
    address immutable addressResolver; // Address resolver contract address for important addresses
    address latestAsyncPromise; // Caches the latest async promise address for the last call

    /// @notice Constructor to initialize the forwarder contract.
    constructor(uint32 chainSlug_, address onChainAddress_, address addressResolver_) {
        chainSlug = chainSlug_;
        onChainAddress = onChainAddress_;
        addressResolver = addressResolver_;
    }

    /// @notice Returns the on-chain address associated with this forwarder.
    function getOnChainAddress() external view returns (address) {
        return onChainAddress;
    }

    /// @notice Returns the chain ID.
    function getChainSlug() external view returns (uint32) {
        return chainSlug;
    }

    /// @notice Stores the callback address and data to be executed once the promise is resolved.
    function then(bytes4 selector, bytes memory data) external returns (address promise_) {
        if (latestAsyncPromise == address(0)) {
            revert("Forwarder: no async promise found");
        }
        require(selector != bytes4(0), "Forwarder: invalid selector"); // Validate selector
        promise_ = IPromise(latestAsyncPromise).then(selector, data);
        latestAsyncPromise = address(0); // Resetting latest promise after use
    }

    /// @notice Fallback function to process the contract calls to onChainAddress.
    fallback() external payable {
        // Retrieve the auction house address from the address resolver.
        address auctionHouse = IAddressResolver(addressResolver).auctionHouse();
        if (auctionHouse == address(0)) {
            revert("Forwarder: auctionHouse not found");
        }

        // Deploy a new async promise contract.
        latestAsyncPromise = IAddressResolver(addressResolver).deployAsyncPromiseContract(msg.sender);

        // Determine if the call is a read or write operation.
        bool isReadCall = IAppGateway(msg.sender).isReadCall();

        // Queue the call in the auction house.
        IAuctionHouse(auctionHouse).queue(
            chainSlug,
            onChainAddress,
            bytes32(uint256(uint160(latestAsyncPromise))),
            isReadCall ? CallType.READ : CallType.WRITE,
            msg.data
        );
    }

    receive() external payable {}
}
