import dev_addresses from "../../deployments/dev_addresses.json";
import stage_addresses from "../../deployments/stage_addresses.json";
// import local_addresses from "../../deployments/local_addresses.json";
import { ChainAddressesObj, DeploymentMode, EVMxAddressesObj } from "../../src";

export const getAddresses = (
  mode: DeploymentMode
): { [chainSlug: string | number]: ChainAddressesObj | EVMxAddressesObj } => {
  switch (mode) {
    // case DeploymentMode.LOCAL:
    //   return local_addresses;
    case DeploymentMode.DEV:
      // @ts-ignore
      return dev_addresses;
    case DeploymentMode.STAGE:
      // @ts-ignore
      return stage_addresses;
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};
