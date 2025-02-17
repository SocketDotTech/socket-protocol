import {
  ChainSocketAddresses,
  DeploymentAddresses,
} from "@socket.tech/dl-core";
import { getProviderFromChainSlug } from "../constants";
import { Contract, ethers, providers, Wallet } from "ethers";
import { getInstance } from "./utils";
import { chains } from "./config";
import dev_addresses from "../../deployments/dev_addresses.json";
import { EVMX_CHAIN_ID } from "../constants/constants";
import { CORE_CONTRACTS, OffChainVMCoreContracts } from "../../src";

const plugs = [CORE_CONTRACTS.ContractFactoryPlug, CORE_CONTRACTS.FeesPlug];
export type AppGatewayConfig = {
  plug: string;
  appGateway: string;
  switchboard: string;
  chainSlug: number;
};
// Maps plug contracts to their corresponding app gateways
export const getAppGateway = (plug: string, addresses: DeploymentAddresses) => {
  switch (plug) {
    case CORE_CONTRACTS.ContractFactoryPlug:
      return addresses?.[EVMX_CHAIN_ID]?.[
        OffChainVMCoreContracts.DeliveryHelper
      ];
    case CORE_CONTRACTS.FeesPlug:
      return addresses?.[EVMX_CHAIN_ID]?.[OffChainVMCoreContracts.FeesManager];
    default:
      throw new Error(`Unknown plug: ${plug}`);
  }
};

export const checkIfAddressExists = (address: string, name: string) => {
  if (
    address == "0x0000000000000000000000000000000000000000" ||
    !address ||
    address == "0x" ||
    address.length != 42
  ) {
    throw Error(`${name} not found`);
  }
  return address;
};

export const isConfigSetOnSocket = async (
  plug: Contract,
  socket: Contract,
  appGateway: string,
  switchboard: string
) => {
  const plugConfigRegistered = await socket.getPlugConfig(plug.address);
  return (
    plugConfigRegistered.appGateway.toLowerCase() ===
      appGateway?.toLowerCase() &&
    plugConfigRegistered.switchboard__.toLowerCase() ===
      switchboard.toLowerCase()
  );
};

// Connect a single plug contract to its app gateway and switchboard
async function connectPlug(
  chain: number,
  plugContract: string,
  socketSigner: Wallet,
  addresses: DeploymentAddresses,
  addr: ChainSocketAddresses
) {
  console.log(`Connecting ${plugContract} on ${chain}`);

  // Get contract instances
  const plug = (await getInstance(plugContract, addr[plugContract])).connect(
    socketSigner
  );
  const socket = (
    await getInstance(CORE_CONTRACTS.Socket, addr[CORE_CONTRACTS.Socket])
  ).connect(socketSigner);

  // Get switchboard and app gateway addresses
  const switchboard = addr[CORE_CONTRACTS.FastSwitchboard];
  checkIfAddressExists(switchboard, "Switchboard");
  const appGateway = getAppGateway(plugContract, addresses);
  checkIfAddressExists(appGateway, "AppGateway");
  // Check if config is already set
  if (await isConfigSetOnSocket(plug, socket, appGateway, switchboard)) {
    console.log(`${plugContract} Socket Config  on ${chain} already set!`);
    return;
  }

  // Connect the plug
  const tx = await plug.functions["connectSocket"](
    appGateway,
    socket.address,
    switchboard
  );
  console.log(
    `Connecting ${plugContract} on ${chain} to ${appGateway} tx hash: ${tx.hash}`
  );
  await tx.wait();
}

export const connectPlugsOnSocket = async () => {
  console.log("Connecting plugs");
  const addresses = dev_addresses as unknown as DeploymentAddresses;
  // Connect plugs on each chain
  await Promise.all(
    chains.map(async (chain) => {
      if (!addresses[chain]) return;

      const providerInstance = getProviderFromChainSlug(chain);
      const socketSigner = new Wallet(
        process.env.SOCKET_SIGNER_KEY as string,
        providerInstance
      );
      const addr = addresses[chain]!;
      // Connect each plug contract
      for (const plugContract of plugs) {
        await connectPlug(chain, plugContract, socketSigner, addresses, addr);
      }
    })
  );
};

export const isConfigSetOnWatcherVM = async (
  watcher: Contract,
  chain: number,
  plug: string,
  appGateway: string,
  switchboard: string
) => {
  const plugConfigRegistered = await watcher.getPlugConfigs(chain, plug);
  return (
    plugConfigRegistered[0].toLowerCase() === appGateway?.toLowerCase() &&
    plugConfigRegistered[1].toLowerCase() === switchboard.toLowerCase()
  );
};

// Configure plugs on the Watcher VM
export const updateConfigWatcherVM = async () => {
  try {
    console.log("Connecting plugs on OffChainVM");
    const addresses = dev_addresses as unknown as DeploymentAddresses;
    const appConfigs: AppGatewayConfig[] = [];

    // Set up Watcher contract
    const providerInstance = new providers.StaticJsonRpcProvider(
      process.env.EVMX_RPC as string
    );
    const signer = new ethers.Wallet(
      process.env.WATCHER_PRIVATE_KEY as string,
      providerInstance
    );
    const watcherVMaddr = addresses[EVMX_CHAIN_ID]!;
    const watcher = (
      await getInstance(
        OffChainVMCoreContracts.WatcherPrecompile,
        watcherVMaddr[OffChainVMCoreContracts.WatcherPrecompile]
      )
    ).connect(signer);

    // Collect configs for each chain and plug
    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;
        const addr = addresses[chain]!;

        for (const plugContract of plugs) {
          const appGateway = getAppGateway(plugContract, addresses);
          const switchboard = addr[CORE_CONTRACTS.FastSwitchboard];
          checkIfAddressExists(switchboard, "Switchboard");
          checkIfAddressExists(appGateway, "AppGateway");

          if (
            await isConfigSetOnWatcherVM(
              watcher,
              chain,
              addr[plugContract],
              appGateway,
              switchboard
            )
          ) {
            console.log(`Config already set on ${chain} for ${plugContract}`);
            continue;
          }
          appConfigs.push({
            plug: addr[plugContract],
            appGateway,
            switchboard: addr[CORE_CONTRACTS.FastSwitchboard],
            chainSlug: chain,
          });
        }
      })
    );

    // Update configs if any changes needed
    if (appConfigs.length > 0) {
      console.log({ appConfigs });
      const tx = await watcher.setAppGateways(appConfigs);
      console.log(`Updating OffChainVM Config tx hash: ${tx.hash}`);
      await tx.wait();
    }
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};

// Main function to connect plugs on all chains
export const main = async () => {
  try {
    await connectPlugsOnSocket();
    await updateConfigWatcherVM();
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
