pragma solidity ^0.8.13;

/// @title IAppDeployer
/// @notice Interface for the app deployer
interface IAppDeployer {
    /// @notice initialize the contracts on chain
    function initialize(uint32 chainSlug) external;

    /// @notice deploy contracts to chain
    function deployContracts(uint32 chainSlug) external;

    /// @notice get the on-chain address of a contract
    function getOnChainAddress(
        bytes32 contractId,
        uint32 chainSlug
    ) external view returns (address onChainAddress);
}
