pragma solidity ^0.8.13;

/// @title IAppDeployer
/// @notice Interface for the app deployer
interface IAppDeployer {
    /// @notice Sets the forwarder contract
    /// @param chainSlug_ The chain slug
    /// @param forwarderContractAddr_ The forwarder contract address
    /// @param contractId_ The contract ID
    function setForwarderContract(
        uint32 chainSlug,
        address forwarderContractAddr,
        bytes32 contractId
    ) external;

    /// @notice initialize the contracts on chain
    function initialize(uint32 chainSlug) external;

    /// @notive deploy contracts to chain
    function deployContracts(uint32 chainSlug) external;
}
