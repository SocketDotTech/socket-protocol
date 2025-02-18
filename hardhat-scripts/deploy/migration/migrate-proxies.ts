import { ethers } from "hardhat";
import { Contract, utils, Wallet } from "ethers";
import * as fs from "fs";
import * as path from "path";
import { EVMX_CHAIN_ID, VERSION } from "../../constants/constants";
import { getProviderFromChainSlug } from "../../constants";
import { ChainSlug } from "@socket.tech/dl-core";

// Implementation slot from ERC1967
const IMPLEMENTATION_SLOT =
  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

const upgradeableContracts = [
  "AddressResolver",
  "WatcherPrecompile",
  "FeesManager",
  "DeliveryHelper",
  "AuctionManager",
];

export async function getImplementationAddress(
  proxyAddress: string
): Promise<string> {
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

async function loadAddresses() {
  const addressesPath = path.join(
    __dirname,
    "../../../deployments/dev_addresses.json"
  );
  const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));

  if (!addresses[EVMX_CHAIN_ID]) {
    throw new Error(`No addresses found for chain ID ${EVMX_CHAIN_ID}`);
  }

  return addresses;
}

async function setupSigner() {
  const providerInstance = getProviderFromChainSlug(EVMX_CHAIN_ID as ChainSlug);
  return new ethers.Wallet(
    process.env.WATCHER_PRIVATE_KEY as string,
    providerInstance
  );
}

async function setupProxyFactory(addresses: any, signer: Wallet) {
  let proxyFactory = await ethers.getContractAt(
    "ERC1967Factory",
    addresses[EVMX_CHAIN_ID].ERC1967Factory
  );
  return proxyFactory.connect(signer);
}

async function upgradeContract(
  contractName: string,
  addresses: any,
  proxyFactory: Contract,
  signer: Wallet
) {
  console.log(`\nProcessing ${contractName}...`);

  const PROXY_ADDRESS = addresses[EVMX_CHAIN_ID][contractName];
  if (!PROXY_ADDRESS) {
    console.log(`Contract address not found for ${contractName}`);
    return;
  }

  try {
    const currentImplAddress = await getImplementationAddress(PROXY_ADDRESS);
    console.log(
      `Current implementation for ${contractName}: ${currentImplAddress}`
    );

    const newImplementation = addresses[EVMX_CHAIN_ID][`${contractName}Impl`];
    if (!newImplementation) {
      console.log(`No implementation address found for ${contractName}`);
      return;
    }

    let contract = await ethers.getContractAt(contractName, PROXY_ADDRESS);
    contract = contract.connect(signer);

    await verifyAndUpgradeContract(
      contract,
      contractName,
      currentImplAddress,
      newImplementation,
      proxyFactory,
      signer
    );
  } catch (error) {
    console.error(`Error upgrading ${contractName}:`, error);
    process.exit(1);
  }
}

async function verifyAndUpgradeContract(
  contract: Contract,
  contractName: string,
  currentImplAddress: string,
  newImplementation: string,
  proxyFactory: Contract,
  signer: Wallet
) {
  let version;
  try {
    version = await contract.version();
    console.log("Version on contract before upgrade:", version);
  } catch (error) {
    console.log("version variable not found");
  }

  if (contractName === "AddressResolver")
    await verifyBeaconImplementation(contract, signer);

  if (currentImplAddress.toLowerCase() === newImplementation.toLowerCase()) {
    console.log("Implementation is already up to date");
    return;
  }

  await performUpgrade(contract, proxyFactory, newImplementation);
  await verifyUpgrade(contract, newImplementation, contractName, signer);
}

async function performUpgrade(
  contract: Contract,
  proxyFactory: Contract,
  newImplementation: string
) {
  console.log("Upgrading proxy...");
  const initializeFn = contract.interface.getFunction("initialize");
  const initData = contract.interface.encodeFunctionData(initializeFn, [
    VERSION,
  ]);

  const tx = await proxyFactory.upgradeAndCall(
    contract.address,
    newImplementation,
    initData
  );
  console.log("tx", tx.hash);
  await tx.wait();
}

async function verifyUpgrade(
  contract: Contract,
  newImplementation: string,
  contractName: string,
  signer: Wallet
) {
  const updatedImplAddress = await getImplementationAddress(contract.address);
  console.log("New implementation:", updatedImplAddress);

  if (updatedImplAddress.toLowerCase() !== newImplementation.toLowerCase()) {
    throw new Error("Upgrade verification failed - implementation mismatch");
  }

  const version = await contract.version();
  console.log("Version on contract after upgrade:", version);

  if (contractName === "AddressResolver") {
    await verifyBeaconImplementation(contract, signer);
  }

  console.log("Upgrade successful and verified");
}

async function verifyBeaconImplementation(contract: Contract, signer: Wallet) {
  console.log("Verifying beacon implementations...");
  const forwarderBeaconAddress = await contract.forwarderBeacon();
  const forwarderImplementationAddress =
    await contract.forwarderImplementation();
  const asyncPromiseBeaconAddress = await contract.asyncPromiseBeacon();
  const asyncPromiseImplementationAddress =
    await contract.asyncPromiseImplementation();

  const upgradeableBeaconAbi = [
    "function implementation() view returns (address)",
  ];

  const forwarderBeacon = new ethers.Contract(
    forwarderBeaconAddress,
    upgradeableBeaconAbi
  );
  const asyncPromiseBeacon = new ethers.Contract(
    asyncPromiseBeaconAddress,
    upgradeableBeaconAbi
  );

  // Verify forwarder beacon implementation
  const forwarderBeaconImplementation = await forwarderBeacon
    .connect(signer)
    .implementation();
  if (
    forwarderBeaconImplementation.toLowerCase() !==
    forwarderImplementationAddress.toLowerCase()
  ) {
    throw new Error("Forwarder beacon implementation mismatch");
  }

  // Verify async promise beacon implementation
  const asyncPromiseBeaconImplementation = await asyncPromiseBeacon
    .connect(signer)
    .implementation();
  if (
    asyncPromiseBeaconImplementation.toLowerCase() !==
    asyncPromiseImplementationAddress.toLowerCase()
  ) {
    throw new Error("Async promise beacon implementation mismatch");
  }
}

async function main() {
  // @ts-ignore - Hardhat Runtime Environment will be injected by hardhat
  const addresses = await loadAddresses();
  const signer = await setupSigner();
  const proxyFactory = await setupProxyFactory(addresses, signer);

  for (const contractName of upgradeableContracts) {
    await upgradeContract(contractName, addresses, proxyFactory, signer);
  }
}
