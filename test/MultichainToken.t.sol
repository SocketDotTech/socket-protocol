// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./AuctionHouse.sol";

import {MultichainTokenDeployer} from "../contracts/apps//going-multichain-erc20/MultichainTokenDeployer.sol";
import {MultichainTokenAppGateway} from "../contracts/apps//going-multichain-erc20/MultichainTokenAppGateway.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

contract MultichainTokenTest is AuctionHouseTest {
    uint256 srcAmount = 0.01 ether;
    uint32 baseChainSlug = optChainSlug;
    address baseTokenAddress;

    MockERC20 public token;

    struct AppContracts {
        MultichainTokenAppGateway multichainTokenApp;
        MultichainTokenDeployer multichainTokenDeployer;
        bytes32 multichainToken;
        bytes32 vault;
    }

    AppContracts appContracts;
    MultichainTokenAppGateway.UserOrder userOrder;

    event BatchCancelled(bytes32 indexed asyncId);
    event FinalizeRequested(bytes32 indexed payloadId, AsyncRequest asyncRequest);

    function setUp() public {
        // set up infrastructure
        setUpAuctionHouse();

        // Deploy mock ERC20
        token = new MockERC20("Mock Token", "MCK", 18);
        token.mint(address(this), 1000 * 10 ** 18);
        baseTokenAddress = address(token);

        // Deploy Deployer and AppGateway
        deployMultichainTokenApp();
    }

    ////////////////////////
    //   TEST FUNCTIONS   //
    ////////////////////////

    function testVaultDeployment() public {
        bytes32[] memory payloadIds = getWritePayloadIds(baseChainSlug, getPayloadDeliveryPlug(baseChainSlug), 1);

        PayloadDetails[] memory payloadDetails = createDeployPayloadDetailsArray(baseChainSlug);

        _deploy(payloadIds, baseChainSlug, maxFees, appContracts.multichainTokenDeployer, payloadDetails);
    }

    function testTokenDeployment() public {
        bytes32[] memory payloadIds = getWritePayloadIds(arbChainSlug, getPayloadDeliveryPlug(arbChainSlug), 1);

        PayloadDetails[] memory payloadDetails = createDeployPayloadDetailsArray(arbChainSlug);

        _deploy(payloadIds, arbChainSlug, maxFees, appContracts.multichainTokenDeployer, payloadDetails);
    }

    function testBridgeSameChain() public {
        // Deploy contracts on both chains
        testVaultDeployment();
        testTokenDeployment();
        // Mint tokens to user1
        // Create bridge order
        // Build bridge payload
        // Bridge transaction
    }
    /////////////////////////
    //  PAYLOAD FUNCTIONS  //
    /////////////////////////

    function createDeployPayloadDetailsArray(uint32 chainSlug) internal returns (PayloadDetails[] memory) {
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        if (chainSlug == baseChainSlug) {
            payloadDetails[0] = createDeployPayloadDetail(
                chainSlug,
                address(appContracts.multichainTokenDeployer),
                appContracts.multichainTokenDeployer.creationCodeWithArgs(appContracts.vault)
            );
        } else {
            payloadDetails[0] = createDeployPayloadDetail(
                chainSlug,
                address(appContracts.multichainTokenDeployer),
                appContracts.multichainTokenDeployer.creationCodeWithArgs(appContracts.multichainToken)
            );
        }

        payloadDetails[0].next[1] = predictAsyncPromiseAddress(address(auctionHouse), address(auctionHouse));

        return payloadDetails;
    }

    ////////////////////////
    //  HELPER FUNCTIONS  //
    ////////////////////////

    function deployMultichainTokenApp() internal {
        MultichainTokenDeployer multichainTokenDeployer = new MultichainTokenDeployer(
            baseChainSlug,
            baseTokenAddress,
            owner,
            "Mock Token",
            "MCK",
            18,
            address(addressResolver),
            createFeesData(maxFees)
        );

        MultichainTokenAppGateway multichainTokenApp = new MultichainTokenAppGateway(
            address(addressResolver), address(multichainTokenDeployer), createFeesData(maxFees)
        );

        appContracts = AppContracts({
            multichainTokenApp: multichainTokenApp,
            multichainTokenDeployer: multichainTokenDeployer,
            multichainToken: multichainTokenDeployer.multichainToken(),
            vault: multichainTokenDeployer.vault()
        });
    }

    // To mint tokens for testing to any user if needed
    function mintTokens(address to, uint256 amount) internal {
        token.mint(to, amount);
    }
}
