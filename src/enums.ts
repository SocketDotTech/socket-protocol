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

  // FeesPlug
  FeesDeposited = "FeesDeposited",

  // Watcher
  TriggerFailed = "TriggerFailed",
  TriggerSucceeded = "TriggerSucceeded",

  // PromiseResolver
  PromiseResolved = "PromiseResolved",
  PromiseNotResolved = "PromiseNotResolved",
  MarkedRevert = "MarkedRevert",

  // RequestHandler
  RequestSubmitted = "RequestSubmitted",
  RequestCancelled = "RequestCancelled",
  FeesIncreased = "FeesIncreased",

  // WritePrecompile
  WriteProofRequested = "WriteProofRequested",
  WriteProofUploaded = "WriteProofUploaded",

  // ReadPrecompile
  ReadRequested = "ReadRequested",

  // SchedulePrecompile
  ScheduleRequested = "ScheduleRequested",
  ScheduleResolved = "ScheduleResolved",

  // AuctionManager
  AuctionEnded = "AuctionEnded",
  AuctionRestarted = "AuctionRestarted",
}

export enum Contracts {
  Socket = "Socket",
  FeesPlug = "FeesPlug",
  ContractFactoryPlug = "ContractFactoryPlug",
  FastSwitchboard = "FastSwitchboard",
  SocketBatcher = "SocketBatcher",
  SocketFeeManager = "SocketFeeManager",
  AddressResolver = "AddressResolver",
  Watcher = "Watcher",
  RequestHandler = "RequestHandler",
  Configurations = "Configurations",
  PromiseResolver = "PromiseResolver",
  AuctionManager = "AuctionManager",
  FeesManager = "FeesManager",
  WritePrecompile = "WritePrecompile",
  ReadPrecompile = "ReadPrecompile",
  SchedulePrecompile = "SchedulePrecompile",
  FeesPool = "FeesPool",
  AsyncDeployer = "AsyncDeployer",
  DeployForwarder = "DeployForwarder",
  ForwarderSolana = "ForwarderSolana",
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
