import { constants, Wallet } from "ethers";
import { ChainAddressesObj, ChainSlug, Contracts } from "../../src";
import { chains, EVMX_CHAIN_ID, getFeesPlugChains, mode } from "../config";
import {
  AppGatewayConfig,
  DeploymentAddresses,
  ZERO_APP_GATEWAY_ID,
} from "../constants";
import {
  checkIfAddressExists,
  getAddresses,
  getInstance,
  getSocketSigner,
} from "../utils";
import { getWatcherSigner, sendWatcherMultiCallWithNonce } from "../utils/sign";
import { isConfigSetOnEVMx, isConfigSetOnSocket } from "../deploy/6.connect";

// update this map to disconnect plugs from chains not in this list
const feesPlugChains = getFeesPlugChains();

export const main = async () => {
  try {
    await disconnectPlugsOnSocket();
    await updateConfigEVMx();
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};

// Connect a single plug contract to its app gateway and switchboard
async function disconnectPlug(
  chain: number,
  plugContract: string,
  socketSigner: Wallet,
  addr: ChainAddressesObj
) {
  console.log(`Disconnecting ${plugContract} on ${chain}`);

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

  // Check if config is already set
  if (
    await isConfigSetOnSocket(plug, socket, ZERO_APP_GATEWAY_ID, switchboard)
  ) {
    console.log(`${plugContract} Socket Config  on ${chain} already set!`);
    return;
  }

  // Connect the plug
  const tx = await plug.functions["connectSocket"](
    ZERO_APP_GATEWAY_ID,
    socket.address,
    switchboard
  );
  console.log(
    `Connecting ${plugContract} on ${chain} to ${ZERO_APP_GATEWAY_ID} tx hash: ${tx.hash}`
  );
  await tx.wait();
}

export const disconnectPlugsOnSocket = async () => {
  console.log("Disconnecting plugs");
  const addresses = getAddresses(mode) as unknown as DeploymentAddresses;
  // Disconnect plugs on each chain
  await Promise.all(
    chains.map(async (chain) => {
      // skip if chain is in feesPlugChains or not in addresses
      if (feesPlugChains.includes(chain) || !addresses[chain]) return;

      const socketSigner = getSocketSigner(chain as ChainSlug);
      const addr = addresses[chain]!;
      if (addr[Contracts.FeesPlug]) {
        await disconnectPlug(chain, Contracts.FeesPlug, socketSigner, addr);
      }
    })
  );
};

// Configure plugs on the Watcher VM
export const updateConfigEVMx = async () => {
  try {
    console.log("Disconnecting plugs on EVMx");
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
        // skip if chain is in feesPlugChains or not in addresses
        if (feesPlugChains.includes(chain) || !addresses[chain]) return;
        const addr = addresses[chain]!;

        const appGatewayId = ZERO_APP_GATEWAY_ID;
        const switchboard = constants.AddressZero;
        const plugContract = Contracts.FeesPlug;

        if (!addr[plugContract]) return;

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
          return;
        }
        appConfigs.push({
          plugConfig: {
            appGatewayId: appGatewayId,
            switchboard: switchboard,
          },
          plug: addr[plugContract],
          chainSlug: chain,
        });

        // update fees manager
        const feesManager = (
          await getInstance(Contracts.FeesManager, addr[Contracts.FeesManager])
        ).connect(signer);

        const tx = await feesManager.functions["setFeesPlug"](
          chain,
          constants.AddressZero
        );
        console.log(`Updating Fees Manager tx hash: ${tx.hash}`);
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
