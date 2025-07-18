import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { Contract, Signer, Wallet } from "ethers";
import { ChainAddressesObj, ChainSlug, Contracts } from "../../src";
import { chains, EVMX_CHAIN_ID, MAX_MSG_VALUE_LIMIT, mode } from "../config";
import {
  DeploymentAddresses,
  FAST_SWITCHBOARD_TYPE,
  getFeeTokens,
} from "../constants";
import {
  getAddresses,
  getInstance,
  getSocketSigner,
  getWatcherSigner,
  overrides,
  updateContractSettings,
} from "../utils";

export const main = async () => {
  let addresses: DeploymentAddresses;
  try {
    console.log("Configuring chain contracts");
    addresses = getAddresses(mode) as unknown as DeploymentAddresses;
    await configureChains(addresses);
  } catch (error) {
    console.log("Error:", error);
  }
};

export const configureChains = async (addresses: DeploymentAddresses) => {
  for (const chain of chains) {
    let chainAddresses: ChainAddressesObj = addresses[chain]
      ? (addresses[chain] as ChainAddressesObj)
      : ({} as ChainAddressesObj);

    const signer: Wallet = getSocketSigner(chain as ChainSlug);

    const socketContract = (
      await getInstance(Contracts.Socket, chainAddresses[Contracts.Socket])
    ).connect(signer);

    await registerSb(
      chain,
      chainAddresses[Contracts.FastSwitchboard],
      signer,
      socketContract
    );

    if (chainAddresses[Contracts.FeesPlug]) {
      await whitelistToken(chain, chainAddresses[Contracts.FeesPlug], signer);
    }

    await setMaxMsgValueLimit(chain);

    await setOnchainContracts(chain, addresses);
  }
};

export const setMaxMsgValueLimit = async (chain: number) => {
  console.log("Setting max msg value limit");
  const signer: Wallet = getWatcherSigner();
  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.WritePrecompile,
    "chainMaxMsgValueLimit",
    [chain],
    MAX_MSG_VALUE_LIMIT,
    "updateChainMaxMsgValueLimits",
    [chain, MAX_MSG_VALUE_LIMIT],
    signer
  );
};

async function setOnchainContracts(
  chain: number,
  addresses: DeploymentAddresses
) {
  console.log("Setting onchain contracts");
  const signer: Wallet = getWatcherSigner();
  const chainAddresses = addresses[chain] as ChainAddressesObj;

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.Configurations,
    "switchboards",
    [chain, FAST_SWITCHBOARD_TYPE],
    chainAddresses[Contracts.FastSwitchboard],
    "setSwitchboard",
    [chain, FAST_SWITCHBOARD_TYPE, chainAddresses[Contracts.FastSwitchboard]],
    signer
  );
  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.Configurations,
    "sockets",
    [chain],
    chainAddresses[Contracts.Socket],
    "setSocket",
    [chain, chainAddresses[Contracts.Socket]],
    signer
  );

  if (chainAddresses[Contracts.FeesPlug])
    await updateContractSettings(
      EVMX_CHAIN_ID,
      Contracts.FeesManager,
      "feesPlugs",
      [chain],
      chainAddresses[Contracts.FeesPlug],
      "setFeesPlug",
      [chain, chainAddresses[Contracts.FeesPlug]],
      signer
    );

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.WritePrecompile,
    "contractFactoryPlugs",
    [chain],
    chainAddresses[Contracts.ContractFactoryPlug],
    "setContractFactoryPlugs",
    [chain, chainAddresses[Contracts.ContractFactoryPlug]],
    signer
  );
}

const registerSb = async (
  chain: number,
  sbAddress: string,
  signer: Wallet,
  socket: Contract
) => {
  try {
    console.log("Registering switchboard");
    // used fast switchboard here as all have same function signature
    const switchboard = (
      await getInstance(Contracts.FastSwitchboard, sbAddress)
    ).connect(signer);

    // send overrides while reading capacitor to avoid errors on mantle chain
    // some chains give balance error if gas price is used with from address as zero
    // therefore override from address as well
    let sb = await socket.isValidSwitchboard(sbAddress, {
      from: signer.address,
    });

    if (Number(sb) == 0) {
      const registerTx = await switchboard.registerSwitchboard({
        ...(await overrides(chain)),
      });
      console.log(`Registering Switchboard ${sbAddress}: ${registerTx.hash}`);
      await registerTx.wait();
    }
  } catch (error) {
    throw error;
  }
};

export const whitelistToken = async (
  chain: number,
  feesPlugAddress: string,
  signer: Signer
) => {
  console.log("Whitelisting token");

  const feesPlugContract = (
    await getInstance(Contracts.FeesPlug, feesPlugAddress)
  ).connect(signer);

  const tokens = getFeeTokens(mode, chain);
  if (tokens.length == 0) return;

  for (const token of tokens) {
    const isWhitelisted = await feesPlugContract.whitelistedTokens(token);

    if (!isWhitelisted) {
      const tx = await feesPlugContract.whitelistToken(token, {
        ...(await overrides(chain)),
      });
      console.log(
        `Whitelisting token ${token} for ${feesPlugContract.address}`,
        tx.hash
      );
      await tx.wait();
    } else {
      console.log(`Token ${token} is already whitelisted`);
    }
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
