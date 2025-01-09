import { DeploymentAddresses } from "@socket.tech/dl-core";
import { Contract, ethers, providers } from "ethers";
import WatcherABI from "../../out/WatcherPrecompile.sol/WatcherPrecompile.json";
import { OffChainVMCoreContracts } from "./config";
import dev_addresses from "../../deployments/dev_addresses.json";
import { OFF_CHAIN_VM_CHAIN_ID } from "../constants/constants";

const MAX_LIMIT = "10000000000000000000000";
const providerInstance = new providers.StaticJsonRpcProvider(
  process.env.OFF_CHAIN_VM_RPC as string
);
const signer = new ethers.Wallet(
  process.env.WATCHER_PRIVATE_KEY as string,
  providerInstance
);
type LimitParam = {
  limitType: string;
  appGateway: string;
  maxLimit: string;
  ratePerSecond: string;
};
const addresses = dev_addresses as unknown as DeploymentAddresses;
const deliveryHelperLimitParams: LimitParam[] = [
  {
    limitType: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("FINALIZE")),
    appGateway:
      addresses[OFF_CHAIN_VM_CHAIN_ID]?.[
        OffChainVMCoreContracts.DeliveryHelper
      ],
    maxLimit: MAX_LIMIT,
    ratePerSecond: MAX_LIMIT,
  },
  {
    limitType: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("QUERY")),
    appGateway:
      addresses[OFF_CHAIN_VM_CHAIN_ID]?.[
        OffChainVMCoreContracts.DeliveryHelper
      ],
    maxLimit: MAX_LIMIT,
    ratePerSecond: MAX_LIMIT,
  },
  {
    limitType: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SCHEDULE")),
    appGateway:
      addresses[OFF_CHAIN_VM_CHAIN_ID]?.[
        OffChainVMCoreContracts.AuctionManager
      ],
    maxLimit: MAX_LIMIT,
    ratePerSecond: MAX_LIMIT,
  },
  {
    limitType: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("FINALIZE")),
    appGateway:
      addresses[OFF_CHAIN_VM_CHAIN_ID]?.[OffChainVMCoreContracts.FeesManager],
    maxLimit: MAX_LIMIT,
    ratePerSecond: MAX_LIMIT,
  },
];

// Set limits on the Watcher VM
export const updateContractLimits = async (limitParamsToSet: LimitParam[]) => {
  try {
    console.log("Setting limits on OffChainVM");
    const limitParams: LimitParam[] = [];

    // Set up Watcher contract
    const watcherVMaddr = addresses[OFF_CHAIN_VM_CHAIN_ID]!;
    const watcher = new Contract(
      watcherVMaddr[OffChainVMCoreContracts.WatcherPrecompile],
      WatcherABI.abi,
      signer
    );

    // Collect configs for each chain and plug
    for (const limitParam of limitParamsToSet) {
      const appGateway = limitParam.appGateway;

      if (await isLimitSet(watcher, limitParam.limitType, appGateway)) {
        console.log(`Limit already set on ${appGateway}`);
        continue;
      }
      limitParams.push(limitParam);
    }

    // Update configs if any changes needed
    if (limitParams.length > 0) {
      console.log({ limitParams });
      const tx = await watcher.updateLimitParams(limitParams);
      console.log(`Updating OffChainVM limits tx hash: ${tx.hash}`);
      await tx.wait();
    }
  } catch (error) {
    console.log("Error while sending transaction to set limits", error);
  }
};

async function isLimitSet(
  watcher: Contract,
  limitType: string,
  appGateway: string
): Promise<boolean> {
  try {
    const currentLimit = await watcher.getCurrentLimit(limitType, appGateway);
    // If maxLimit is 0, limit is not set yet
    return currentLimit.toString() === MAX_LIMIT;
  } catch (error) {
    console.log(`Error checking limit for ${appGateway}:`, error);
    return false;
  }
}

// Main function to set limits
export const main = async () => {
  try {
    await updateContractLimits(deliveryHelperLimitParams);
  } catch (error) {
    console.log("Error while sending transaction to set limits", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
