// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./AuctionHouse.sol";

import {MultichainTokenDeployer} from "../contracts/apps//going-multichain-erc20/MultichainTokenDeployer.sol";
import {MultichainTokenAppGateway} from "../contracts/apps//going-multichain-erc20/MultichainTokenAppGateway.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

contract MultichainTokenTest is AuctionHouseTest {
    uint256 srcAmount = 0.01 ether;

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

        // Deploy Deployer and AppGateway
        deployMultichainTokenApp();
    }

    ////////////////////////
    //   TEST FUNCTIONS   //
    ////////////////////////

    function testContractDeployment() public {
        bytes32[] memory payloadIds = getWritePayloadIds(optChainSlug, getPayloadDeliveryPlug(optChainSlug), 2);

        PayloadDetails[] memory payloadDetails = createDeployPayloadDetailsArray(optChainSlug);

        _deploy(payloadIds, optChainSlug, maxFees, appContracts.multichainTokenDeployer, payloadDetails);
    }

    /////////////////////////
    //  PAYLOAD FUNCTIONS  //
    /////////////////////////

    function createDeployPayloadDetailsArray(uint32 chainSlug_) internal returns (PayloadDetails[] memory) {
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](2);
        payloadDetails[0] = createDeployPayloadDetail(
            chainSlug_,
            address(appContracts.multichainTokenDeployer),
            appContracts.multichainTokenDeployer.creationCodeWithArgs(appContracts.multichainToken)
        );
        payloadDetails[1] = createDeployPayloadDetail(
            chainSlug_,
            address(appContracts.multichainTokenDeployer),
            appContracts.multichainTokenDeployer.creationCodeWithArgs(appContracts.vault)
        );

        for (uint256 i = 0; i < payloadDetails.length; i++) {
            payloadDetails[i].next[1] = predictAsyncPromiseAddress(address(auctionHouse), address(auctionHouse));
            console.log(asyncPromiseCounterLocal, payloadDetails[i].next[1]);
        }

        return payloadDetails;
    }

    ////////////////////////
    //  HELPER FUNCTIONS  //
    ////////////////////////

    function deployMultichainTokenApp() internal {
        MultichainTokenDeployer multichainTokenDeployer = new MultichainTokenDeployer(
            optChainSlug,
            address(token),
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
