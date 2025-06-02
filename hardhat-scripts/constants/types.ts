import { ChainAddressesObj, ChainSlug } from "../../src";

export type DeploymentAddresses = {
  [chainSlug in ChainSlug]?: ChainAddressesObj;
};

export type TokenMap = { [key: string]: { [chainSlug: number]: string[] } };

export interface WatcherMultiCallParams {
  contractAddress: string;
  data: string;
  nonce: number;
  signature: string;
}
