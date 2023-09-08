const { deployments, ethers, getNamedAccounts } = require("hardhat");
const { initialRate } = require("../../helper-hardhat-config");

const { assert, expect } = require("chai");
const { BN } = require("bn.js");

describe("ListenToEarn", async function () {
  let listenToEarn, deployer, myToken, user1, user2;

  const address0 = 0x5fbdb2315678afecb367f032d93f642f64180aa3;

  beforeEach(async function () {
    deployer = (await getNamedAccounts()).deployer;
    const accounts = await ethers.getSigners();
    user1 = accounts[0];
    user2 = accounts[1];
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
    it("User cannot be registered on initial deployment", async () => {
      const isUser = await listenToEarn.isUser(user1);
      assert.isFalse(isUser, "User should be registered");
    });

    it("successfully registers a user", async () => {
      await listenToEarn.connect(user1).registerUser();
      const isRegistered = await listenToEarn.isUser(user1);
      assert.isTrue(isRegistered, "User should be registered");
    });

    it("requires a registration fee when userCounts greater than 1000", async () => {
      //get the user counts
      const userCount = await listenToEarn.registeredUser();

      //setting the reg fee
      const regFee = new BN(100);
      const userBalance = new BN(50);

      //sending the regfee to the user
      myToken.transfer(user1, regFee.toString());

      //registration when the user counts is greater than 1000
      if (userCount > new BN(1000)) {
        // assert.isTrue(
        //   userBalance.gte(regFee),
        //   "userBalance greater than reg fee"
        // );

        //connects the user
        await listenToEarn.connect(user1).registerUser();

        const user1Balance = await myToken.balanceOf(user1);
        assert.isTrue(
          user1Balance.eq(),
          "User's token balance is incorrect after registration"
        );
      }
    });

    it("adds user to the array of users", async () => {
      await listenToEarn.connect(user2).registerUser();
      const user = await listenToEarn.users(0);
      assert.equal(user, user2.address);
    });

    it("increases the count of the registeredUser", async () => {
      //getting the initial count of the registeredUser
      const initialCount = await listenToEarn.registeredUser();

      //connect to the listenToEarn contract and register a user
      await listenToEarn.connect(user1).registerUser();

      //getting the initial count of the registeredUser
      const newCount = await listenToEarn.registeredUser();

      //using the BN lib
      const initialCountB = new BN(initialCount.toString());
      const newCountB = new BN(newCount.toString());

      //checking the initial count has increased after the registration
      //addn is a bn.js function used to add a number
      const resInitial = initialCountB.addn(1);
      expect(newCountB).to.equal(resInitial);
    });
  });
});
