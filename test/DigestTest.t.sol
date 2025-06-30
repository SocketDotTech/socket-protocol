// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {DigestParams} from "../contracts/utils/common/Structs.sol";
import "../contracts/utils/common/Constants.sol";
import "forge-std/console.sol";

contract DigestTest is Test {
    function testCallType() public pure {
        console.log("READ");
        console.logBytes4(READ);
        console.log("WRITE");
        console.logBytes4(WRITE);
        console.log("SCHEDULE");
        console.logBytes4(SCHEDULE);

        bytes32 superTokenEvm = keccak256(abi.encode("superTokenEvm"));
        console.log("superTokenEvm");
        console.logBytes32(superTokenEvm);
    }

    function testDigest() public pure {
        bytes32 expectedDigest = 0xc26b01718c6f97b51ad73743bb5b1ac2abb53966d15a2948f65db43b30cce1a1;

        DigestParams memory inputDigestParams = DigestParams({
            socket: 0x84815e8ca2f6dad7e12902c39a51bc72e13c48139b4fb10025d94e7abea2969c,
            transmitter: 0x138e9840861C983DC0BB9b3e941FB7C0e9Ade320,
            payloadId: 0x965c0b8c6c5c8dc6f433b34b72ecddcec35b2f36f700f50aed20a40366efa88a,
            deadline: 1750681840,
            callType: WRITE,
            gasLimit: 10000000,
            value: 0,
            payload: hex"0914e65e59622aeeefb7f007aef36df62d4c380895553b0643fcc4383c7c24480af77affb0a5db632e9bafb98525232515d440861c9942e447c20eefd8883d349ded6d20f1f5b9c56cb90ef89fc52d355aaaa868c42738eff11f50d1f81f522a04feb6778939c89983aac734e237dc22f49d7b4418d378a516df15a255d084cb000000000000000000000000000000000000000000000000000000000000000006ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a93339e12fb69289a640420f0000000000",
            // TODO: fix with correct super-token program id
            target: 0x0914e65e59622aeeefb7f007aef36df62d4c380895553b0643fcc4383c7c2448,
            appGatewayId: 0x0000000000000000000000004530a440dcc32206f901325143132da1edb8d2e9,
            // prevDigestsHash: 0x4cfb2ef587acc8ad0cdb441f5b5e0624f7fef9c2fa084f5e93075cdc54d99d8f
            prevBatchDigestHash: 0x0000000000000000000000000000000000000000000000000000000000000000,
            extraData: bytes("")
        });

        bytes memory packedParams = abi.encodePacked(
            inputDigestParams.socket,
            inputDigestParams.transmitter,
            inputDigestParams.payloadId,
            inputDigestParams.deadline,
            inputDigestParams.callType,
            inputDigestParams.gasLimit,
            inputDigestParams.value,
            inputDigestParams.payload,
            inputDigestParams.target,
            inputDigestParams.appGatewayId,
            inputDigestParams.prevBatchDigestHash,
            inputDigestParams.extraData
        );
        console.log("packedParams");
        console.logBytes(packedParams);

        bytes32 actualDigest = getDigest(inputDigestParams);
        assertEq(actualDigest, expectedDigest);
    }

    // taken from WatcherPrecompileCore.getDigest()
    function getDigest(DigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            abi.encodePacked(
                params_.socket,
                params_.transmitter,
                params_.payloadId,
                params_.deadline,
                params_.callType,
                params_.gasLimit,
                params_.value,
                params_.payload,
                params_.target,
                params_.appGatewayId,
                params_.prevBatchDigestHash,
                params_.extraData
            )
        );
    }
}
