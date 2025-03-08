import { expect } from "chai";
import { ethers } from "hardhat";
import { NauhToken, RewardManager } from "../typechain-types";

describe("RewardManager", function () {
  let nauhToken: NauhToken;
  let rewardManager: RewardManager;
  let owner: any, user1: any;

  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    const NauhToken = await ethers.getContractFactory("NauhToken");
    nauhToken = await NauhToken.deploy();

    const RewardManager = await ethers.getContractFactory("RewardManager");
    rewardManager = await RewardManager.deploy(
      nauhToken.target,
      ethers.parseEther("10"),
      86400
    );
  });

  it("Should set initial reward token correctly", async function () {
    expect(await rewardManager.rewardToken()).to.equal(nauhToken.target);
  });

  it("Should allow admin to set token vault", async function () {
    await rewardManager.setTokenVault(user1.address);
    expect(await rewardManager.tokenVault()).to.equal(user1.address);
  });

  it("Should not allow non-admin to set token vault", async function () {
    await expect(
      rewardManager.connect(user1).setTokenVault(user1.address)
    ).to.be.revertedWithCustomError(
      rewardManager,
      "AccessControlUnauthorizedAccount"
    );
  });

  it("Should update reward rate", async function () {
    await rewardManager.updateRewardRate(ethers.parseEther("20"));
    expect((await rewardManager.rewardCheckpoints(1)).rewardRate).to.equal(
      ethers.parseEther("20")
    );
  });

  it("Should allow vault to add stake", async function () {
    await rewardManager.grantRole(
      await rewardManager.VAULT_ROLE(),
      owner.address
    );
    await rewardManager.addStakePosition(
      user1.address,
      ethers.parseEther("50")
    );

    expect(await rewardManager.calculateUserBalance(user1.address)).to.equal(
      ethers.parseEther("50")
    );
  });
});
