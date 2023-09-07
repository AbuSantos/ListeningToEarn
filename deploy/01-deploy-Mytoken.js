const { network } = require("hardhat");
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  //   const chainId = network.config.chainId;

  const myToken = await deploy("MyToken", {
    from: deployer,
    args: [],
    log: true,
  });
  log(myToken.address);
};

module.exports.tags = ["all", "myToken"];
