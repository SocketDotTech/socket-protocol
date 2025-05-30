import { ethers } from "ethers";
import { ChainSlug, Contracts } from "../../src";
import { EVMX_CHAIN_ID, mode } from "../config/config";
import { getProviderFromChainSlug } from "./networks";
import { signWatcherMultiCallMessage } from "../../src/signer";
import { getAddresses } from "./address";
import { getOverrides, overrides } from "./overrides";
import { getInstance } from "./deployUtils";
import { WatcherMultiCallParams } from "../constants/types";

export const getWatcherSigner = () => {
  const provider = getProviderFromChainSlug(EVMX_CHAIN_ID as ChainSlug);
  return new ethers.Wallet(process.env.WATCHER_PRIVATE_KEY as string, provider);
};

export const getSocketSigner = (chainSlug: ChainSlug) => {
  const provider = getProviderFromChainSlug(chainSlug);
  return new ethers.Wallet(process.env.SOCKET_SIGNER_KEY as string, provider);
};

export const getTransmitterSigner = (chainSlug: ChainSlug) => {
  const provider = getProviderFromChainSlug(chainSlug);
  return new ethers.Wallet(
    process.env.TRANSMITTER_PRIVATE_KEY as string,
    provider
  );
};

export const signWatcherMessage = async (
  targetContractAddress: string,
  calldata: string
) => {
  const addresses = getAddresses(mode);
  return await signWatcherMultiCallMessage(
    addresses[EVMX_CHAIN_ID][Contracts.Watcher],
    EVMX_CHAIN_ID,
    targetContractAddress,
    calldata,
    getWatcherSigner()
  );
};

export const sendWatcherMultiCallWithNonce = async (
  targetContractAddress: string,
  calldata: string
) => {
  const addresses = getAddresses(mode);
  const watcherContract = (
    await getInstance(
      Contracts.Watcher,
      addresses[EVMX_CHAIN_ID][Contracts.Watcher]
    )
  ).connect(getWatcherSigner());
  const { nonce, signature } = await signWatcherMessage(
    targetContractAddress,
    calldata
  );

  const params: WatcherMultiCallParams = {
    contractAddress: targetContractAddress,
    data: calldata,
    nonce,
    signature,
  };
  // Call watcherMultiCall function with single call data
  return await watcherContract.watcherMultiCall([params], {
    ...(await overrides(EVMX_CHAIN_ID as ChainSlug)),
  });
};
