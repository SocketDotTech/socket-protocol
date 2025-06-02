import { DeploymentMode } from "../../src";
import { TokenMap } from "./types";

const tokens: TokenMap = {
    [DeploymentMode.DEV]: {
        421614: ["0x2321BF7AdFaf49b1338F1Cd474859dBc0D8dfA96"],
        11155420: ["0x15dbE4B96306Cc9Eba15D834d6c1a895cF4e1697"]
    },
    [DeploymentMode.STAGE]: {
        84532: ["0xfD51918C0572512901fFA79F822c99A475d22BB4"],
        421614: ["0xa03Cbf13f331aF7c0fD7F2E28E6Cbc13F879E3F3"],
        11155420: ["0xa0E1738a9Fc0698789866e09d7A335d30128C5C5"],
        11155111: ["0xbcaDE56f86a819994d0F66b98e921C484bE6FE4e"]
    }
};

const feePools: { [key: string]: string } = {
    [DeploymentMode.DEV]: "0xc20Be67ef742202dc93A78aa741E7C3715eA1DFd",
    [DeploymentMode.STAGE]: ""
};

export const getFeeTokens = (mode: DeploymentMode, chainSlug: number): string[] => {
    return tokens[mode][chainSlug] || [];
};

export const getFeePool = (mode: DeploymentMode): string => {
    return feePools[mode];
};


