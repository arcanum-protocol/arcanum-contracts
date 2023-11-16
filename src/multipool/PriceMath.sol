// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { IUniswapV3Pool } from "uniswapv3/interfaces/IUniswapV3Pool.sol";
import { TickMath } from "uniswapv3/libraries/TickMath.sol";
import { FixedPoint96 } from "uniswapv3/libraries/FixedPoint96.sol";

enum FeedType {
    Undefined,
    FixedValue,
    UniV3
   // YieldDerivative
}

struct UniV3Feed {
    address oracle;
    uint twapInterval;
}

// any Price should have a 2^96 decimals
// some unsafe shit here, generally feed type is a simple number and bytes that 
//depend on feed type
struct FeedInfo {
    FeedType kind;
    bytes data;
}


using {MpPriceMath.getPrice} for FeedInfo global;

library MpPriceMath {

    function getPrice(FeedInfo memory feed) internal view returns (uint price) {
        if (feed.kind == FeedType.FixedValue) {
            price = abi.decode(feed.data, (uint));
        } else if (feed.kind == FeedType.UniV3) {
            UniV3Feed memory data = abi.decode(feed.data, (UniV3Feed));
            price = getTwapX96(data.oracle, data.twapInterval);
        } else {
            require(false, "No price origin set");
        }
    }

    function getTwapX96(address uniswapV3Pool, uint256 twapInterval) internal view returns (uint256 priceX96) {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (priceX96, , , , , , ) = IUniswapV3Pool(uniswapV3Pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = uint32(twapInterval); // from (before)
            secondsAgos[1] = 0; // to (now)

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(uniswapV3Pool).observe(secondsAgos);

            // tick(imprecise as it's an integer) to price
            priceX96 = TickMath.getSqrtRatioAtTick(
                int24(int256(tickCumulatives[1] - tickCumulatives[0]) / int256(twapInterval))
            );
            priceX96 = priceX96 * priceX96 / FixedPoint96.Q96;
        }
    }

}
