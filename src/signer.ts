import { ethers } from "ethers";

export const signWatcherMultiCallMessage = async (
  watcherContractAddress: string,
  evmxChainId: number,
  targetContractAddress: string,
  calldata: string,
  signer: ethers.Signer
) => {
  const signatureNonce = Date.now();
  const digest = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["address", "uint32", "uint256", "address", "bytes"],
      [
        watcherContractAddress,
        evmxChainId,
        signatureNonce,
        targetContractAddress,
        calldata,
      ]
    )
  );
  const signature = await signer.signMessage(ethers.utils.arrayify(digest));
  return { nonce: signatureNonce, signature };
};
