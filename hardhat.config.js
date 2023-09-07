require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require("hardhat-deploy");
require("solidity-coverage");
const etherScanApi = "VIF6JTDMN3IC3W69WXZ7BV4SE53PK4IQ7R";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  network: {
    defaultNetwork: "hardhat",
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  etherscan: {
    apiKey: etherScanApi,
  },
};
