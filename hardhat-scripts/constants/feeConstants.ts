import { DeploymentMode } from "../../src";
import { mode } from "../config";
import { TokenMap } from "./types";

const tokens: TokenMap = {
  [DeploymentMode.DEV]: {
    421614: ["0x2321BF7AdFaf49b1338F1Cd474859dBc0D8dfA96"],
    11155420: ["0x15dbE4B96306Cc9Eba15D834d6c1a895cF4e1697"],
  },
  [DeploymentMode.STAGE]: {
    8453: ["0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"],
    42161: ["0xaf88d065e77c8cc2239327c5edb3a432268e5831"],
    10: ["0x0b2c639c533813f4aa9d7837caf62653d097ff85"],
  },
};

const feePools: { [key: string]: string } = {
  [DeploymentMode.DEV]: "0xc20Be67ef742202dc93A78aa741E7C3715eA1DFd",
  [DeploymentMode.STAGE]: "0xe2054B575664dfDBD7a7FbAf2B12420ae88DE0FF",
};

export const getFeeTokens = (chainSlug: number): string[] => {
  return tokens[mode][chainSlug] || [];
};

export const getFeePool = (): string => {
  return feePools[mode];
};
