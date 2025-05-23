export enum DeploymentMode {
  LOCAL = "local",
  DEV = "dev",
  PROD = "prod",
  STAGE = "stage",
}

export enum Events {
  // Socket
  ExecutionSuccess = "ExecutionSuccess",
  ExecutionFailed = "ExecutionFailed",
  PlugConnected = "PlugConnected",
  AppGatewayCallRequested = "AppGatewayCallRequested",
  AppGatewayCallFailed = "AppGatewayCallFailed",

  // FeesPlug
  FeesDeposited = "FeesDeposited",

  // Watcher
  CalledAppGateway = "CalledAppGateway",
  QueryRequested = "QueryRequested",
  FinalizeRequested = "FinalizeRequested",
  PromiseResolved = "PromiseResolved",
  PromiseNotResolved = "PromiseNotResolved",
  TimeoutRequested = "TimeoutRequested",
  TimeoutResolved = "TimeoutResolved",
  RequestSubmitted = "RequestSubmitted",
  Finalized = "Finalized",
  MarkedRevert = "MarkedRevert",
  ReadRequested = "ReadRequested",
  WriteProofRequested = "WriteProofRequested",
  WriteProofUploaded = "WriteProofUploaded",
  // AuctionManager
  AuctionEnded = "AuctionEnded",
  AuctionRestarted = "AuctionRestarted",

  // DeliveryHelper
  PayloadSubmitted = "PayloadSubmitted",
  PayloadAsyncRequested = "PayloadAsyncRequested",
  FeesIncreased = "FeesIncreased",
  RequestCancelled = "RequestCancelled",
}

export enum Contracts {
  Socket = "Socket",
  FeesPlug = "FeesPlug",
  ContractFactoryPlug = "ContractFactoryPlug",
  FastSwitchboard = "FastSwitchboard",
  SocketBatcher = "SocketBatcher",

  AddressResolver = "AddressResolver",
  Watcher = "Watcher",
  RequestHandler = "RequestHandler",
  Configurations = "Configurations",
  PromiseResolver = "PromiseResolver",
  AuctionManager = "AuctionManager",
  FeesManager = "FeesManager",
  WritePrecompile = "WritePrecompile",
  ReadPrecompile = "ReadPrecompile",
}

export enum CallTypeNames {
  READ = "READ",
  WRITE = "WRITE",
  SCHEDULE = "SCHEDULE",
}

export enum FinalityBucket {
  LOW, // low confirmations / latest
  MEDIUM, // medium confirmations / data posted
  HIGH, // high confirmations / data posted and finalized
}

export enum FinalityBucketNames {
  LOW = "LOW",
  MEDIUM = "MEDIUM",
  HIGH = "HIGH",
}
