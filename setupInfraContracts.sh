if [ "$1" = "skip-compile" ]; then
  time npx hardhat run hardhat-scripts/deploy/1.deploy.ts --no-compile
else
  time npx hardhat run hardhat-scripts/deploy/1.deploy.ts
fi
time npx hardhat run hardhat-scripts/deploy/2.roles.ts --no-compile
time npx hardhat run hardhat-scripts/deploy/3.upgradeManagers.ts --no-compile
time npx hardhat run hardhat-scripts/deploy/4.connect.ts --no-compile
time npx ts-node hardhat-scripts/deploy/5.upload.ts --resolveJsonModule
time npx hardhat run hardhat-scripts/deploy/6.setupEnv.ts --no-compile
time npx hardhat run hardhat-scripts/misc-scripts/errorCodes.ts --no-compile
time npx hardhat run hardhat-scripts/misc-scripts/eventTopics.ts --no-compile
time npx hardhat run hardhat-scripts/misc-scripts/functionSigs.ts --no-compile
time npx hardhat run hardhat-scripts/verify/verify.ts --no-compile
# yarn lint 