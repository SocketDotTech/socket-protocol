import {
  ChainSocketAddresses,
  CORE_CONTRACTS,
  DeploymentAddresses,
  ROLES,
} from "@socket.tech/dl-core";

import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ethers } from "hardhat";
import dev_addresses from "../../deployments/dev_addresses.json";
import { chains, watcher } from "./config";
import { getProviderFromChainSlug } from "../constants";
import { Wallet } from "ethers";
import { getInstance, getRoleHash } from "./utils";

export const REQUIRED_ROLES = {
  FastSwitchboard: [ROLES.WATCHER_ROLE, ROLES.RESCUE_ROLE],
  Socket: [ROLES.GOVERNANCE_ROLE, ROLES.RESCUE_ROLE],
  FeesPlug: [ROLES.RESCUE_ROLE],
  ContractFactoryPlug: [ROLES.RESCUE_ROLE],
};

export const main = async () => {
  let addresses: DeploymentAddresses;
  try {
    console.log("Setting Roles");
    addresses = dev_addresses as unknown as DeploymentAddresses;

    for (const chain of chains) {
      let chainAddresses: ChainSocketAddresses = addresses[chain]
        ? (addresses[chain] as ChainSocketAddresses)
        : ({} as ChainSocketAddresses);

      const providerInstance = getProviderFromChainSlug(chain);
      const signer: Wallet = new ethers.Wallet(
        process.env.SOCKET_SIGNER_KEY as string,
        providerInstance
      );

      for (const [contractName, roleHash] of Object.entries(REQUIRED_ROLES)) {
        if (!chainAddresses[contractName as keyof ChainSocketAddresses])
          continue;

        let contract = await getInstance(
          contractName as CORE_CONTRACTS,
          chainAddresses[contractName as keyof ChainSocketAddresses]!
        );
        contract = contract.connect(signer);

        const targetAddress =
          contractName === CORE_CONTRACTS.FastSwitchboard
            ? watcher
            : signer.address;

        const hasRole = await contract.callStatic["hasRole(bytes32,address)"](
          getRoleHash(roleHash),
          targetAddress,
          {
            from: signer.address,
          }
        );

        if (!hasRole) {
          let tx;
          if (contractName === CORE_CONTRACTS.FastSwitchboard) {
            tx = await contract.grantWatcherRole(targetAddress);
          } else {
            tx = await contract.grantRole(getRoleHash(roleHash), targetAddress);
          }
          console.log(
            `granting ${roleHash} role to ${targetAddress} for ${contractName}`,
            chain,
            tx.hash
          );
          await tx.wait();
        }
      }
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
