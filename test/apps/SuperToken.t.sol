// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {SuperTokenAppGateway} from "./app-gateways/super-token/SuperTokenAppGateway.sol";
import {SuperToken} from "./app-gateways/super-token/SuperToken.sol";
import "../SetupTest.t.sol";

/**
 * @title SuperToken Test
 * @notice Test contract for verifying the functionality of the SuperToken system, which enables
 * multi-chain token bridging capabilities.
 * @dev Inherits from AppGatewayBaseSetup to utilize multi-chain messaging infrastructure
 *
 * The test suite validates:
 * - Contract deployment across different chains
 * - Token transfers between chains
 * - Proper balance updates
 * - Integration with the delivery and auction system
 */
contract SuperTokenTest is AppGatewayBaseSetup {
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
    address owner = address(uint160(c++));
    uint256 maxFees = 0.01 ether;

    /// @dev Main contracts used throughout the tests
    AppContracts appContracts;
    /// @dev Array storing contract IDs for deployment (currently only SuperToken)
    bytes32[] contractIds = new bytes32[](1);

    /// @dev Test amount for token transfers (0.01 ETH)
    uint256 srcAmount = 0.01 ether;
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
        deploy();

        SuperTokenAppGateway superTokenApp = new SuperTokenAppGateway(
            address(addressResolver),
            owner,
            maxFees,
            SuperTokenAppGateway.ConstructorParams({
                name_: "SUPER TOKEN",
                symbol_: "SUPER",
                decimals_: 18,
                initialSupplyHolder_: owner,
                initialSupply_: 1000000000 ether
            })
        );

        // Enable app gateways to do all operations in the Watcher: Read, Write and Schedule on EVMx
        // Watcher sets the limits for apps in this SOCKET protocol version
        depositNativeAndCredits(arbChainSlug, 1 ether, 0, address(superTokenApp));

        appContracts = AppContracts({
            superTokenApp: superTokenApp,
            superToken: superTokenApp.superToken()
        });

        contractIds[0] = appContracts.superToken;
    }

    /**
     * @notice Deploys the SuperToken application and its components
     * @dev Creates both the deployer and gateway contracts with initial configuration
     * - Sets up SuperToken with "SUPER TOKEN" name and "SUPER" symbol
     * - Configures initial supply of 1 billion tokens
     * - Sets up fee structure and auction manager integration
     */
    function deploySuperToken(uint32 chainSlug) internal {
        appContracts.superTokenApp.deployContracts(chainSlug);
        executeDeploy(IAppGateway(appContracts.superTokenApp), chainSlug, contractIds);
    }

    /**
     * @notice Tests the deployment of SuperToken contracts across chains
     * @dev Verifies:
     * - Correct deployment on target chain (Arbitrum in this case)
     * - Proper initialization of token parameters
     * - Correct setup of forwarder contracts for multi-chain communication
     */
    function testContractDeployment() public {
        deploySuperToken(arbChainSlug);

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
     * @notice Tests multi-chain token transfers
     * @dev Verifies:
     * - Correct token burning on source chain (Arbitrum)
     * - Correct token minting on destination chain (Optimism)
     * - Accurate balance updates on both chains
     * - Proper execution of multi-chain messaging
     */
    function testTransfer() public {
        deploySuperToken(arbChainSlug);
        deploySuperToken(optChainSlug);

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

        transferOrder = SuperTokenAppGateway.TransferOrder({
            srcToken: forwarderArb,
            dstToken: forwarderOpt,
            user: owner,
            srcAmount: srcAmount,
            deadline: block.timestamp + 1000000
        });

        bytes memory encodedOrder = abi.encode(transferOrder);
        appContracts.superTokenApp.transfer(encodedOrder);
        executeRequest();

        assertEq(
            SuperToken(onChainArb).balanceOf(owner),
            arbBalanceBefore - srcAmount,
            "Arb balance should be decreased by srcAmount"
        );
        assertEq(
            SuperToken(onChainOpt).balanceOf(owner),
            optBalanceBefore + srcAmount,
            "Opt balance should be increased by srcAmount"
        );
    }
}
