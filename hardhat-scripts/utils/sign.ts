import { ethers } from "ethers";
import { ChainSlug } from "../../src";
import { EVMX_CHAIN_ID } from "../config/config";
import { getProviderFromChainSlug } from "./networks";

export const signWatcherMessage = async (
  encodedMessage: string,
  watcherContractAddress: string
) => {
  const signatureNonce = Date.now();
  const signer = getWatcherSigner();
  const digest = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["address", "uint32", "uint256", "bytes"],
      [watcherContractAddress, EVMX_CHAIN_ID, signatureNonce, encodedMessage]
    )
  );
  const signature = await signer.signMessage(ethers.utils.arrayify(digest));
  return { nonce: signatureNonce, signature };
};

export const getWatcherSigner = () => {
  const provider = getProviderFromChainSlug(EVMX_CHAIN_ID as ChainSlug);
  return new ethers.Wallet(process.env.WATCHER_PRIVATE_KEY as string, provider);
};

export const getSocketSigner = (chainSlug: ChainSlug) => {
  const provider = getProviderFromChainSlug(chainSlug);
  return new ethers.Wallet(process.env.SOCKET_SIGNER_KEY as string, provider);
};
