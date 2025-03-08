import { expect } from "chai";
import { ethers } from "hardhat";
import { NauhToken } from "../typechain-types";

describe("NauhToken", function () {
  let nauhToken: NauhToken;
  let owner: any, user1: any, user2: any;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    const NauhToken = await ethers.getContractFactory("NauhToken");
    nauhToken = await NauhToken.deploy();
  });

  it("Should deploy with initial supply", async function () {
    expect(await nauhToken.totalSupply()).to.equal(
      ethers.parseEther("1000000")
    );
  });

  it("Should allow admin to set token vault", async function () {
    await nauhToken.setTokenVault(user1.address);
    expect(await nauhToken.tokenVault()).to.equal(user1.address);
  });

  it("Should grant VAULT_ROLE to token vault", async function () {
    await nauhToken.setTokenVault(user1.address);
    expect(await nauhToken.hasRole(await nauhToken.VAULT_ROLE(), user1.address))
      .to.be.true;
  });

  it("Should not allow non-admin to set token vault", async function () {
    await expect(
      nauhToken.connect(user1).setTokenVault(user2.address)
    ).to.be.revertedWithCustomError(
      nauhToken,
      "AccessControlUnauthorizedAccount"
    );
  });
});
