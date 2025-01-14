// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SuperTokenDeployer} from "../../contracts/apps/super-token/SuperTokenDeployer.sol";
import {SuperTokenAppGateway} from "../../contracts/apps/super-token/SuperTokenAppGateway.sol";
import {SuperToken} from "../../contracts/apps/super-token/SuperToken.sol";
import "../DeliveryHelper.t.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../../contracts/common/Constants.sol";

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

        (address onChain, address forwarder) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.superToken,
            appContracts.superTokenDeployer
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

        (address onChainArb, address forwarderArb) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.superToken,
            appContracts.superTokenDeployer
        );

        (address onChainOpt, address forwarderOpt) = getOnChainAndForwarderAddresses(
            optChainSlug,
            appContracts.superToken,
            appContracts.superTokenDeployer
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

        uint32[] memory chainSlugs = new uint32[](2);
        chainSlugs[0] = IForwarder(forwarderArb).getChainSlug();
        chainSlugs[1] = IForwarder(forwarderOpt).getChainSlug();
        _executeBatchMultiChain(chainSlugs);

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
