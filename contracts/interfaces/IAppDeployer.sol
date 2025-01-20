pragma solidity ^0.8.13;

/// @title IAppDeployer
/// @notice Interface for the app deployer
interface IAppDeployer {
    /// @notice initialize the contracts on chain
    function initialize(uint32 chainSlug_) external;

    /// @notice deploy contracts to chain
    function deployContracts(uint32 chainSlug_) external;

    /// @notice get the on-chain address of a contract
    function getOnChainAddress(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (address onChainAddress);

    /// @notice get the forwarder address of a contract
    function forwarderAddresses(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (address forwarderAddress);
}
