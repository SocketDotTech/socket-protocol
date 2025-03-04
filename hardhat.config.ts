import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "hardhat-deploy";
import "hardhat-abi-exporter";
import "hardhat-change-network";
import { config as dotenvConfig } from "dotenv";
import type { HardhatUserConfig } from "hardhat/config";
import type {
  HardhatNetworkAccountUserConfig,
  NetworkUserConfig,
} from "hardhat/types";
import { resolve } from "path";
import fs from "fs";

import "./hardhat-scripts/utils/accounts";
import { getJsonRpcUrl } from "./hardhat-scripts/utils/networks";
import {
  ChainId,
  ChainSlug,
  ChainSlugToId,
  HardhatChainName,
  hardhatChainNameToSlug,
} from "@socket.tech/socket-protocol-common";
import { EVMX_CHAIN_ID } from "./hardhat-scripts/config/config";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// Ensure that we have all the environment variables we need.
// TODO: fix it for setup scripts
// if (!process.env.SOCKET_SIGNER_KEY) throw new Error("No private key found");
const privateKey: HardhatNetworkAccountUserConfig = process.env
  .SOCKET_SIGNER_KEY as unknown as HardhatNetworkAccountUserConfig;

function getChainConfig(chainSlug: ChainSlug): NetworkUserConfig {
  return {
    accounts: [`0x${privateKey}`],
    chainId: ChainSlugToId[chainSlug],
    url: getJsonRpcUrl(chainSlug),
  };
}

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

let liveNetworks = {
  [HardhatChainName.ARBITRUM_SEPOLIA]: getChainConfig(
    ChainSlug.ARBITRUM_SEPOLIA
  ),
  [HardhatChainName.OPTIMISM_SEPOLIA]: getChainConfig(
    ChainSlug.OPTIMISM_SEPOLIA
  ),
  [HardhatChainName.SEPOLIA]: getChainConfig(ChainSlug.SEPOLIA),
  EVMX: {
    accounts: [`0x${privateKey}`],
    chainId: EVMX_CHAIN_ID,
    url: process.env.EVMX_RPC,
  },
  ["base_sepolia"]: {
    accounts: [`0x${privateKey}`],
    chainId: ChainId.BASE_SEPOLIA,
    url: process.env.BASE_SEPOLIA_RPC,
  },
  ["interop_alpha_0"]: {
    accounts: [`0x${privateKey}`],
    chainId: ChainId.INTEROP_ALPHA_0,
    url: process.env.INTEROP_ALPHA_0_RPC,
  },
  ["interop_alpha_1"]: {
    accounts: [`0x${privateKey}`],
    chainId: ChainId.INTEROP_ALPHA_1,
    url: process.env.INTEROP_ALPHA_1_RPC,
  },
};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  abiExporter: {
    path: "artifacts/abi",
    flat: true,
  },
  networks: {
    hardhat: {
      chainId: hardhatChainNameToSlug[HardhatChainName.HARDHAT],
    },
    ...liveNetworks,
  },
  paths: {
    sources: "./contracts",
    cache: "./cache_hardhat",
    artifacts: "./artifacts",
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      arbitrumTestnet: process.env.ARBISCAN_API_KEY || "",
      baseTestnet: process.env.BASESCAN_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      bscTestnet: process.env.BSCSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      optimisticEthereum: process.env.OPTIMISM_API_KEY || "",
      optimisticTestnet: process.env.OPTIMISM_API_KEY || "",
      evmx: "none",
    },
    customChains: [
      {
        network: "optimisticTestnet",
        chainId: ChainId.OPTIMISM_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/",
        },
      },
      {
        network: "arbitrumTestnet",
        chainId: ChainId.ARBITRUM_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        },
      },
      {
        network: "baseTestnet",
        chainId: ChainId.BASE_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org/",
        },
      },
      {
        network: "interopAlpha0",
        chainId: ChainId.INTEROP_ALPHA_0,
        urls: {
          apiURL: "https://optimism-interop-alpha-0.blockscout.com/api",
          browserURL: "https://optimism-interop-alpha-0.blockscout.com/",
        },
      },
      {
        network: "interopAlpha1",
        chainId: ChainId.INTEROP_ALPHA_1,
        urls: {
          apiURL: "https://optimism-interop-alpha-1.blockscout.com/api",
          browserURL: "https://optimism-interop-alpha-1.blockscout.com/",
        },
      },
      {
        network: "evmx",
        chainId: EVMX_CHAIN_ID,
        urls: {
          apiURL: "",
          browserURL: "",
        },
      },
    ],
  },
  sourcify: {
    // Disabled by default
    // Doesn't need an API key
    enabled: true,
  },
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
  solidity: {
    version: "0.8.22",
    settings: {
      evmVersion: "paris",
      optimizer: {
        enabled: true,
        runs: 999,
        details: {
          yul: true,
          yulDetails: {
            stackAllocation: true,
          },
        },
      },
      viaIR: true,
    },
  },
};

export default config;
