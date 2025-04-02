import { ChainAddressesObj, ChainSlug } from "../../src";

export type DeploymentAddresses = {
  [chainSlug in ChainSlug]?: ChainAddressesObj;
};
