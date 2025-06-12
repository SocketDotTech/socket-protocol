import { Wallet, utils } from "ethers";
import { network, ethers, run } from "hardhat";

import { ContractFactory, Contract } from "ethers";
import { Address } from "hardhat-deploy/dist/types";
import path from "path";
import fs from "fs";
import { ChainAddressesObj, ChainSlug, DeploymentMode } from "../../src";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { overrides } from "../utils";
import { VerifyArgs } from "../verify";
import { DeploymentAddresses } from "../constants";

export const deploymentsPath = path.join(__dirname, `/../../deployments/`);

export const deployedAddressPath = (mode: DeploymentMode) =>
  deploymentsPath + `${mode}_addresses.json`;

export const getRoleHash = (role: string) =>
  ethers.utils.keccak256(ethers.utils.toUtf8Bytes(role)).toString();

export const getChainRoleHash = (role: string, chainSlug: number) =>
  ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "uint32"],
      [getRoleHash(role), chainSlug]
    )
  );

export interface DeployParams {
  addresses: ChainAddressesObj;
  mode: DeploymentMode;
  signer: SignerWithAddress | Wallet;
  currentChainSlug: number;
}

export const getOrDeploy = async (
  keyName: string,
  contractName: string,
  path: string,
  args: any[],
  deployUtils: DeployParams
): Promise<Contract> => {
  if (!deployUtils || !deployUtils.addresses)
    throw new Error("No addresses found");

  let contract: Contract;
  if (!deployUtils.addresses[keyName]) {
    contract = await deployContractWithArgs(
      path + `:${contractName}`,
      args,
      deployUtils.signer,
      deployUtils.currentChainSlug
    );

    console.log(
      `${contractName} deployed on ${deployUtils.currentChainSlug} for ${deployUtils.mode} at address ${contract.address}`
    );

    await storeVerificationParams(
      [contract.address, contractName, path, args],
      deployUtils.currentChainSlug,
      deployUtils.mode
    );
  } else {
    contract = await getInstance(
      path + `:${contractName}`,
      deployUtils.addresses[keyName]
    );
    console.log(
      `${contractName} found on ${deployUtils.currentChainSlug} for ${deployUtils.mode} at address ${contract.address}`
    );
  }

  return contract;
};

export async function deployContractWithArgs(
  contractName: string,
  args: Array<any>,
  signer: SignerWithAddress | Wallet,
  chainSlug: ChainSlug
) {
  try {
    console.log("deploying", contractName, args);
    const Contract: ContractFactory = await ethers.getContractFactory(
      contractName
    );

    // gasLimit is set to undefined to not use the value set in overrides
    const contract: Contract = await Contract.connect(signer).deploy(...args, {
      ...(await overrides(chainSlug)),
    });
    await contract.deployed();
    return contract;
  } catch (error) {
    throw error;
  }
}

export const verify = async (
  address: string,
  contractName: string,
  path: string,
  args: any[]
): Promise<boolean> => {
  try {
    const chainSlug = await getChainSlug();
    if (chainSlug === 31337) return true;

    await run("verify:verify", {
      address,
      contract: `${path}:${contractName}`,
      constructorArguments: args,
    });
    return true;
  } catch (error) {
    console.log("Error during verification", error);
    if (error.toString().includes("Contract source code already verified"))
      return true;
  }

  return false;
};

export const getInstance = async (
  contractName: string,
  address: Address
): Promise<Contract> =>
  (await ethers.getContractFactory(contractName)).attach(address);

export const getChainSlug = async (): Promise<number> => {
  if (network.config.chainId === undefined)
    throw new Error("chain id not found");
  return Number(network.config.chainId);
};

export const integrationType = (integrationName: string) =>
  ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(["string"], [integrationName])
  );

export const storeAddresses = async (
  addresses: ChainAddressesObj,
  chainSlug: ChainSlug,
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath, { recursive: true });
  }

  const addressesPath = deploymentsPath + `${mode}_addresses.json`;
  const outputExists = fs.existsSync(addressesPath);
  let deploymentAddresses: DeploymentAddresses = {};
  if (outputExists) {
    const deploymentAddressesString = fs.readFileSync(addressesPath, "utf-8");
    deploymentAddresses = JSON.parse(deploymentAddressesString);
  }

  // Sort addresses object by key name for readability
  const sortedAddresses = Object.fromEntries(
    Object.entries(addresses).sort(([keyA], [keyB]) => keyA.localeCompare(keyB))
  ) as ChainAddressesObj;

  deploymentAddresses[chainSlug] = sortedAddresses;
  fs.writeFileSync(
    addressesPath,
    JSON.stringify(deploymentAddresses, null, 2) + "\n"
  );
};

export const storeUnVerifiedParams = async (
  verifyParams: VerifyArgs[],
  chainSlug: ChainSlug,
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath, { recursive: true });
  }

  const verificationPath = deploymentsPath + `${mode}_verification.json`;
  const outputExists = fs.existsSync(verificationPath);
  let verificationDetails: object = {};
  if (outputExists) {
    const verificationDetailsString = fs.readFileSync(
      verificationPath,
      "utf-8"
    );
    verificationDetails = JSON.parse(verificationDetailsString);
  }

  verificationDetails[chainSlug] = verifyParams;
  fs.writeFileSync(
    verificationPath,
    JSON.stringify(verificationDetails, null, 2) + "\n"
  );
};

export const storeAllAddresses = async (
  addresses: DeploymentAddresses,
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath, { recursive: true });
  }

  const addressesPath = deploymentsPath + `${mode}_addresses.json`;
  fs.writeFileSync(addressesPath, JSON.stringify(addresses, null, 2) + "\n");
};

export const storeVerificationParams = async (
  verificationDetail: any[],
  chainSlug: ChainSlug,
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath);
  }
  const verificationPath = deploymentsPath + `${mode}_verification.json`;
  const outputExists = fs.existsSync(verificationPath);
  let verificationDetails: object = {};
  if (outputExists) {
    const verificationDetailsString = fs.readFileSync(
      verificationPath,
      "utf-8"
    );
    verificationDetails = JSON.parse(verificationDetailsString);
  }

  if (!verificationDetails[chainSlug]) verificationDetails[chainSlug] = [];
  verificationDetails[chainSlug] = [
    verificationDetail,
    ...verificationDetails[chainSlug],
  ];

  fs.writeFileSync(
    verificationPath,
    JSON.stringify(verificationDetails, null, 2) + "\n"
  );
};

export const getChainSlugsFromDeployedAddresses = async (
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath);
  }
  const addressesPath = deploymentsPath + `${mode}_addresses.json`;

  const outputExists = fs.existsSync(addressesPath);
  let deploymentAddresses: DeploymentAddresses = {};
  if (outputExists) {
    const deploymentAddressesString = fs.readFileSync(addressesPath, "utf-8");
    deploymentAddresses = JSON.parse(deploymentAddressesString);

    return Object.keys(deploymentAddresses);
  }
};

export const getRelayUrl = async (mode: DeploymentMode) => {
  switch (mode) {
    case DeploymentMode.STAGE:
      return process.env.RELAYER_URL_STAGE;
    case DeploymentMode.PROD:
      return process.env.RELAYER_URL_PROD;
    default:
      return process.env.RELAYER_URL_DEV;
  }
};

export const getRelayAPIKEY = (mode: DeploymentMode) => {
  switch (mode) {
    case DeploymentMode.STAGE:
      return process.env.RELAYER_API_KEY_STAGE;
    case DeploymentMode.PROD:
      return process.env.RELAYER_API_KEY_PROD;
    default:
      return process.env.RELAYER_API_KEY_DEV;
  }
};

export const getAPIBaseURL = (mode: DeploymentMode) => {
  switch (mode) {
    case DeploymentMode.PROD:
      return process.env.DL_API_PROD_URL;
    default:
      return process.env.DL_API_DEV_URL;
  }
};

export const createObj = function (
  obj: ChainAddressesObj,
  keys: string[],
  value: any
): ChainAddressesObj {
  if (keys.length === 1) {
    obj[keys[0]] = value;
  } else {
    const key = keys.shift();
    if (key === undefined) return obj;
    obj[key] = createObj(
      typeof obj[key] === "undefined" ? {} : obj[key],
      keys,
      value
    );
  }
  return obj;
};

export const toLowerCase = (str?: string) => {
  if (!str) return "";
  return str.toLowerCase();
};

export function getChainSlugFromId(chainId: number) {
  const MAX_UINT_32 = 4294967295;
  if (chainId < MAX_UINT_32) return chainId;

  // avoid conflict for now
  return parseInt(utils.id(chainId.toString()).substring(0, 10));
}

// TODO: move this to socket-common
export function toBytes32FormatHexString(hexString: string): string {
  // this means that the string is already in bytes32 format with or without 0x prefix
  if (hexString.length == 64 || hexString.length == 66) {
    return hexString;
  }
  // Remove the '0x' prefix from the input string if it's present
  const cleanedHexString = hexString.startsWith("0x")
    ? hexString.slice(2)
    : hexString;

  const buffer = Buffer.alloc(32);
  buffer.write(cleanedHexString, 32 - cleanedHexString.length / 2, "hex"); // each hex char is 2 bytes

  return "0x" + buffer.toString("hex");
}

export function toBytes32Format(hexString: string): number[] {
  const hex32Format = toBytes32FormatHexString(hexString);
  const cleanedHex32String = hex32Format.startsWith("0x")
    ? hex32Format.slice(2)
    : hex32Format;

  return Array.from(Buffer.from(cleanedHex32String, "hex"));
}
