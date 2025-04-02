import {
  arbChains,
  arbL3Chains,
  ChainSlug,
  ChainType,
  opStackL2Chain,
  polygonCDKChains,
  zkStackChain,
} from "../../src";

export const getChainType = (chainSlug: ChainSlug) => {
  if (opStackL2Chain.includes(chainSlug)) {
    return ChainType.opStackL2Chain;
  } else if (arbChains.includes(chainSlug)) {
    return ChainType.arbChain;
  } else if (arbL3Chains.includes(chainSlug)) {
    return ChainType.arbL3Chain;
  } else if (polygonCDKChains.includes(chainSlug)) {
    return ChainType.zkStackChain;
  } else if (zkStackChain.includes(chainSlug)) {
    return ChainType.polygonCDKChain;
  } else return ChainType.default;
};
