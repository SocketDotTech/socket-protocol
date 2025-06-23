import { constants, Wallet } from "ethers";
import { ChainAddressesObj, ChainSlug, Contracts } from "../../src";
import { chains, EVMX_CHAIN_ID, mode } from "../config";
import { DeploymentAddresses, FAST_SWITCHBOARD_TYPE } from "../constants";
import {
  getAddresses,
  getInstance,
  getSocketSigner,
  updateContractSettings,
} from "../utils";
import { getWatcherSigner } from "../utils/sign";

export const main = async () => {
  try {
    console.log("Disabling Fast Switchboards");
    const addresses = getAddresses(mode) as unknown as DeploymentAddresses;
    const watcherSigner = getWatcherSigner();

    // Disable Fast Switchboards on each chain
    await Promise.all(
      chains.map(async (chain) => {
        const socketSigner = getSocketSigner(chain as ChainSlug);
        const addr = addresses[chain]!;
        await disableSBOnChain(chain, socketSigner, addr);
        await disableSBOnEVMx(chain, watcherSigner);
      })
    );
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};

// Disable a single Fast Switchboard
async function disableSBOnChain(
  chain: number,
  socketSigner: Wallet,
  addr: ChainAddressesObj
) {
  const sbAddr = addr[Contracts.FastSwitchboard];
  console.log(`Disabling Fast Switchboard ${sbAddr} on ${chain}`);

  // Get contract instances
  const fastSwitchboard = (
    await getInstance(Contracts.FastSwitchboard, sbAddr)
  ).connect(socketSigner);

  // Check if SB is already disabled
  const sbStatus = await fastSwitchboard.isValidSwitchboard(sbAddr);
  if (Number(sbStatus) === 1) {
    console.log(`Fast Switchboard ${sbAddr} on ${chain} is already disabled`);
    return;
  }

  // Disable SB
  const tx = await fastSwitchboard.functions["disableSwitchboard"](sbAddr);
  console.log(
    `Disabling Fast Switchboard ${sbAddr} on ${chain} tx hash: ${tx.hash}`
  );
  await tx.wait();
}

// Disable Fast Switchboards on the Watcher VM
export const disableSBOnEVMx = async (chain: number, watcherSigner: Wallet) => {
  try {
    console.log("Disabling Fast Switchboards on EVMx");
    await updateContractSettings(
      EVMX_CHAIN_ID,
      Contracts.Configurations,
      "switchboards",
      [chain, FAST_SWITCHBOARD_TYPE],
      constants.AddressZero,
      "setSwitchboard",
      [chain, FAST_SWITCHBOARD_TYPE, constants.AddressZero],
      watcherSigner
    );
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
