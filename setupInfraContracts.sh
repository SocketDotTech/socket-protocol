npx hardhat run hardhat-scripts/deploy/1.deploy.ts --no-compile
npx hardhat run hardhat-scripts/deploy/2.roles.ts --no-compile
npx hardhat run hardhat-scripts/deploy/3.upgradeManagers.ts --no-compile
npx hardhat run hardhat-scripts/deploy/4.connect.ts --no-compile
export AWS_PROFILE=lldev && npx ts-node hardhat-scripts/deploy/5.upload.ts --resolveJsonModule
npx hardhat run hardhat-scripts/deploy/6.setupEnv.ts --no-compile
npx hardhat run hardhat-scripts/verify/verify.ts --no-compile
