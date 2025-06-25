import { ethers, Wallet } from "ethers";
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
  overrides,
  toBytes32FormatHexString,
} from "../utils";
import { getWatcherSigner, sendWatcherMultiCallWithNonce } from "../utils/sign";
import { isConfigSetOnEVMx, isConfigSetOnSocket } from "../utils";
import { mockForwarderSolanaOnChainAddress32Bytes } from "./1.deploy";

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
    switchboard,
    { ...(await overrides(chain)) }
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
          const switchboardBytes32Hex = toBytes32FormatHexString(
            addr[Contracts.FastSwitchboard]
          );
          const plugBytes32Hex = toBytes32FormatHexString(addr[plugContract]);
          // checkIfAddressExists(switchboard, "Switchboard");
          checkIfAppGatewayIdExists(appGatewayId, "AppGatewayId");

          if (!addr[plugContract]) {
            console.log(`${plugContract} not found on ${chain}`);
            continue;
          }

          if (
            await isConfigSetOnEVMx(
              configurationsContract,
              chain,
              plugBytes32Hex,
              appGatewayId,
              switchboardBytes32Hex
            )
          ) {
            console.log(`Config already set on ${chain} for ${plugContract}`);
            continue;
          }
          appConfigs.push({
            plugConfig: {
              appGatewayId: appGatewayId,
              switchboard: switchboardBytes32Hex,
            },
            plug: plugBytes32Hex,
            chainSlug: chain,
          });
        }
      })
    );

    //TODO:GW: This is a temporary workaround for th Solana POC
    //---
    const appGatewayAddress = process.env.APP_GATEWAY;
    if (!appGatewayAddress) throw new Error("APP_GATEWAY is not set");
    const solanaSwitchboard = process.env.SWITCHBOARD_SOLANA!.slice(2); // remove 0x prefix for Buffer from conversion
    if (!solanaSwitchboard) throw new Error("SWITCHBOARD_SOLANA is not set");

    const solanaSwitchboardBytes32 = Buffer.from(solanaSwitchboard, "hex");
    const solanaAppGatewayId = ethers.utils.hexZeroPad(appGatewayAddress, 32);

    console.log("SolanaAppGatewayId: ", solanaAppGatewayId);
    console.log(
      "SolanaSwitchboardBytes32: ",
      solanaSwitchboardBytes32.toString("hex")
    );

    appConfigs.push({
      plugConfig: {
        appGatewayId: solanaAppGatewayId,
        switchboard: "0x" + solanaSwitchboardBytes32.toString("hex"),
      },
      plug: "0x" + mockForwarderSolanaOnChainAddress32Bytes.toString("hex"),
      chainSlug: ChainSlug.SOLANA_DEVNET,
    });
    // appConfigs.push({
    //   plug: "0x" + mockForwarderSolanaOnChainAddress32Bytes.toString("hex"),
    //   appGatewayId: solanaAppGatewayId,
    //   switchboard: "0x" + solanaSwitchboardBytes32.toString("hex"),
    //   chainSlug: ChainSlug.SOLANA_DEVNET,
    // });
    //---

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
