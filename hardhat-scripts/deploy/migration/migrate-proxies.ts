import { ethers } from "hardhat";
import { Contract, utils, Wallet } from "ethers";
import * as fs from "fs";
import * as path from "path";
import { EVMX_CHAIN_ID } from "../../constants/constants";
import { getProviderFromChainSlug } from "../../constants";
import { ChainSlug } from "@socket.tech/dl-core";

// Implementation slot from ERC1967
const IMPLEMENTATION_SLOT =
  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

const upgradeableContracts = [
  "SignatureVerifier",
  "AddressResolver",
  "WatcherPrecompile",
  "FeesManager",
  "DeliveryHelper",
  "AuctionManager",
];

async function getImplementationAddress(proxyAddress: string): Promise<string> {
  const customProvider = new ethers.providers.JsonRpcProvider(
    process.env.EVMX_RPC as string
  );

  // Fallback to standard storage slot for other proxy types
  const implHex = await customProvider.getStorageAt(
    proxyAddress,
    IMPLEMENTATION_SLOT
  );

  return utils.getAddress("0x" + implHex.slice(-40));
}

async function main() {
  // @ts-ignore - Hardhat Runtime Environment will be injected by hardhat

  // Read addresses from JSON file
  const addressesPath = path.join(
    __dirname,
    "../../../deployments/dev_addresses.json"
  );
  const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));

  if (!addresses[EVMX_CHAIN_ID]) {
    throw new Error(`No addresses found for chain ID ${EVMX_CHAIN_ID}`);
  }

  const providerInstance = getProviderFromChainSlug(EVMX_CHAIN_ID as ChainSlug);
  const signer: Wallet = new ethers.Wallet(
    process.env.WATCHER_PRIVATE_KEY as string,
    providerInstance
  );


  // Get the proxy factory
  let proxyFactory = await ethers.getContractAt(
    "ERC1967Factory",
    addresses[EVMX_CHAIN_ID].ERC1967Factory
  );
  proxyFactory = proxyFactory.connect(signer);

  // Loop through each upgradeable contract
  for (const contractName of upgradeableContracts) {
    console.log(`\nProcessing ${contractName}...`);

    const PROXY_ADDRESS = addresses[EVMX_CHAIN_ID][contractName];
    if (!PROXY_ADDRESS) {
      console.log(`Contract address not found for ${contractName}`);
      continue;
    }

    try {
      // Get current implementation
      const currentImplAddress = await getImplementationAddress(PROXY_ADDRESS);
      console.log(
        `Current implementation for ${contractName}: ${currentImplAddress}`
      );

      // Get new implementation address
      const newImplementation = addresses[EVMX_CHAIN_ID][`${contractName}Impl`];
      if (!newImplementation) {
        console.log(`No implementation address found for ${contractName}`);
        continue;
      }

      // Get contract instance for state verification
      let contract = await ethers.getContractAt(contractName, PROXY_ADDRESS);
      contract = contract.connect(signer);

      let version;
      try {
        version = await contract.version();
        console.log("Version on contract before upgrade:", version);
      } catch (error) {
        console.log("version variable not found");
      }

      if (
        currentImplAddress.toLowerCase() === newImplementation.toLowerCase()
      ) {
        console.log("Implementation is already up to date");
        continue;
      }

      // Upgrade proxy
      console.log("Upgrading proxy...");

      version = 2;
      const initializeFn = contract.interface.getFunction("initialize");
      const initData = contract.interface.encodeFunctionData(
        initializeFn,
        [version]
      );

      const tx = await proxyFactory.upgradeAndCall(
        PROXY_ADDRESS,
        newImplementation,
        initData
      );
      console.log("tx", tx.hash);
      await tx.wait();

      // Verify upgrade
      const updatedImplAddress = await getImplementationAddress(PROXY_ADDRESS);
      console.log("New implementation:", updatedImplAddress);

      if (
        updatedImplAddress.toLowerCase() !== newImplementation.toLowerCase()
      ) {
        throw new Error(
          "Upgrade verification failed - implementation mismatch"
        );
      }

      version = await contract.version();
      console.log("Version on contract after upgrade:", version);
      console.log("Upgrade successful and verified");
    } catch (error) {
      console.error(`Error upgrading ${contractName}:`, error);
      process.exit(1);
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
