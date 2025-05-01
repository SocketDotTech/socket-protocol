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

  // WatcherPrecompile
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
  WatcherPrecompile = "WatcherPrecompile",
  WatcherPrecompileLimits = "WatcherPrecompileLimits",
  WatcherPrecompileConfig = "WatcherPrecompileConfig",
  AuctionManager = "AuctionManager",
  DeliveryHelper = "DeliveryHelper",
}

export enum CallType {
  READ,
  WRITE,
  DEPLOY,
  WITHDRAW,
}

export enum CallTypeNames {
  READ = "READ",
  WRITE = "WRITE",
  DEPLOY = "DEPLOY",
  WITHDRAW = "WITHDRAW",
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
