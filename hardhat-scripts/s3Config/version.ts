import { DeploymentMode } from "../../src";

export const version = {
  [DeploymentMode.LOCAL]: "1.0.17",
  [DeploymentMode.DEV]: "1.0.17",
  [DeploymentMode.STAGE]: "1.0.17",
  [DeploymentMode.PROD]: "1.0.17",
};
