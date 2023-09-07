const { deployments, ethers, getNamedAccounts } = require("hardhat");
const { initialRate } = require("../../helper-hardhat-config");

const { assert } = require("chai");

describe("ListenToEarn", async function () {
  let listenToEarn, deployer, myToken;

  const address0 = 0x5fbdb2315678afecb367f032d93f642f64180aa3;

  beforeEach(async function () {
    deployer = (await getNamedAccounts()).deployer;
    //the fixture object from deployments allows us to use the tags from the deployment functions
    await deployments.fixture(["all"]);
    //gives us the most recent deployment of the contract and we connect our deployer to the ListenToEarn contract
    //so all func from the listenToEarn contract will be from the deployer account
    listenToEarn = await ethers.getContract("ListenToEarn", deployer);
    myToken = await ethers.getContract("MyToken", deployer);
  });

  describe("constructor", async function () {
    it("sets the token's contract address correctly", async function () {
      const listenToEarnToken = await listenToEarn.token();
      assert.equal(
        listenToEarnToken,
        address0,
        "Token address is set correctly"
      );
    });

    it("should set the initial rate correctly", async () => {
      //check that the current rate is correct for this test case
      const listenToEarnRate = await listenToEarn.initialRate();
      assert.equal(listenToEarnRate, initialRate);
    });
  });

  describe("registerUser", async () => {
    const [owner] = await ethers.getSigners();
    it("successfully registers a user", async () => {
      const isUser = await listenToEarn.isUser(deployer);
      assert.isFalse(isUser, "User should be registered");
    });

    it("successfully registers a user", async () => {
      await listenToEarn
        .connect(ethers.provider.getSigner(owner))
        .registerUser();

      const isRegistered = await listenToEarn.isUser(owner);
      //   const isUser = await listenToEarn.isUser(registeredUser);
      assert.isTrue(isRegistered, "User should be registered");
    });
  });
});
