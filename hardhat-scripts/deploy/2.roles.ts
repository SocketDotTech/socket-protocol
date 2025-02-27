import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { Wallet } from "ethers";
import { ethers } from "hardhat";
import { chains, EVMX_CHAIN_ID, mode, watcher } from "../config";
import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  EVMxCoreContracts,
} from "../constants";
import {
  getAddresses,
  getInstance,
  getProviderFromChainSlug,
  getRoleHash,
  overrides,
} from "../utils";
import { relayerAddressList } from "../constants/relayers";
import { ChainAddressesObj } from "@socket.tech/socket-protocol-common";
import { ROLES } from "../constants/roles";

export const REQUIRED_ROLES = {
  FastSwitchboard: [ROLES.WATCHER_ROLE, ROLES.RESCUE_ROLE],
  Socket: [ROLES.GOVERNANCE_ROLE, ROLES.RESCUE_ROLE],
  FeesPlug: [ROLES.RESCUE_ROLE],
  ContractFactoryPlug: [ROLES.RESCUE_ROLE],
};

async function setRoleForContract(
  contractName: CORE_CONTRACTS | EVMxCoreContracts,
  contractAddress: string | number,
  targetAddress: string,
  roleName: string,
  signer: Wallet,
  chain: number
) {
  let contract = await getInstance(contractName, contractAddress.toString());
  contract = contract.connect(signer);

  console.log(`checking ${roleName} role for ${contractName} on ${chain}`);
  const roleHash = getRoleHash(roleName);
  const hasRole = await contract.callStatic["hasRole(bytes32,address)"](
    roleHash,
    targetAddress,
    {
      from: signer.address,
    }
  );

  if (!hasRole) {
    let tx = await contract.grantRole(roleHash, targetAddress, {
      ...overrides(chain),
    });
    console.log(
      `granting ${roleName} role to ${targetAddress} for ${contractName}`,
      chain,
      "txHash: ",
      tx.hash
    );
    await tx.wait();
  }
}

async function getSigner(chain: number, isWatcher: boolean = false) {
  const providerInstance = getProviderFromChainSlug(chain);
  const signer: Wallet = new ethers.Wallet(
    isWatcher
      ? (process.env.WATCHER_PRIVATE_KEY as string)
      : (process.env.SOCKET_SIGNER_KEY as string),
    providerInstance
  );
  return signer;
}

async function setRolesForOnChain(
  chain: number,
  addresses: DeploymentAddresses
) {
  const chainAddresses: ChainAddressesObj = (addresses[chain] ??
    {}) as ChainAddressesObj;
  const signer = await getSigner(chain);

  for (const [contractName, roles] of Object.entries(REQUIRED_ROLES)) {
    const contractAddress =
      chainAddresses[contractName as keyof ChainAddressesObj];
    if (!contractAddress) continue;

    for (const roleName of roles) {
      const targetAddress =
        contractName === CORE_CONTRACTS.FastSwitchboard &&
        roleName === ROLES.WATCHER_ROLE
          ? watcher
          : signer.address;

      await setRoleForContract(
        contractName as CORE_CONTRACTS,
        contractAddress,
        targetAddress,
        roleName,
        signer,
        chain
      );
    }
  }
}

async function setRolesForEVMx(addresses: DeploymentAddresses) {
  const chainAddresses: ChainAddressesObj = (addresses[EVMX_CHAIN_ID] ??
    {}) as ChainAddressesObj;
  const signer = await getSigner(EVMX_CHAIN_ID, true);

  const contractAddress = chainAddresses[EVMxCoreContracts.WatcherPrecompile];
  if (!contractAddress) return;

  for (const relayerAddress of [...relayerAddressList, signer.address]) {
    console.log(`setting WATCHER_ROLE for ${relayerAddress} on EVMX`);
    await setRoleForContract(
      EVMxCoreContracts.WatcherPrecompile,
      contractAddress,
      relayerAddress,
      ROLES.WATCHER_ROLE,
      signer,
      EVMX_CHAIN_ID
    );
  }
}

export const main = async () => {
  try {
    console.log("Setting Roles");
    const addresses = getAddresses(mode) as unknown as DeploymentAddresses;

    console.log("Setting Roles for EVMx");
    await setRolesForEVMx(addresses);

    console.log("Setting Roles for On Chain");
    for (const chain of chains) {
      await setRolesForOnChain(chain, addresses);
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
