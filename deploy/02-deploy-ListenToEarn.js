const { initialRate, tokenAddress } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

const args = [initialRate, tokenAddress];

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const listenToEarn = await deploy("ListenToEarn", {
    from: deployer,
    args: [tokenAddress, initialRate],
    log: true,
    
  });
//   await verify(listenToEarn.address, args);
};

module.exports.tags = ["all", "listen"];
