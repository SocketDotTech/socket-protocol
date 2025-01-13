// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SuperTokenDeployer} from "../contracts/apps/super-token/SuperTokenDeployer.sol";
import {SuperTokenAppGateway} from "../contracts/apps/super-token/SuperTokenAppGateway.sol";
import "./DeliveryHelper.t.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../contracts/common/Constants.sol";

contract SuperTokenTest is DeliveryHelperTest {
    struct AppContracts {
        SuperTokenAppGateway superTokenApp;
        SuperTokenDeployer superTokenDeployer;
        bytes32 superToken;
    }
    AppContracts appContracts;
    bytes32[] contractIds = new bytes32[](1);

    uint256 srcAmount = 0.01 ether;
    SuperTokenAppGateway.TransferOrder transferOrder;

    function setUp() public {
        // core
        setUpDeliveryHelper();

        // app specific
        deploySuperTokenApp();

        contractIds[0] = appContracts.superToken;
    }

    function deploySuperTokenApp() internal {
        SuperTokenDeployer superTokenDeployer = new SuperTokenDeployer(
            address(addressResolver),
            owner,
            address(auctionManager),
            FAST,
            SuperTokenDeployer.ConstructorParams({
                name_: "SUPER TOKEN",
                symbol_: "SUPER",
                decimals_: 18,
                initialSupplyHolder_: owner,
                initialSupply_: 1000000000 ether
            }),
            createFeesData(maxFees)
        );
        SuperTokenAppGateway superTokenApp = new SuperTokenAppGateway(
            address(addressResolver),
            address(superTokenDeployer),
            createFeesData(maxFees),
            address(auctionManager)
        );
        setLimit(address(superTokenApp));

        appContracts = AppContracts({
            superTokenApp: superTokenApp,
            superTokenDeployer: superTokenDeployer,
            superToken: superTokenDeployer.superToken()
        });
    }

    function testContractDeployment() public {
        _deploy(
            contractIds,
            arbChainSlug,
            1,
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );
    }

    function beforeTransfer() internal {
        writePayloadIdCounter = 0;
        _deploy(
            contractIds,
            arbChainSlug,
            1,
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );

        _deploy(
            contractIds,
            optChainSlug,
            1,
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );
    }

    function testTransfer() public {
        beforeTransfer();

        transferOrder = SuperTokenAppGateway.TransferOrder({
            srcToken: appContracts.superTokenDeployer.forwarderAddresses(
                appContracts.superToken,
                arbChainSlug
            ),
            dstToken: appContracts.superTokenDeployer.forwarderAddresses(
                appContracts.superToken,
                optChainSlug
            ),
            user: owner, // 2 account anvil
            srcAmount: srcAmount, // .01 ETH in wei
            deadline: 1672531199 // Unix timestamp for a future date
        });
        bytes memory encodedOrder = abi.encode(transferOrder);
        appContracts.superTokenApp.transfer(encodedOrder);

        uint32[] memory chainSlugs = new uint32[](2);
        chainSlugs[0] = IForwarder(transferOrder.srcToken).getChainSlug();
        chainSlugs[1] = IForwarder(transferOrder.dstToken).getChainSlug();
        _executeBatchMultiChain(chainSlugs);
    }
}
