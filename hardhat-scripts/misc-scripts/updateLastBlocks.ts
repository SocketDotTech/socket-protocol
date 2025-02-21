import dotenv from "dotenv";
import fs from "fs";
import path from "path";
import { getProviderFromChainSlug } from "../utils";
import { getAddresses } from "../utils";
import { mode } from "../config/config";
dotenv.config();
async function updateLastBlocks() {
  // Read deployment addresses
  const addresses = getAddresses(mode);

  const chains = Object.keys(addresses).map((chainSlug) => Number(chainSlug));
  // Update each chain's start block
  for (const chainSlug of chains) {
    const chainAddresses = addresses[chainSlug];
    try {
      let provider = getProviderFromChainSlug(chainSlug);
      // Get latest block
      const latestBlock = await provider.getBlockNumber();
      console.log({
        chainSlug,
        currentStartBlock: chainAddresses.startBlock,
        latestBlock,
      });
      // Update start block
      chainAddresses.startBlock = latestBlock;

      console.log(`Updated chain ${chainSlug} start block to ${latestBlock}`);
    } catch (error) {
      console.error(`Error updating chain ${chainSlug}:`, error);
    }
  }

  // Write updated data back to file
  fs.writeFileSync(
    path.join(__dirname, `../../deployments/${mode}_addresses.json`),
    JSON.stringify(addresses, null, 2)
  );
  console.log("Successfully updated start blocks in deployment file");
}

// Run the update
updateLastBlocks()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
