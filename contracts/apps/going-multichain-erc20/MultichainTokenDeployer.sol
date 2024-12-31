// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "solady/auth/Ownable.sol";
import "../../interfaces/IAddressResolver.sol";
import "../../base/AppDeployerBase.sol";
import "./MultichainToken.sol";
import "./Vault.sol";

/**
 * @title MultichainTokenDeployer
 * @notice A contract for deploying MultichainToken across multiple chains
 * @dev Extends AppDeployerBase and Ownable to provide cross-chain token deployment functionality
 */
contract MultichainTokenDeployer is AppDeployerBase, Ownable {
    /**
     * @notice Unique identifier for the MultichainToken contract
     * @dev Used to track and manage the MultichainToken contract across different chains
     */
    bytes32 public immutable multichainToken = _createContractId("multichainToken");
    bytes32 public immutable vault = _createContractId("vault");
    uint32 public baseChainSlug;
    address public baseTokenAddress;

    /**
     * @notice Constructor to initialize the MultichainTokenDeployer
     * @param baseChainSlug_ Chain ID of the original ERC20 already deployed
     * @param baseTokenAddress_ Token address of the original ERC20 already deployed
     * @param addressResolver Address of the address resolver contract
     * @param owner Address of the contract owner
     * @param name Name of the token to be deployed
     * @param symbol Symbol of the token to be deployed
     * @param decimals Number of decimals for the token
     * @param feesData Struct containing fee-related data for deployment
     * @dev Sets up the contract with token creation code and initializes ownership
     */
    constructor(
        uint32 baseChainSlug_,
        address baseTokenAddress_,
        address owner,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address addressResolver,
        FeesData memory feesData
    ) AppDeployerBase(addressResolver) Ownable() {
        baseChainSlug = baseChainSlug_;
        baseTokenAddress = baseTokenAddress_;

        _initializeOwner(owner);

        creationCodeWithArgs[multichainToken] =
            abi.encodePacked(type(MultichainToken).creationCode, abi.encode(name, symbol, decimals));

        creationCodeWithArgs[vault] = abi.encodePacked(type(Vault).creationCode, abi.encode(owner, baseTokenAddress_));

        _setFeesData(feesData);

        IAddressResolver(addressResolver).deployForwarderContract(address(this), baseTokenAddress, baseChainSlug);
    }

    /**
     * @notice Deploys the MultichainToken contract on a specified chain
     * @param chainSlug The unique identifier of the target blockchain
     * @dev Triggers the deployment of the MultichainToken contract
     * @custom:modifier Accessible to contract owner or authorized deployers
     */
    function deployContracts(uint32 chainSlug) external async {
        if (chainSlug == baseChainSlug) {
            _deploy(vault, chainSlug);
        } else {
            _deploy(multichainToken, chainSlug);
        }
    }

    /**
     * @notice Initialization function for post-deployment setup
     * @param chainSlug The unique identifier of the blockchain
     * @dev Overrides the initialize function from AppDeployerBase
     * @notice This function is automatically called after all contracts are deployed
     * @dev Currently implemented as a no-op, can be extended for additional initialization logic
     * @custom:note Automatically triggered via AppDeployerBase.allPayloadsExecuted or AppGateway.queueAndDeploy
     */
    function initialize(uint32 chainSlug) public override async {}
}
