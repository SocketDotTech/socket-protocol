import { config as dotenvConfig } from "dotenv";
import { ChainConfig, ChainSlug, S3Config, getFinalityBlocks } from "../../src";
import { EVMX_CHAIN_ID, chains, mode } from "../config/config";
import { getAddresses } from "../utils/address";
import { getChainName, rpcKeys, wssRpcKeys } from "../utils/networks";
import { getChainType } from "./utils";
import { version } from "./version";

dotenvConfig();
const addresses = getAddresses(mode);

export const getS3Config = () => {
  const supportedChainSlugs = [EVMX_CHAIN_ID as ChainSlug, ...chains];
  const config: S3Config = {
    supportedChainSlugs,
    version: version[mode],
    chains: {},
  };
  supportedChainSlugs.forEach((chainSlug) => {
    config.chains[chainSlug] = getChainConfig(chainSlug);
  });
  return config;
};

export const getChainConfig = (chainSlug: ChainSlug) => {
  let rpcKey = rpcKeys(chainSlug);
  let wssRpcKey = wssRpcKeys(chainSlug);
  if (!process.env[rpcKey] || !process.env[wssRpcKey]) {
    throw new Error(
      `Missing RPC or WSS RPC for chain ${getChainName(chainSlug)}`
    );
  }
  const chainConfig: ChainConfig = {
    eventBlockRangePerCron: 5000,
    rpc: process.env[rpcKey],
    wssRpc: process.env[wssRpcKey],
    confirmations: 0,
    eventBlockRange: 5000,
    addresses: addresses[chainSlug],
    chainType: getChainType(chainSlug),
    finalityBlocks: getFinalityBlocks(chainSlug),
  };
  return chainConfig;
};
