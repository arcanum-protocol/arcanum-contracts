import { BigNumber, BigNumberish, FixedNumber } from "ethers";

export function toDecimal(
  number: BigNumberish,
  decimals: Number = 18
): BigNumber {
  return BigNumber.from(number).mul(BigNumber.from(10).pow(BigNumber.from(decimals)));
}
