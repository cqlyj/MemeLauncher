export function getContractData(chainId) {
  if (!chainId) {
    throw new Error("ChainId is required.");
  }

  const contractTransaction = require(`../../broadcast/DeployLauncher.s.sol/${chainId}/run-latest.json`);
  const abi = require("../../abi/Launcher.json");

  return {
    abi,
    contractTransaction,
  };
}
