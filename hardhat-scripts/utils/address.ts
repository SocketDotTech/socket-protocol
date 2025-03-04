import dev_addresses from "../../deployments/dev_addresses.json";
import stage_addresses from "../../deployments/stage_addresses.json";
import { DeploymentMode } from "@socket.tech/socket-protocol-common";

export const getAddresses = (mode: DeploymentMode) => {
  switch (mode) {
    case DeploymentMode.DEV:
      return dev_addresses;
    case DeploymentMode.STAGE:
      return stage_addresses;
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};
