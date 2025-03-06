import { ethers, Wallet } from "ethers";
import { EVMX_CHAIN_ID, mode } from "../config/config";
import { EVMxCoreContracts } from "../constants";
import { getAddresses } from "./address";
import { getProviderFromChainSlug } from "./networks";
import { ChainSlug } from "@socket.tech/socket-protocol-common";
export const signWatcherMessage = async (encodedMessage: string) => {
  const signatureNonce = Date.now();
  const signer = new Wallet(process.env.WATCHER_PRIVATE_KEY!);
  const watcherPrecompileAddress =
    getAddresses(mode)[EVMX_CHAIN_ID][EVMxCoreContracts.WatcherPrecompile];
  const digest = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["address", "uint32", "uint256", "bytes"],
      [watcherPrecompileAddress, EVMX_CHAIN_ID, signatureNonce, encodedMessage]
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
