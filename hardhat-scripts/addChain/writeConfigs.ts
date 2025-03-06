import { StaticJsonRpcProvider } from "@ethersproject/providers";
import { utils } from "ethers";
import prompts from "prompts";

import { ChainId, ChainType, NativeTokens } from "../../src";
import { updateSDK } from "./utils";

export async function addChainToSDK() {
  const currencyChoices = [...Object.keys(NativeTokens), "other"];

  const rpcResponse = await prompts([
    {
      name: "rpc",
      type: "text",
      message: "Enter rpc url",
      validate: validateRpc,
    },
    {
      name: "chainName",
      type: "text",
      message:
        "Enter chain name (without spaces, use underscore instead of spaces)",
    },
  ]);

  const chainId = await getChainId(rpcResponse.rpc);

  const filteredChain = Object.values(ChainId).filter((c) => c == chainId);
  if (filteredChain.length > 0) {
    console.log("Chain already added!");
    return {
      response: { rpc: rpcResponse.rpc, chainName: rpcResponse.chainName },
      chainId,
      isAlreadyAdded: true,
    };
  }

  const response = await prompts([
    {
      name: "isMainnet",
      type: "toggle",
      message: "Is it a mainnet?",
    },
    {
      name: "chainType",
      type: "select",
      message: "Select the rollup type (select default if not)",
      choices: [...Object.keys(ChainType)].map((type) => ({
        title: type,
        value: type,
      })),
    },
    {
      name: "currency",
      type: "select",
      message: "Select the native token",
      choices: currencyChoices.map((choice) => ({
        title: choice,
        value: choice,
      })),
    },
    // {
    //   name: "explorer",
    //   type: "text",
    //   message: "Enter the block explorer url",
    // },
    // {
    //   name: "icon",
    //   type: "text",
    //   message: "Enter the icon url",
    // },
  ]);

  let isNewNative = false;
  let currency = currencyChoices[response.currency];
  if (response.currency == currencyChoices.length - 1) {
    const currencyPromptResponse = await prompts([
      {
        name: "coingeckoId",
        type: "text",
        message: "Enter coingecko id of your token",
        validate: validateCoingeckoId,
      },
    ]);

    isNewNative = true;
    currency = currencyPromptResponse.coingeckoId;
  }

  // update types and enums
  await updateSDK(
    rpcResponse.chainName,
    chainId,
    currency,
    response.chainType,
    response.isMainnet,
    isNewNative
  );

  return { response, chainId, isAlreadyAdded: false };
}

export async function writeConfigs() {
  const { response, chainId } = await addChainToSDK();

  // const chainOptions = response.isMainnet ? MainnetIds : TestnetIds;
  // const choices = chainOptions.map((chain) => ({
  //   title: chain.toString(),
  //   value: chain,
  // }));

  // const configResponse = await prompts([
  //   // {
  //   //   name: "siblings",
  //   //   type: "multiselect",
  //   //   message: "Select chains to connect",
  //   //   choices,
  //   // },
  //   // {
  //   //   name: "owner",
  //   //   type: "text",
  //   //   message:
  //   //     "Enter deployer address (this will be owner initially to configure roles)",
  //   //   validate: validateAddress,
  //   // },
  //   {
  //     name: "transmitter",
  //     type: "text",
  //     message:
  //       "Enter transmitter address (skip this for standard contract deployment)",
  //     validate: validateAddress,
  //   },
  //   {
  //     name: "executor",
  //     type: "text",
  //     message:
  //       "Enter executor address (skip this for standard contract deployment)",
  //     validate: validateAddress,
  //   },
  //   {
  //     name: "watcher",
  //     type: "text",
  //     message:
  //       "Enter watcher address (skip this for standard contract deployment)",
  //     validate: validateAddress,
  //   },
  //   {
  //     name: "feeUpdater",
  //     type: "text",
  //     message:
  //       "Enter fee updater address (skip this for standard contract deployment)",
  //     validate: validateAddress,
  //   },
  //   {
  //     name: "pk",
  //     type: "text",
  //     message:
  //       "Enter deployer private key (can be left blank and added to env as SOCKET_SIGNER_KEY)",
  //   },
  //   {
  //     name: "timeout",
  //     type: "text",
  //     message: "Enter timeout, skip if you want to keep it default (2 hrs)",
  //   },
  //   {
  //     name: "msgValueMaxThreshold",
  //     type: "text",
  //     message:
  //       "Enter max msg value transfer limit, skip if you want to keep it default (0.01 ETH)",
  //   },
  //   {
  //     name: "type",
  //     type: "text",
  //     message:
  //       "Enter transaction type supported, skip if you want it to be picked from RPC",
  //   },
  //   {
  //     name: "gasLimit",
  //     type: "text",
  //     message: "Enter max gas limit, skip if you want it to be picked from RPC",
  //   },
  //   {
  //     name: "gasPrice",
  //     type: "text",
  //     message: "Enter gas price, skip if you want it to be picked from RPC",
  //   },
  // ]);

  // // update env and config
  // const roleOwners: RoleOwners = {
  //   ownerAddress: "",
  //   executorAddress: "",
  //   transmitterAddress: "",
  //   watcherAddress: "",
  //   feeUpdaterAddress: "",
  // };

  // if (configResponse.owner) {
  //   roleOwners.ownerAddress = configResponse.owner;
  // } else roleOwners.ownerAddress = ownerAddresses[DeploymentMode.PROD];

  // if (configResponse.transmitter) {
  //   roleOwners.transmitterAddress = configResponse.transmitter;
  // } else
  //   roleOwners.transmitterAddress = transmitterAddresses[DeploymentMode.PROD];

  // if (configResponse.executor) {
  //   roleOwners.executorAddress = configResponse.executor;
  // } else roleOwners.executorAddress = executorAddresses[DeploymentMode.PROD];

  // if (configResponse.watcher) {
  //   roleOwners.watcherAddress = configResponse.watcher;
  // } else roleOwners.watcherAddress = watcherAddresses[DeploymentMode.PROD];

  // if (configResponse.feeUpdater) {
  //   roleOwners.feeUpdaterAddress = configResponse.feeUpdater;
  // } else
  //   roleOwners.feeUpdaterAddress = transmitterAddresses[DeploymentMode.PROD];

  // // write chain config and env for NEW_RPC and SOCKET_SIGNER_KEY
  // const config = {
  //   roleOwners,
  //   siblings: configResponse.siblings,
  //   overrides: {},
  // };

  // if (configResponse.timeout) config["timeout"] = configResponse.timeout;
  // if (configResponse.msgValueMaxThreshold)
  //   config["msgValueMaxThreshold"] = configResponse.msgValueMaxThreshold;
  // if (configResponse.type) config["overrides"]["type"] = configResponse.type;
  // if (configResponse.gasLimit)
  //   config["overrides"]["gasLimit"] = configResponse.gasLimit;
  // if (configResponse.gasPrice)
  //   config["overrides"]["gasPrice"] = configResponse.gasPrice;

  // await updateConfig(chainId as ChainSlug, config);

  // let pk = configResponse.pk ?? "";
  // if (configResponse.pk && configResponse.pk.length > 64)
  //   pk = configResponse.pk.substring(2);

  // await buildEnvFile(response.rpc, roleOwners.ownerAddress, pk);
}

const validateCoingeckoId = async (coingeckoId: string) => {
  if (!coingeckoId) {
    return "Invalid coingecko Id";
  }

  // todo use either public api key or a list cached somewhere in dl updated frequently
  return true;
};

const validateRpc = async (rpcUrl: string) => {
  if (!rpcUrl) {
    return "Invalid RPC";
  }
  return getChainId(rpcUrl)
    .then((a) => true)
    .catch((e) => `Invalid RPC: ${e}`);
};

const validateAddress = (address: string) => {
  if (!address || address.length === 0) return true;
  return utils.isAddress(address);
};

const getChainId = async (rpcUrl: string) => {
  const provider = new StaticJsonRpcProvider(rpcUrl);
  const network = await provider.getNetwork();
  return network.chainId;
};
