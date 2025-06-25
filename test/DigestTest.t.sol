// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {DigestParams} from "../contracts/utils/common/Structs.sol";
import "../contracts/utils/common/Constants.sol";
import "forge-std/console.sol";

contract DigestTest is Test {

    function testCallType() pure public {
        bytes4 READ = bytes4(keccak256("READ"));
        bytes4 WRITE = bytes4(keccak256("WRITE"));
        bytes4 SCHEDULE = bytes4(keccak256("SCHEDULE"));

        console.log("READ");
        console.logBytes4(READ);
        console.log("WRITE");
        console.logBytes4(WRITE);
        console.log("SCHEDULE");
        console.logBytes4(SCHEDULE);
    }

    /**
    emit DigestWithSourceParams(digest: 0xd64549c2e9bc8c443a5e8a5e375c72258a7131088b6fcd0c3297b40a686195b3, digestParams: DigestParams({ socket: 0x84815e8ca2f6dad7e12902c39a51bc72e13c48139b4fb10025d94e7abea2969c, transmitter: 0x138e9840861C983DC0BB9b3e941FB7C0e9Ade320, payloadId: 0x8c60d67962292aec8829ece076feee3bc37b486f9e6939cf56fa4f6bf25553bd, deadline: 1749307926 [1.749e9], callType: 1, gasLimit: 10000000 [1e7], value: 0, payload: 0x0914e65e59622aeeefb7f007aef36df62d4c380895553b0643fcc4383c7c24480af77affb0a5db632e9bafb98525232515d440861c9942e447c20eefd8883d349ded6d20f1f5b9c56cb90ef89fc52d355aaaa868c42738eff11f50d1f81f522a04feb6778939c89983aac734e237dc22f49d7b4418d378a516df15a255d084cb000000000000000000000000000000000000000000000000000000000000000006ddf6e1d765a193d9cbe146ceeb79ac1cb485ed5f5b37913a8cf5857eff00a93339e12fb69289a640420f0000000000, target: 0x55d893e742d43eafc1e6509eefca9ceb635a39bd3394041d334203ed35720922, appGatewayId: 0x000000000000000000000000751085ca028d2bcfc58cee2514def1ed72c843cd, prevDigestsHash: 0x4cfb2ef587acc8ad0cdb441f5b5e0624f7fef9c2fa084f5e93075cdc54d99d8f }))
    */
    function testDigest3() public {
        bytes32 expectedDigest = 0xd64549c2e9bc8c443a5e8a5e375c72258a7131088b6fcd0c3297b40a686195b3;

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
            prevDigestsHash: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        assertEq(uint256(inputDigestParams.callType), uint256(1));

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
                inputDigestParams.prevDigestsHash,
                bytes("")
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
                params_.prevDigestsHash,
                bytes("")
            )
        );
    }
}
