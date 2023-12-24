// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "uniswapv3/interfaces/IUniswapV3Pool.sol";
import {FixedPoint96} from "../lib/FixedPoint96.sol";
import {IMultipoolErrors} from "../interfaces/multipool/IMultipoolErrors.sol";
import {IPriceAdapter} from "../interfaces/IPriceAdapter.sol";
import {IMultipoolErrors} from "../interfaces/multipool/IMultipoolErrors.sol";

enum FeedType {
    // Unset value
    Undefined,
    // Constant value used for tests and to represend quote price feed to quote
    FixedValue,
    // Uniswap v3 price extraction
    UniV3,
    // Call for other contract to provide price
    Adapter
}

// Data of uniswap v3 feed
struct UniV3Feed {
    // Pool address
    address oracle;
    // Shows wether to flip the price
    bool reversed;
    // Interval of aggregation in seconds
    uint twapInterval;
}

// Any price should have a 2^96 decimals
// Some unsafe shit here, generally feed type is a simple number and bytes that
// depend on feed type
struct FeedInfo {
    FeedType kind;
    bytes data;
}

using {PriceMath.getPrice} for FeedInfo global;

/// @title Price calculation and provision library
library PriceMath {
    /// @notice Extracts current price from origin
    /// @dev Processed the provided `prceFeed` to get it's current price value.
    /// @param priceFeed struct with data of supplied price feed
    /// @return price value is represented as a Q96 value
    function getPrice(FeedInfo memory priceFeed) internal view returns (uint price) {
        if (priceFeed.kind == FeedType.FixedValue) {
            price = abi.decode(priceFeed.data, (uint));
        } else if (priceFeed.kind == FeedType.UniV3) {
            UniV3Feed memory data = abi.decode(priceFeed.data, (UniV3Feed));
            price = getTwapX96(data.oracle, data.reversed, data.twapInterval);
        } else if (priceFeed.kind == FeedType.Adapter) {
            (address adapterContract, uint feedId) = abi.decode(priceFeed.data, (address, uint));
            price = IPriceAdapter(adapterContract).getPrice(feedId);
        } else {
            revert IMultipoolErrors.NoPriceOriginSet();
        }
    }

    /**
     *
     * Reversed parameter serves to determine wether price needs to be flipped. This happens because
     * uniswap
     * pools have single pool per asset pair and sort assets addresses.
     */
    /// @notice Extracts current price from origin
    /// @dev This function is used to extract TWAP price from uniswap v3 pool
    /// @param twapInterval price aggregation interval in seconds
    /// @param uniswapV3Pool address of target uniswap v3 pool
    /// @param reversed parameter serves to determine wether price needs to be flipped.
    //  This happens because uniswap pools have single pool per asset pair and sort assets addresses
    /// @return priceX96 value is represented as a Q96 value
    function getTwapX96(
        address uniswapV3Pool,
        bool reversed,
        uint256 twapInterval
    )
        internal
        view
        returns (uint256 priceX96)
    {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (priceX96,,,,,,) = IUniswapV3Pool(uniswapV3Pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = uint32(twapInterval); // from (before)
            secondsAgos[1] = 0; // to (now)

            (bool success, bytes memory data) = uniswapV3Pool.staticcall(
                abi.encodeWithSelector(IUniswapV3Pool(uniswapV3Pool).observe.selector, secondsAgos)
            );
            if (success) {
                (int56[] memory tickCumulatives,) = abi.decode(data, (int56[], uint160[]));

                // tick(imprecise as it's an integer) to price
                priceX96 = TickMath.getSqrtRatioAtTick(
                    int24(int256(tickCumulatives[1] - tickCumulatives[0]) / int256(twapInterval))
                );
            } else {
                // fallbakc to slot0 if error is OLD
                if (keccak256(data) == keccak256(abi.encodeWithSignature("Error(string)", "OLD"))) {
                    (priceX96,,,,,,) = IUniswapV3Pool(uniswapV3Pool).slot0();
                } else {
                    revert IMultipoolErrors.UniV3PriceFetchingReverted();
                }
            }
        }
        if (reversed) {
            priceX96 = (
                ((FixedPoint96.Q96 << FixedPoint96.RESOLUTION) / priceX96)
                    << FixedPoint96.RESOLUTION
            ) / priceX96;
        } else {
            priceX96 = (priceX96 * priceX96) >> FixedPoint96.RESOLUTION;
        }
    }
}

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point
/// Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base
    /// 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base
    /// 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to
    /// getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to
    /// getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the
    /// two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= uint256(int256(MAX_TICK)), "T");

        uint256 ratio = absTick & 0x1 != 0
            ? 0xfffcb933bd6fad37aa2d162d1a594001
            : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick
        // input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always
        // consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }
}
