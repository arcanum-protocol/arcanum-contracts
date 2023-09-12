// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IMultipoolRouter {
    function mintWithSharesOut(address poolAddress, address assetAddress, uint sharesOut, uint amountInMax, address to)
        external
        returns (uint amount, uint refund);

    function burnWithSharesIn(address poolAddress, address assetAddress, uint sharesIn, uint amountOutMin, address to)
        external
        returns (uint amount, uint refund);

    function mintWithAmountIn(address poolAddress, address assetAddress, uint amountIn, uint sharesOutMin, address to)
        external
        returns (uint shares, uint refund);

    function burnWithAmountOut(address poolAddress, address assetAddress, uint amountOut, uint sharesInMax, address to)
        external
        returns (uint shares, uint refund);

    function swapWithAmountIn(
        address poolAddress,
        address assetInAddress,
        address assetOutAddress,
        uint amountIn,
        uint amountOutMin,
        address to
    ) external returns (uint amountOut, uint refundIn, uint refundOut);

    function swapWithAmountOut(
        address poolAddress,
        address assetInAddress,
        address assetOutAddress,
        uint amountOut,
        uint amountInMax,
        address to
    ) external returns (uint amountIn, uint refundIn, uint refundOut);

    function estimateMintSharesOut(address poolAddress, address assetAddress, uint amountIn)
        external
        view
        returns (uint sharesOut, uint assetPrice, uint sharePrice, uint cashbackIn);

    function estimateMintAmountIn(address poolAddress, address assetAddress, uint sharesOut)
        external
        view
        returns (uint amountIn, uint assetPrice, uint sharePrice, uint cashbackIn);

    function estimateBurnAmountOut(address poolAddress, address assetAddress, uint sharesIn)
        external
        view
        returns (uint amountOut, uint assetPrice, uint sharePrice, uint cashbackOut);

    function estimateBurnSharesIn(address poolAddress, address assetAddress, uint amountOut)
        external
        view
        returns (uint sharesIn, uint assetPrice, uint sharePrice, uint cashbackOut);
    function estimateSwapAmountOut(address poolAddress, address assetInAddress, address assetOutAddress, uint amountIn)
        external
        view
        returns (uint shares, uint amountOut, uint assetInPrice, uint assetOutPrice, uint cashbackIn, uint cashbackOut);
    function estimateSwapAmountIn(address poolAddress, address assetInAddress, address assetOutAddress, uint amountOut)
        external
        view
        returns (uint shares, uint amountIn, uint assetInPrice, uint assetOutPrice, uint cashbackIn, uint cashbackOut);
}
