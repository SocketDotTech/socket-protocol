import { Contract, Wallet } from "ethers";
import { ChainAddressesObj, ChainSlug, Contracts } from "../../src";
import { chains, EVMX_CHAIN_ID, mode } from "../config";
import { AppGatewayConfig, DeploymentAddresses } from "../constants";
import {
  checkIfAddressExists,
  checkIfAppGatewayIdExists,
  getAddresses,
  getAppGatewayId,
  getInstance,
  getSocketSigner,
} from "../utils";
import { getWatcherSigner, sendWatcherMultiCallWithNonce } from "../utils/sign";

const plugs = [Contracts.ContractFactoryPlug, Contracts.FeesPlug];

// Main function to connect plugs on all chains
export const main = async () => {
  try {
    await connectPlugsOnSocket();
    await updateConfigEVMx();
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};

export const isConfigSetOnSocket = async (
  plug: Contract,
  socket: Contract,
  appGatewayId: string,
  switchboard: string
) => {
  const plugConfigRegistered = await socket.getPlugConfig(plug.address);
  return (
    plugConfigRegistered.appGatewayId.toLowerCase() ===
      appGatewayId.toLowerCase() &&
    plugConfigRegistered.switchboard.toLowerCase() === switchboard.toLowerCase()
  );
};

// Connect a single plug contract to its app gateway and switchboard
async function connectPlug(
  chain: number,
  plugContract: string,
  socketSigner: Wallet,
  addresses: DeploymentAddresses,
  addr: ChainAddressesObj
) {
  console.log(`Connecting ${plugContract} on ${chain}`);

  // Get contract instances
  const plug = (await getInstance(plugContract, addr[plugContract])).connect(
    socketSigner
  );
  const socket = (
    await getInstance(Contracts.Socket, addr[Contracts.Socket])
  ).connect(socketSigner);

  // Get switchboard and app gateway addresses
  const switchboard = addr[Contracts.FastSwitchboard];
  checkIfAddressExists(switchboard, "Switchboard");
  const appGatewayId = getAppGatewayId(plugContract, addresses);
  checkIfAppGatewayIdExists(appGatewayId, "AppGatewayId");
  // Check if config is already set
  if (await isConfigSetOnSocket(plug, socket, appGatewayId, switchboard)) {
    console.log(`${plugContract} Socket Config  on ${chain} already set!`);
    return;
  }

  // Connect the plug
  const tx = await plug.functions["connectSocket"](
    appGatewayId,
    socket.address,
    switchboard
  );
  console.log(
    `Connecting ${plugContract} on ${chain} to ${appGatewayId} tx hash: ${tx.hash}`
  );
  await tx.wait();
}

export const connectPlugsOnSocket = async () => {
  console.log("Connecting plugs");
  const addresses = getAddresses(mode) as unknown as DeploymentAddresses;
  // Connect plugs on each chain
  await Promise.all(
    chains.map(async (chain) => {
      if (!addresses[chain]) return;

      const socketSigner = getSocketSigner(chain as ChainSlug);
      const addr = addresses[chain]!;
      // Connect each plug contract
      for (const plugContract of plugs) {
        if (addr[plugContract]) {
          await connectPlug(chain, plugContract, socketSigner, addresses, addr);
        }
      }
    })
  );
};

export const isConfigSetOnEVMx = async (
  watcher: Contract,
  chain: number,
  plug: string,
  appGatewayId: string,
  switchboard: string
) => {
  const plugConfigRegistered = await watcher.getPlugConfigs(chain, plug);
  return (
    plugConfigRegistered[0].toLowerCase() === appGatewayId?.toLowerCase() &&
    plugConfigRegistered[1].toLowerCase() === switchboard.toLowerCase()
  );
};

// Configure plugs on the Watcher VM
export const updateConfigEVMx = async () => {
  try {
    console.log("Connecting plugs on EVMx");
    const addresses = getAddresses(mode) as unknown as DeploymentAddresses;
    const appConfigs: AppGatewayConfig[] = [];

    // Set up Watcher contract
    const signer = getWatcherSigner();
    const EVMxAddresses = addresses[EVMX_CHAIN_ID]!;
    const configurationsContract = (
      await getInstance(
        Contracts.Configurations,
        EVMxAddresses[Contracts.Configurations]
      )
    ).connect(signer);

    // Collect configs for each chain and plug
    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;
        const addr = addresses[chain]!;

        for (const plugContract of plugs) {
          const appGatewayId = getAppGatewayId(plugContract, addresses);
          const switchboard = addr[Contracts.FastSwitchboard];
          checkIfAddressExists(switchboard, "Switchboard");
          checkIfAppGatewayIdExists(appGatewayId, "AppGatewayId");

          if (!addr[plugContract]) {
            console.log(`${plugContract} not found on ${chain}`);
            continue;
          }

          if (
            await isConfigSetOnEVMx(
              configurationsContract,
              chain,
              addr[plugContract],
              appGatewayId,
              switchboard
            )
          ) {
            console.log(`Config already set on ${chain} for ${plugContract}`);
            continue;
          }
          appConfigs.push({
            plugConfig: {
              appGatewayId: appGatewayId,
              switchboard: switchboard,
            },
            plug: addr[plugContract],
            chainSlug: chain,
          });
        }
      })
    );

    // Update configs if any changes needed
    if (appConfigs.length > 0) {
      console.log({ appConfigs });
      const calldata = configurationsContract.interface.encodeFunctionData(
        "setAppGatewayConfigs",
        [appConfigs]
      );
      const tx = await sendWatcherMultiCallWithNonce(
        configurationsContract.address,
        calldata
      );
      console.log(`Updating EVMx Config tx hash: ${tx.hash}`);
      await tx.wait();
    }
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
