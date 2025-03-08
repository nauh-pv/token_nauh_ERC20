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
    await rewardManager.grantRole(
      await rewardManager.VAULT_ROLE(),
      tokenVault.target
    );
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

  it("Should prevent withdrawal if user has insufficient balance", async function () {
    await expect(
      tokenVault.withdraw(ethers.parseEther("50"))
    ).to.be.revertedWith("Insufficient balance");
  });

  it("Should prevent staking more than deposited balance", async function () {
    await nauhToken.approve(tokenVault.target, ethers.parseEther("100"));
    await tokenVault.deposit(ethers.parseEther("100"));

    await expect(tokenVault.stake(ethers.parseEther("200"))).to.be.revertedWith(
      "Insufficient balance"
    );
  });

  it("Should allow unstaking after lock period", async function () {
    await nauhToken.approve(tokenVault.target, ethers.parseEther("100"));
    await tokenVault.deposit(ethers.parseEther("100"));
    await tokenVault.stake(ethers.parseEther("50"));

    await ethers.provider.send("evm_increaseTime", [7 * 24 * 3600]);
    await ethers.provider.send("evm_mine");

    await expect(tokenVault.unstake(ethers.parseEther("50"))).to.not.be
      .reverted;
  });

  it("Should allow user to claim rewards", async function () {
    await rewardManager.grantRole(
      await rewardManager.VAULT_ROLE(),
      tokenVault.target
    );

    await nauhToken.transfer(rewardManager.target, ethers.parseEther("10000"));

    await nauhToken.approve(tokenVault.target, ethers.parseEther("100"));
    await tokenVault.deposit(ethers.parseEther("100"));
    await tokenVault.stake(ethers.parseEther("50"));

    await rewardManager.updateRewardRate(ethers.parseEther("10"));
    await ethers.provider.send("evm_mine");

    await ethers.provider.send("evm_increaseTime", [2 * 86400]);
    await ethers.provider.send("evm_mine");

    await rewardManager.updateRewardRate(ethers.parseEther("10"));
    await ethers.provider.send("evm_mine");

    let pendingReward = await tokenVault.viewRewards();
    expect(pendingReward).to.be.gt(
      0,
      "❌ No rewards available before claiming!"
    );

    const rewardManagerBalance = await nauhToken.balanceOf(
      rewardManager.target
    );
    expect(rewardManagerBalance).to.be.gt(0, "❌ RewardManager has no tokens!");

    const userRewardsBefore = await rewardManager.viewReward(owner.address);
    expect(userRewardsBefore).to.be.gt(0, "❌ User has no rewards to claim!");

    try {
      await expect(tokenVault.claimRewards()).to.not.be.reverted;
    } catch (error) {
      console.error("🚨 Claim rewards failed with error:", error);
    }

    const userRewardsAfter = await rewardManager.viewReward(owner.address);
    expect(userRewardsAfter).to.equal(
      0,
      "❌ Rewards not reset after claiming!"
    );
  });

  it("Should revert if user has no rewards", async function () {
    await expect(tokenVault.claimRewards()).to.be.revertedWith(
      "No rewards to claim!"
    );
  });

  it("Should allow multiple deposits and stakes", async function () {
    await nauhToken.approve(tokenVault.target, ethers.parseEther("200"));
    await tokenVault.deposit(ethers.parseEther("100"));
    await tokenVault.deposit(ethers.parseEther("100"));
    expect(await tokenVault.balances(owner.address)).to.equal(
      ethers.parseEther("200")
    );

    await tokenVault.stake(ethers.parseEther("50"));
    await tokenVault.stake(ethers.parseEther("50"));
    expect(await tokenVault.stakedBalances(owner.address)).to.equal(
      ethers.parseEther("100")
    );
  });
});
