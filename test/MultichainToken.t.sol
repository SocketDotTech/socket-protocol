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

    function deployMultichainTokenApp() internal {
        MultichainTokenDeployer multichainTokenDeployer = new MultichainTokenDeployer(
            optChainSlug,
            address(token),
            owner,
            "SUPER TOKEN",
            "SUPER",
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

    ////////////////////////
    //  HELPER FUNCTIONS  //
    ////////////////////////

    // To mint tokens for testing to any user if needed
    function mintTokens(address to, uint256 amount) internal {
        token.mint(to, amount);
    }
}
