// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IMultipool {
    function mint(address assetAddress, uint share, address to) external returns (uint amountIn, uint refund);
    function burn(address assetAddress, uint share, address to) external returns (uint amountOut, uint refund);
    function swap(address assetInAddress, address assetOutAddress, uint share, address to)
        external
        returns (uint amountIn, uint amountOut, uint refundIn, uint refundOut);
}
