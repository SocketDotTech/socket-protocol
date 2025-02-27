time npx hardhat run hardhat-scripts/deploy/1.deploy.ts 
time npx hardhat run hardhat-scripts/deploy/2.roles.ts --no-compile
time npx hardhat run hardhat-scripts/deploy/3.upgradeManagers.ts --no-compile
time npx hardhat run hardhat-scripts/deploy/4.connect.ts --no-compile
time npx ts-node hardhat-scripts/deploy/5.upload.ts --resolveJsonModule
time npx hardhat run hardhat-scripts/deploy/6.setupEnv.ts --no-compile
time npx hardhat run hardhat-scripts/verify/verify.ts --no-compile
