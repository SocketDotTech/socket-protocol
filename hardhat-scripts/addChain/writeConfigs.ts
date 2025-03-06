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

const validateCoingeckoId = async (coingeckoId: string) => {
  if (!coingeckoId) {
    return "Invalid coingecko Id";
  }
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
