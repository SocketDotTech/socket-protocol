import { config } from "dotenv";
import { Signer } from "ethers";
import { Contracts } from "../../src";
import {
  EVMX_CHAIN_ID,
  FEES_POOL_FUNDING_AMOUNT_THRESHOLD,
  mode,
} from "../config/config";
import { getAddresses, getWatcherSigner } from "../utils";
config();

export const fundFeesPool = async (watcherSigner: Signer) => {
  const addresses = getAddresses(mode);
  const feesPoolAddress = addresses[EVMX_CHAIN_ID][Contracts.FeesPool];
  const feesPoolBalance = await watcherSigner.provider!.getBalance(
    feesPoolAddress
  );
  console.log({
    feesPoolAddress,
    feesPoolBalance,
    FEES_POOL_FUNDING_AMOUNT_THRESHOLD,
  });
  if (feesPoolBalance.gte(FEES_POOL_FUNDING_AMOUNT_THRESHOLD)) {
    console.log(
      `Fees pool ${feesPoolAddress} already has sufficient balance, skipping funding`
    );
    return;
  }

  const tx = await watcherSigner.sendTransaction({
    to: feesPoolAddress,
    value: FEES_POOL_FUNDING_AMOUNT_THRESHOLD,
  });
  console.log(
    `Funding fees pool ${feesPoolAddress} with ${FEES_POOL_FUNDING_AMOUNT_THRESHOLD} ETH, txHash: `,
    tx.hash
  );
  await tx.wait();
};

const main = async () => {
  console.log("Fund transfers");
  const watcherSigner = getWatcherSigner();
  await fundFeesPool(watcherSigner);
};

main();
