// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SuperTokenAppGateway} from "./app-gateways/super-token-op/SuperTokenAppGateway.sol";
import {SuperToken} from "./app-gateways/super-token-op/SuperToken.sol";
import "../DeliveryHelper.t.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../../contracts/protocol/utils/common/Constants.sol";

/**
 * @title SuperToken Test
 * @notice Test contract for verifying the functionality of the SuperToken system, which enables
 * multi-chain token bridging capabilities.
 * @dev Inherits from DeliveryHelperTest to utilize multi-chain messaging infrastructure
 *
 * The test suite validates:
 * - Contract deployment across different chains
 * - Token transfers between chains
 * - Proper balance updates
 * - Integration with the delivery and auction system
 */
contract SuperTokenTest is DeliveryHelperTest {
    /**
     * @notice Groups the main contracts needed for SuperToken functionality
     * @param superTokenApp The gateway contract that handles multi-chain token operations
     * @param superTokenDeployer Contract responsible for deploying SuperToken instances
     * @param superToken Identifier for the SuperToken contract
     */
    struct AppContracts {
        SuperTokenAppGateway superTokenApp;
        bytes32 superToken;
    }

    /// @dev Main contracts used throughout the tests
    AppContracts appContracts;
    /// @dev Array storing contract IDs for deployment (currently only SuperToken)
    bytes32[] contractIds = new bytes32[](1);

    /// @dev Test amount for token transfers (0.01 ETH)
    uint256 amount = 0.01 ether;
    /// @dev Structure holding transfer order details
    SuperTokenAppGateway.TransferOrder transferOrder;

    /**
     * @notice Sets up the test environment
     * @dev Initializes core infrastructure and deploys SuperToken-specific contracts
     * Sequence:
     * 1. Sets up delivery helper for multi-chain communication
     * 2. Deploys SuperToken application
     * 3. Initializes contract IDs array
     */
    function setUp() public {
        setUpDeliveryHelper();
        deploySuperTokenApp();
        contractIds[0] = appContracts.superToken;
    }

    /**
     * @notice Deploys the SuperToken application and its components
     * @dev Creates both the deployer and gateway contracts with initial configuration
     * - Sets up SuperToken with "SUPER TOKEN" name and "SUPER" symbol
     * - Configures initial supply of 1 billion tokens
     * - Sets up fee structure and auction manager integration
     */
    function deploySuperTokenApp() internal {
        SuperTokenAppGateway superTokenApp = new SuperTokenAppGateway(
            address(addressResolver),
            owner,
            createFees(maxFees)
        );
        // Enable app gateways to do all operations in the Watcher: Read, Write and Schedule on EVMx
        // Watcher sets the limits for apps in this SOCKET protocol version
        depositFees(address(superTokenApp), createFees(1 ether));

        appContracts = AppContracts({
            superTokenApp: superTokenApp,
            superToken: superTokenApp.superToken()
        });
    }

    /**
     * @notice Tests the deployment of SuperToken contracts across chains
     * @dev Verifies:
     * - Correct deployment on target chain (Arbitrum in this case)
     * - Proper initialization of token parameters
     * - Correct setup of forwarder contracts for multi-chain communication
     */
    function testContractDeployment() public {
        _deploy(contractIds, arbChainSlug, 1, IAppGateway(appContracts.superTokenApp));

        (address onChain, address forwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.superToken,
            IAppGateway(appContracts.superTokenApp)
        );

        assertEq(
            SuperToken(onChain).name(),
            "SUPER TOKEN",
            "OnChain SuperToken name should be SUPER TOKEN"
        );
        assertEq(
            IForwarder(forwarder).getChainSlug(),
            arbChainSlug,
            "Forwarder SuperToken chainSlug should be arbChainSlug"
        );
        assertEq(
            IForwarder(forwarder).getOnChainAddress(),
            onChain,
            "Forwarder SuperToken onChainAddress should be correct"
        );
        assertEq(SuperToken(onChain).owner(), owner, "SuperToken owner should be correct");
    }

    /**
     * @notice Helper function to prepare the environment for transfer tests
     * @dev Deploys necessary contracts on both Arbitrum and Optimism chains
     */
    function beforeTransfer() internal {
        _deploy(contractIds, arbChainSlug, 1, IAppGateway(appContracts.superTokenApp));
        _deploy(contractIds, optChainSlug, 1, IAppGateway(appContracts.superTokenApp));
    }

    /**
     * @notice Tests multi-chain token transfers
     * @dev Verifies:
     * - Correct token burning on source chain (Arbitrum)
     * - Correct token minting on destination chain (Optimism)
     * - Accurate balance updates on both chains
     * - Proper execution of multi-chain messaging
     */
    function testTransfer() public {
        beforeTransfer();

        (address onChainArb, address forwarderArb) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.superToken,
            IAppGateway(appContracts.superTokenApp)
        );

        (address onChainOpt, address forwarderOpt) = getOnChainAndForwarderAddresses(
            optChainSlug,
            appContracts.superToken,
            IAppGateway(appContracts.superTokenApp)
        );

        uint256 arbBalanceBefore = SuperToken(onChainArb).balanceOf(owner);
        uint256 optBalanceBefore = SuperToken(onChainOpt).balanceOf(owner);

        hoax(owner);
        getSocketConfig(optChainSlug).switchboard.setToken(onChainOpt);
        getSocketConfig(optChainSlug).switchboard.syncIn(owner, amount);

        transferOrder = SuperTokenAppGateway.TransferOrder({
            srcToken: forwarderArb,
            dstToken: forwarderOpt,
            user: owner,
            amount: amount,
            deadline: block.timestamp + 1000000
        });
        bytes memory encodedOrder = abi.encode(transferOrder);
        appContracts.superTokenApp.transfer(encodedOrder);

        uint32[] memory chainSlugs = new uint32[](2);
        chainSlugs[0] = IForwarder(forwarderArb).getChainSlug();
        chainSlugs[1] = IForwarder(forwarderOpt).getChainSlug();
        // You can run the function below whenever you want to simulate the onchain execution for
        // the txs in batch of the current asyncId. It bids, finalises, relays and resolves promises
        _executeWriteBatchMultiChain(chainSlugs);

        assertEq(
            SuperToken(onChainArb).balanceOf(owner),
            arbBalanceBefore - amount,
            "Arb balance should be decreased by amount"
        );
        assertEq(
            SuperToken(onChainOpt).balanceOf(owner),
            optBalanceBefore + amount,
            "Opt balance should be increased by amount"
        );
    }
}
