import { DeploymentMode } from "../../src";
import { TokenMap } from "./types";

const tokens: TokenMap = {
    [DeploymentMode.DEV]: {
        421614: ["0x2321BF7AdFaf49b1338F1Cd474859dBc0D8dfA96"],
        11155420: ["0x15dbE4B96306Cc9Eba15D834d6c1a895cF4e1697"]
    },
    [DeploymentMode.STAGE]: {}
};

const feePools: { [key: string]: string } = {
    [DeploymentMode.DEV]: "0xc20Be67ef742202dc93A78aa741E7C3715eA1DFd",
    [DeploymentMode.STAGE]: "0x15dbE4B96306Cc9Eba15D834d6c1a895cF4e1697"
};


export const getFeeTokens = (mode: DeploymentMode, chainSlug: number): string[] => {
    return tokens[mode][chainSlug] || [];
};

export const getFeePool = (mode: DeploymentMode): string => {
    return feePools[mode];
};


