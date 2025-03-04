import { NauhToken, RewardManager, TokenVault } from "../typechain-types";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("TokenVault", function () {
  let nauhToken: NauhToken;
  let tokenVault: TokenVault;
  let rewardManager: RewardManager;
  let owner: any, user1: any, user2: any;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const NauhToken = await ethers.getContractFactory("NauhToken");
    nauhToken = await NauhToken.deploy();
    await nauhToken.waitForDeployment();

    const RewardManager = await ethers.getContractFactory("RewardManager");
    rewardManager = await RewardManager.deploy(nauhToken.target, 100, 86400);

    const TokenVault = await ethers.getContractFactory("TokenVault");
    tokenVault = await TokenVault.deploy(
      nauhToken.target,
      rewardManager.target
    );

    await rewardManager.setTokenVault(tokenVault.target);
  });

  it("Should allow user to deposit tokens", async function () {
    await nauhToken.approve(tokenVault.target, ethers.parseEther("100"));
    await tokenVault.deposit(ethers.parseEther("100"));

    const balance = await tokenVault.balances(owner.address);
    expect(balance).to.equal(ethers.parseEther("100"));
  });

  it("Should allow user to stake tokens", async function () {
    await nauhToken.approve(tokenVault.target, ethers.parseEther("100"));
    await tokenVault.deposit(ethers.parseEther("100"));
    await tokenVault.stake(ethers.parseEther("50"));

    const stakedBalance = await tokenVault.stakedBalances(owner.address);
    expect(stakedBalance).to.equal(ethers.parseEther("50"));
  });

  it("Should prevent unstaking before lock period", async function () {
    await nauhToken.approve(tokenVault.target, ethers.parseEther("100"));
    await tokenVault.deposit(ethers.parseEther("100"));
    await tokenVault.stake(ethers.parseEther("50"));

    await expect(
      tokenVault.unstake(ethers.parseEther("50"))
    ).to.be.revertedWith("Stake is still locked!");
  });
});
