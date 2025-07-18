import { ChainSlug } from "../../src";
import { BigNumber, BigNumberish, Contract, providers, Signer } from "ethers";
import { EVMX_CHAIN_ID } from "../config/config";
import { getProviderFromChainSlug } from "./networks";

const defaultType = 0;

export const chainOverrides: {
  [chainSlug in ChainSlug]?: {
    type?: number;
    gasLimit?: number;
    gasPrice?: number;
  };
} = {
  [ChainSlug.ARBITRUM_SEPOLIA]: {
    // type: 2,
    // gasLimit: 50_000_000,
    gasPrice: 800_000_000,
  },
  [ChainSlug.SEPOLIA]: {
    type: 1,
    gasLimit: 2_000_000,
    // gasPrice: 50_000_000_000, // calculate in real time
  },
  [ChainSlug.OPTIMISM_SEPOLIA]: {
    // type: 1,
    // gasLimit: 1_000_000,
    // gasPrice: 212_000_000_000,
  },
  [ChainSlug.BASE]: {
    gasLimit: 2_000_000,
  },
  [ChainSlug.ARBITRUM]: {
    gasPrice: 100_629_157,
  },
  [EVMX_CHAIN_ID as ChainSlug]: {
    type: 0,
    // gasLimit: 1_000_000_000,
    gasPrice: 0,
  },
};

export const overrides = async (
  chain: ChainSlug | number
): Promise<{
  type?: number | undefined;
  gasLimit?: BigNumberish | undefined;
  gasPrice?: BigNumberish | undefined;
}> => {
  return await getOverrides(
    chain as ChainSlug,
    getProviderFromChainSlug(chain)
  );
};

export const getOverrides = async (
  chainSlug: ChainSlug,
  provider: providers.StaticJsonRpcProvider
) => {
  let overrides = chainOverrides[chainSlug];
  let gasPrice = overrides?.gasPrice;
  let gasLimit = overrides?.gasLimit;
  let type = overrides?.type;
  if (gasPrice == undefined || gasPrice == null)
    gasPrice = (await getGasPrice(chainSlug, provider)).toNumber();
  if (type == undefined) type = defaultType;
  // if gas limit is undefined, ethers will calcuate it automatically. If want to override,
  // add in the overrides object. Dont set a default value
  return { gasLimit, gasPrice, type };
};

export const getGasPrice = async (
  chainSlug: ChainSlug,
  provider: providers.StaticJsonRpcProvider
): Promise<BigNumber> => {
  let gasPrice = await provider.getGasPrice();

  if ([ChainSlug.SEPOLIA].includes(chainSlug as ChainSlug)) {
    return gasPrice.mul(BigNumber.from(150)).div(BigNumber.from(100));
  }
  return gasPrice;
};
