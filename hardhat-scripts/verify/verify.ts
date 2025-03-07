import {
  ChainSlug,
  HardhatChainName,
  DeploymentMode,
  ChainSlugToKey,
} from "../../src";
import hre from "hardhat";
import { EVMX_CHAIN_ID, mode } from "../config/config";
import { storeUnVerifiedParams, verify } from "../utils";

import dev_verification from "../../deployments/dev_verification.json";
import stage_verification from "../../deployments/stage_verification.json";

const getVerificationParams = (mode: DeploymentMode) => {
  switch (mode) {
    case DeploymentMode.DEV:
      return dev_verification;
    case DeploymentMode.STAGE:
      return stage_verification;
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};

export type VerifyParams = {
  [chain in HardhatChainName]?: VerifyArgs[];
};
export type VerifyArgs = [string, string, string, any[]];

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    const verificationParams = getVerificationParams(mode);
    const chains = Object.keys(verificationParams);
    if (!chains) return;

    for (let chainIndex = 0; chainIndex < chains.length; chainIndex++) {
      const chain = parseInt(chains[chainIndex]) as ChainSlug;
      let chainName: string;
      console.log({ chain });
      if (chain == (EVMX_CHAIN_ID as ChainSlug)) {
        chainName = "EVMX";
      } else {
        chainName = ChainSlugToKey[chain];
      }
      console.log({ chainName });
      hre.changeNetwork(chainName);
      console.log(chainName);

      const chainParams: VerifyArgs[] = verificationParams[chain];
      const unverifiedChainParams: VerifyArgs[] = [];
      if (chainParams.length) {
        const len = chainParams.length;
        for (let index = 0; index < len!; index++) {
          const res = await verify(...chainParams[index]);
          if (!res) {
            unverifiedChainParams.push(chainParams[index]);
          }
        }
      }

      await storeUnVerifiedParams(unverifiedChainParams, chain, mode);
    }
  } catch (error) {
    console.log("Error in verifying contracts", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
