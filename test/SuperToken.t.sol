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
        bytes32 limitHook;
    }
    AppContracts appContracts;
    bytes32[] contractIds = new bytes32[](2);

    uint256 srcAmount = 0.01 ether;
    SuperTokenAppGateway.UserOrder userOrder;

    function setUp() public {
        // core
        setUpDeliveryHelper();

        // app specific
        deploySuperTokenApp();

        contractIds[0] = appContracts.superToken;
        contractIds[1] = appContracts.limitHook;
    }

    function deploySuperTokenApp() internal {
        SuperTokenDeployer superTokenDeployer = new SuperTokenDeployer(
            address(addressResolver),
            owner,
            address(auctionManager),
            FAST,
            SuperTokenDeployer.ConstructorParams({
                _burnLimit: 10000000000000000000000,
                _mintLimit: 10000000000000000000000,
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
            superToken: superTokenDeployer.superToken(),
            limitHook: superTokenDeployer.limitHook()
        });
    }

    function testContractDeployment() public {
        bytes32 asyncId = _deploy(
            contractIds,
            arbChainSlug,
            2,
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );
    }

    function testConfigure() public {
        writePayloadIdCounter = 0;
        _deploy(
            contractIds,
            arbChainSlug,
            2,
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );

        _configure(arbChainSlug, 1);
    }

    function beforeBridge() internal {
        writePayloadIdCounter = 0;
        _deploy(
            contractIds,
            arbChainSlug,
            2,
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );

        _configure(arbChainSlug, 1);

        _deploy(
            contractIds,
            optChainSlug,
            2,
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );

        _configure(optChainSlug, 1);
    }

    function _bridge() internal returns (bytes32, bytes32[] memory) {
        beforeBridge();

        userOrder = SuperTokenAppGateway.UserOrder({
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
        uint32 srcChainSlug = IForwarder(userOrder.srcToken).getChainSlug();
        uint32 dstChainSlug = IForwarder(userOrder.dstToken).getChainSlug();

        bytes32[] memory payloadIds = new bytes32[](4);
        payloadIds[0] = getWritePayloadId(
            srcChainSlug,
            address(getSocketConfig(srcChainSlug).switchboard),
            writePayloadIdCounter++
        );
        payloadIds[2] = getWritePayloadId(
            dstChainSlug,
            address(getSocketConfig(dstChainSlug).switchboard),
            writePayloadIdCounter++
        );
        writePayloadIdCounter++;
        bytes32 bridgeAsyncId = getCurrentAsyncId();
        asyncCounterTest++;

        bytes memory encodedOrder = abi.encode(userOrder);
        appContracts.superTokenApp.bridge(encodedOrder);
        bidAndEndAuction(bridgeAsyncId);
        return (bridgeAsyncId, payloadIds);
    }

    function testBridge() public {
        (bytes32 bridgeAsyncId, bytes32[] memory payloadIds) = _bridge();
        finalizeAndExecute(bridgeAsyncId, payloadIds[0], false);
        finalizeAndExecute(bridgeAsyncId, payloadIds[1], false);
    }
}
