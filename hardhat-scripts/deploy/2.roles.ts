import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { Wallet } from "ethers";
import { chains, EVMX_CHAIN_ID, mode, watcher, transmitter } from "../config";
import { DeploymentAddresses } from "../constants";
import { getAddresses, getInstance, getRoleHash, overrides } from "../utils";
import { ChainAddressesObj, ChainSlug, Contracts } from "../../src";
import { ROLES } from "../constants/roles";
import { getWatcherSigner, getSocketSigner } from "../utils/sign";

export const REQUIRED_ROLES = {
  EVMx: {
    AuctionManager: [ROLES.TRANSMITTER_ROLE],
    FeesPool: [ROLES.FEE_MANAGER_ROLE],
  },
  Chain: {
    FastSwitchboard: [ROLES.WATCHER_ROLE, ROLES.RESCUE_ROLE],
    CCTPSwitchboard: [ROLES.WATCHER_ROLE, ROLES.RESCUE_ROLE],
    Socket: [
      ROLES.GOVERNANCE_ROLE,
      ROLES.RESCUE_ROLE,
      ROLES.SWITCHBOARD_DISABLER_ROLE,
    ],
    FeesPlug: [ROLES.RESCUE_ROLE],
    ContractFactoryPlug: [ROLES.RESCUE_ROLE],
  },
};

async function setRoleForContract(
  contractName: Contracts,
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
      ...(await overrides(chain as ChainSlug)),
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
  const signer: Wallet = isWatcher
    ? getWatcherSigner()
    : getSocketSigner(chain as ChainSlug);
  return signer;
}

async function setRolesOnChain(chain: number, addresses: DeploymentAddresses) {
  const chainAddresses: ChainAddressesObj = (addresses[chain] ??
    {}) as ChainAddressesObj;
  const signer = await getSigner(chain);

  for (const [contractName, roles] of Object.entries(REQUIRED_ROLES["Chain"])) {
    const contractAddress =
      chainAddresses[contractName as keyof ChainAddressesObj];
    if (!contractAddress) continue;

    for (const roleName of roles) {
      const targetAddress =
        [Contracts.FastSwitchboard, Contracts.CCTPSwitchboard].includes(
          contractName as Contracts
        ) && roleName === ROLES.WATCHER_ROLE
          ? watcher
          : signer.address;

      await setRoleForContract(
        contractName as Contracts,
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

  await setRoleForContract(
    Contracts.AuctionManager,
    chainAddresses[Contracts.AuctionManager],
    transmitter,
    ROLES.TRANSMITTER_ROLE,
    signer,
    EVMX_CHAIN_ID
  );

  await setRoleForContract(
    Contracts.FeesPool,
    chainAddresses[Contracts.FeesPool],
    chainAddresses[Contracts.FeesManager],
    ROLES.FEE_MANAGER_ROLE,
    signer,
    EVMX_CHAIN_ID
  );
}

export const main = async () => {
  try {
    console.log("Setting Roles");
    const addresses = getAddresses(mode) as unknown as DeploymentAddresses;
    console.log("Setting Roles for On Chain");
    for (const chain of chains) {
      await setRolesOnChain(chain, addresses);
    }
    await setRolesForEVMx(addresses);
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
