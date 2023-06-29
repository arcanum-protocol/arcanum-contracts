import { expect } from "chai";
import { ethers } from "hardhat";

describe("Multipool library", function () {
  let TEST1: any;
  let TEST2: any;
  let test1: any;
  let test2: any;

  before(async () => {
    TEST1 = await ethers.getContractFactory("TestMultipoolMath");
    TEST2 = await ethers.getContractFactory("TestMultipoolMathCorner");
  });

  beforeEach(async function () {
    test1 = await TEST1.deploy();
    test2 = await TEST2.deploy();
  });

  it("Mint with zero balance", async function () {
    await test1.mintWithZeroBalance();
  });
  it("Mint with zero balance reversed", async function () {
    await test1.mintWithZeroBalanceReversed();
  });
  it("Mint with deviation fee", async function () {
    await test1.mintWithDeviationFee();
  });
  it("Mint with deviation fee reversed", async function () {
    await test1.mintWithDeviationFeeReversed();
  });
  it("Burn with deviation fee", async function () {
    await test1.burnWithDeviationFee();
  });
  it("Burn with deviation fee reversed", async function () {
    await test1.burnWithDeviationFeeReversed();
  });
  it("Mint with no deviation fee", async function () {
    await test1.mintWithNoDeviationFee();
  });
  it("Mint with no deviation fee reversed", async function () {
    await test1.mintWithNoDeviationFeeReversed();
  });
  it("Burn with no deviation fee", async function () {
    await test1.burnWithNoDeviationFee();
  });
  it("Burn with no deviation fee reversed", async function () {
    await test1.burnWithNoDeviationFeeReversed();
  });
  it("Mint with no deviation fee and cashback", async function () {
    await test1.mintWithNoDeviationFeeAndCashback();
  });
  it("Mint with no deviation fee and cashback reversed", async function () {
    await test1.mintWithNoDeviationFeeAndCashbackReversed();
  });
  it("Burn with no deviation fee and cashback ", async function () {
    await test1.burnWithNoDeviationFeeAndCashback();
  });
  it("Burn with no deviation fee and cashback reversed", async function () {
    await test1.burnWithNoDeviationFeeAndCashbackReversed();
  });

  it("Mint with deviation bigger than limit ", async function () {
    await test2.mintWithDeviationBiggerThanLimit();
  });
  it("Mint with deviation bigger than limit reversed", async function () {
    await test2.mintWithDeviationBiggerThanLimitReversed();
  });
  it("Burn with deviation bigger than limit ", async function () {
    await test2.burnWithDeviationBiggerThanLimit();
  });
  it("Burn with deviation bigger than limit reversed", async function () {
    await test2.burnWithDeviationBiggerThanLimitReversed();
  });

  it("Mint and make deviation bigger than limit", async function () {
    await test2.mintTooMuch();
  });
  it("Mint and make deviation bigger than limit reversed", async function () {
    await test2.mintTooMuchReversed();
  });
  it("Burn and make deviation bigger than limit", async function () {
    await expect(test2.burnTooMuch()).to.be.revertedWith(
      "deviation overflows limit",
    );
  });
  it("Burn and make deviation bigger than limit reversed", async function () {
    await expect(test2.burnTooMuchReversed()).to.be.revertedWith(
      "no curve solutions found",
    );
  });
  it("Mint and make deviation bigger than limit with deviation already bigger", async function () {
    await expect(test2.mintTooMuchBeingBiggerThanLimit()).to.be.revertedWith(
      "deviation overflows limit",
    );
  });
  it("Mint and make deviation bigger than limit with deviation already bigger reversed", async function () {
    await expect(test2.mintTooMuchBeingBiggerThanLimitReversed()).to.be
      .revertedWith("deviation overflows limit");
  });
  it("Burn and make deviation bigger than limit with deviation already bigger", async function () {
    await expect(test2.burnTooMuchBeingBiggerThanLimit()).to.be.revertedWith(
      "deviation overflows limit",
    );
  });
  it("Burn and make deviation bigger than limit with deviation already bigger reversed", async function () {
    await expect(test2.burnTooMuchBeingBiggerThanLimitReversed()).to.be
      .revertedWith("deviation overflows limit");
  });
  it("Burn and make deviation bigger than limit with deviation already bigger more then quantity", async function () {
    await expect(test2.burnTooMuchBeingBiggerThanLimitMoreThenQuantity()).to.be
      .revertedWith("can't burn more assets than exist");
  });
  it("Burn and make deviation bigger than limit with deviation already bigger more then quantity reversed", async function () {
    await expect(
      test2.burnTooMuchBeingBiggerThanLimitMoreThenQuantityReversed(),
    ).to.be.revertedWith("can't burn more assets than exist");
  });
});
