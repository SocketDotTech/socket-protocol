import { ethers, upgrades } from "hardhat";
import * as fs from "fs";
import * as path from "path";
import { EVMX_CHAIN_ID } from "../constants/constants";

const upgradeableContracts = [
  "SignatureVerifier",
  "AddressResolver",
  "WatcherPrecompile",
  "FeesManager",
  "DeliveryHelper",
  "AuctionManager",
];

async function main() {
  // Read addresses from JSON file
  const addressesPath = path.join(
    __dirname,
    "../../deployments/dev_addresses.json"
  );
  const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));

  if (!addresses[EVMX_CHAIN_ID]) {
    throw new Error(`No addresses found for chain ID ${EVMX_CHAIN_ID}`);
  }

  // Loop through each upgradeable contract
  for (const contractName of upgradeableContracts) {
    console.log(`\nProcessing ${contractName}...`);

    // Get the new implementation contract factory
    const NewImplementation = await ethers.getContractFactory(contractName);

    // Get proxy address from JSON
    const PROXY_ADDRESS = addresses[EVMX_CHAIN_ID][contractName];
    if (!PROXY_ADDRESS) {
      console.log(`Contract address not found for ${contractName}`);
      continue;
    }

    try {
      // Try to get current implementation address
      const currentImplAddress =
        await upgrades.erc1967.getImplementationAddress(PROXY_ADDRESS);
      console.log(
        `Current implementation address for ${contractName}: ${currentImplAddress}`
      );

      // Get the implementation address from JSON
      const newImplementation =
        addresses[EVMX_CHAIN_ID][`${contractName}Impl`];
      if (!newImplementation) {
        console.log(`No implementation address found for ${contractName}`);
        continue;
      }

      if (
        currentImplAddress.toLowerCase() === newImplementation.toLowerCase()
      ) {
        console.log("Implementation is already up to date");
        continue;
      }

      // Upgrade the proxy to point to the new implementation
      console.log("Upgrading proxy...");
      const upgraded = await upgrades.upgradeProxy(
        PROXY_ADDRESS,
        NewImplementation
      );
      await upgraded.deployed();

      console.log("Proxy upgraded successfully");

      // Verify the new implementation address
      const updatedImplAddress =
        await upgrades.erc1967.getImplementationAddress(PROXY_ADDRESS);
      console.log("Updated implementation address:", updatedImplAddress);
    } catch (error) {
      if (error.message.includes("doesn't look like an ERC 1967 proxy")) {
        console.log(
          `${contractName} at ${PROXY_ADDRESS} is not a proxy contract, skipping...`
        );
        continue;
      }
      throw error;
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
