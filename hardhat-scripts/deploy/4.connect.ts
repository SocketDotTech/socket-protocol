import { constants, Contract, ethers, Wallet } from "ethers";
import { ChainAddressesObj, ChainId, ChainSlug } from "../../src";
import { chains, EVMX_CHAIN_ID, mode } from "../config";
import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  EVMxCoreContracts,
} from "../constants";
import {
  getAddresses,
  getInstance,
  getSocketSigner,
  overrides,
  toBytes32Format,
  toBytes32FormatHexString,
} from "../utils";
import { getWatcherSigner, signWatcherMessage } from "../utils/sign";
import { mockForwarderSolanaOnChainAddress32Bytes } from "./1.deploy";
const plugs = [CORE_CONTRACTS.ContractFactoryPlug, CORE_CONTRACTS.FeesPlug];
export type AppGatewayConfig = {
  plug: string;
  appGatewayId: string;
  switchboard: string;
  chainSlug: number;
};
// Maps plug contracts to their corresponding app gateways
export const getAppGatewayId = (
  plug: string,
  addresses: DeploymentAddresses
) => {
  let address: string = "";
  switch (plug) {
    case CORE_CONTRACTS.ContractFactoryPlug:
      address = addresses?.[EVMX_CHAIN_ID]?.[EVMxCoreContracts.DeliveryHelper]; // TODO:GW: ask why DeliveryHelper referred as plug ?
      if (!address) throw new Error(`DeliveryHelper not found on EVMX`);
      return ethers.utils.hexZeroPad(address, 32);
    case CORE_CONTRACTS.FeesPlug:
      address = addresses?.[EVMX_CHAIN_ID]?.[EVMxCoreContracts.FeesManager]; // TODO:GW: ask why FeesManager is on EVMx it should only be on on-chain ?
      if (!address) throw new Error(`FeesManager not found on EVMX`);
      return ethers.utils.hexZeroPad(address, 32);
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
    throw Error(`${name} not found : ${address}`);
  }
  return address;
};
export const checkIfAppGatewayIdExists = (
  appGatewayId: string,
  name: string
) => {
  if (
    appGatewayId == constants.HashZero ||
    !appGatewayId ||
    appGatewayId == "0x" ||
    appGatewayId.length != 66
  ) {
    throw Error(`${name} not found : ${appGatewayId}`);
  }
  return appGatewayId;
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
    await getInstance(CORE_CONTRACTS.Socket, addr[CORE_CONTRACTS.Socket])
  ).connect(socketSigner);

  // Get switchboard and app gateway addresses
  const switchboard = addr[CORE_CONTRACTS.FastSwitchboard];
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
        await connectPlug(chain, plugContract, socketSigner, addresses, addr);
      }
    })
  );
};

export const isConfigSetOnEVMx = async (
  watcher: Contract,
  chain: number,
  plugHexStringBytes32: string,
  appGatewayId: string,
  switchboardHexStringBytes32: string
) => {
  const plugConfigRegistered = await watcher.getPlugConfigs(
    chain,
    toBytes32Format(plugHexStringBytes32)
  );
  return (
    plugConfigRegistered[0].toLowerCase() === appGatewayId?.toLowerCase() &&
    plugConfigRegistered[1].toLowerCase() ===
      switchboardHexStringBytes32.toLowerCase()
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
    const watcherPrecompileConfig = (
      await getInstance(
        EVMxCoreContracts.WatcherPrecompileConfig,
        EVMxAddresses[EVMxCoreContracts.WatcherPrecompileConfig]
      )
    ).connect(signer);

    // Collect configs for each chain and plug
    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;
        const addr = addresses[chain]!;

        for (const plugContract of plugs) {
          // TODO:GW: this method getAppGatewayId() should also probably be adjusted to hand bytes32 as plugContract and address ?
          const appGatewayId = getAppGatewayId(plugContract, addresses);
          const switchboard = addr[CORE_CONTRACTS.FastSwitchboard];
          const plugAddress = addr[plugContract];
          checkIfAddressExists(switchboard, "Switchboard");
          checkIfAppGatewayIdExists(appGatewayId, "AppGatewayId");
          const plugAddressHexStringBytes32 = toBytes32FormatHexString(plugAddress);
          const switchboardHexStringBytes32 = toBytes32FormatHexString(switchboard);

          if (
            await isConfigSetOnEVMx(
              watcherPrecompileConfig,
              chain,
              plugAddressHexStringBytes32,
              appGatewayId,
              switchboardHexStringBytes32
            )
          ) {
            console.log(`Config already set on ${chain} for ${plugContract}`);
            continue;
          }
          appConfigs.push({
            plug: plugAddressHexStringBytes32,  // mock address from ForwaderSolana on-chain address
            appGatewayId: appGatewayId,  // genrate as above
            switchboard: switchboardHexStringBytes32, // mock it manually 
            chainSlug: chain,   // use Solana chain slug
          });
        }
        
      })
    );
    //TODO:GW: This is a temporary workaround for th Solana POC
    //---
    const appGatewayAddress = process.env.APP_GATEWAY;
    if (!appGatewayAddress) throw new Error("APP_GATEWAY is not set");
    const solanaSwitchboard = process.env.SWITCHBOARD_SOLANA;
    if (!solanaSwitchboard) throw new Error("SWITCHBOARD_SOLANA is not set");

    const solanaSwitchboardBytes32 = Buffer.from(solanaSwitchboard, "hex");
    const solanaAppGatewayId = ethers.utils.hexZeroPad(appGatewayAddress, 32);

    console.log("SolanaAppGatewayId: ", solanaAppGatewayId);
    console.log("SolanaSwitchboardBytes32: ", solanaSwitchboardBytes32);

    appConfigs.push({
      plug: "0x" + mockForwarderSolanaOnChainAddress32Bytes.toString("hex"),
      appGatewayId: solanaAppGatewayId,
      // switchboard: "0x" + mockSwitchboardSolanaAddress32Bytes.toString("hex"),
      switchboard: "0x" + solanaSwitchboardBytes32.toString("hex"),
      chainSlug: ChainId.SOLANA_DEVNET,
    });
    //---

    // Update configs if any changes needed
    if (appConfigs.length > 0) {
      console.log({ appConfigs });
      const encodedMessage = ethers.utils.defaultAbiCoder.encode(
        [
          "bytes4",
          "tuple(bytes32 plug,bytes32 appGatewayId,bytes32 switchboard,uint32 chainSlug)[]",
        ],
        [
          watcherPrecompileConfig.interface.getSighash("setAppGateways"),
          appConfigs,
        ]
      );
      const { nonce, signature } = await signWatcherMessage(
        encodedMessage,
        watcherPrecompileConfig.address
      );
      const tx = await watcherPrecompileConfig.setAppGateways(
        appConfigs,
        nonce,
        signature,
        { ...overrides(EVMX_CHAIN_ID) }
      );
      console.log(`Updating EVMx Config tx hash: ${tx.hash}`);
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
    await updateConfigEVMx();
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
