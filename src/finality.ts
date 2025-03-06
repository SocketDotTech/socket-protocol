import { ChainSlug } from "./chain-enums";
import { ChainFinalityBlocks, FinalityBucket } from "./types";

export const DEFAULT_FINALITY_BUCKET = FinalityBucket.LOW;

export const defaultFinalityBlocks: ChainFinalityBlocks = {
  [FinalityBucket.LOW]: 1,
  [FinalityBucket.MEDIUM]: "safe",
  [FinalityBucket.HIGH]: "finalized",
};

export const getFinalityBlocks = (
  chainSlug: ChainSlug
): ChainFinalityBlocks => {
  return finalityBlockOverrides[chainSlug] ?? defaultFinalityBlocks;
};

export const finalityBlockOverrides: {
  [chainSlug in ChainSlug]?: ChainFinalityBlocks;
} = {
  [ChainSlug.MAINNET]: {
    [FinalityBucket.LOW]: 6,
    [FinalityBucket.MEDIUM]: "safe",
    [FinalityBucket.HIGH]: "finalized",
  },

  [ChainSlug.POLYGON_MAINNET]: {
    [FinalityBucket.LOW]: 256,
    [FinalityBucket.MEDIUM]: 512,
    [FinalityBucket.HIGH]: 1000,
  },
  [ChainSlug.NEOX_TESTNET]: {
    [FinalityBucket.LOW]: 1,
    [FinalityBucket.MEDIUM]: 10,
    [FinalityBucket.HIGH]: 100,
  },
  [ChainSlug.NEOX_T4_TESTNET]: {
    [FinalityBucket.LOW]: 1,
    [FinalityBucket.MEDIUM]: 10,
    [FinalityBucket.HIGH]: 100,
  },
  [ChainSlug.NEOX]: {
    [FinalityBucket.LOW]: 1,
    [FinalityBucket.MEDIUM]: 10,
    [FinalityBucket.HIGH]: 100,
  },
  [ChainSlug.LINEA]: {
    [FinalityBucket.LOW]: 1,
    [FinalityBucket.MEDIUM]: 10,
    [FinalityBucket.HIGH]: 100,
  },
};
