export enum DeploymentMode {
  LOCAL = "local",
  DEV = "dev",
  PROD = "prod",
  STAGE = "stage",
}

export enum Events {
  ExecutionSuccess = "ExecutionSuccess",
  ExecutionFailed = "ExecutionFailed",
  PlugConnected = "PlugConnected",
  CalledAppGateway = "CalledAppGateway",
  AppGatewayCallRequested = "AppGatewayCallRequested",
  QueryRequested = "QueryRequested",
  FinalizeRequested = "FinalizeRequested",
  PromiseResolved = "PromiseResolved",
  PromiseNotResolved = "PromiseNotResolved",
  TimeoutRequested = "TimeoutRequested",
  TimeoutResolved = "TimeoutResolved",
  AuctionEnded = "AuctionEnded",
  AuctionRestarted = "AuctionRestarted",
  PayloadSubmitted = "PayloadSubmitted",
  PayloadAsyncRequested = "PayloadAsyncRequested",
  Finalized = "Finalized",
  FeesDeposited = "FeesDeposited",
  FeesIncreased = "FeesIncreased",
}

export enum Contracts {
  Socket = "Socket",
  FeesPlug = "FeesPlug",
  WatcherPrecompile = "WatcherPrecompile",
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
  LOW = 1, // low confirmations / latest
  MEDIUM = 2, // medium confirmations / data posted
  HIGH = 3, // high confirmations / data posted and finalized
}

export enum FinalityBucketNames {
  LOW = "LOW",
  MEDIUM = "MEDIUM",
  HIGH = "HIGH",
}
