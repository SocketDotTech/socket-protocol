import { FinalityBucket } from "./enums";

export enum ChainType {
  opStackL2Chain = "opStackL2Chain",
  arbL3Chain = "arbL3Chain",
  arbChain = "arbChain",
  polygonCDKChain = "polygonCDKChain",
  zkStackChain = "zkStackChain",
  default = "default",
}

export type ChainFinalityBlocks = {
  [FinalityBucket.LOW]: number | "safe" | "finalized";
  [FinalityBucket.MEDIUM]: number | "safe" | "finalized";
  [FinalityBucket.HIGH]: number | "safe" | "finalized";
};

export type ChainAddressesObj = {
  Socket: string;
  SocketBatcher: string;
  FastSwitchboard: string;
  ContractFactoryPlug: string;
  SocketFeesManager?: string;
  FeesPlug?: string;
  startBlock: number;
};

export type EVMxAddressesObj = {
  AddressResolver: string;
  AsyncDeployer: string;
  AuctionManager: string;
  Configurations: string;
  DeployForwarder: string;
  FeesManager: string;
  FeesPool: string;
  PromiseResolver: string;
  ReadPrecompile: string;
  RequestHandler: string;
  SchedulePrecompile: string;
  Watcher: string;
  WritePrecompile: string;
  ERC1967Factory: string;
  startBlock: number;
};

export type S3Config = {
  version: string;
  chains: { [chainSlug: number]: ChainConfig };
  supportedChainSlugs: number[];
  testnetChainSlugs: number[];
  mainnetChainSlugs: number[];
};

export type ChainConfig = {
  eventBlockRangePerCron: number;
  rpc: string | undefined;
  wssRpc: string | undefined;
  confirmations: number;
  eventBlockRange: number;
  addresses: ChainAddressesObj | EVMxAddressesObj;
  finalityBlocks: ChainFinalityBlocks;
  chainType: ChainType;
};

export { FinalityBucket };
