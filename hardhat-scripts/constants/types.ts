export type ChainAddressesObj = {
  Socket: string;
  SocketBatcher: string;
  FastSwitchboard: string;
  FeesPlug: string;
  ContractFactoryPlug: string;
  startBlock: number;
};

export type CloudAddressesObj = {
  SignatureVerifier: string;
  AddressResolver: string;
  WatcherPrecompile: string;
  AuctionManager: string;
  FeesManager: string;
  DeliveryHelper: string;
  startBlock: number;
};
