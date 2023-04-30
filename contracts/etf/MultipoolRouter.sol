//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Multipool.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract MultipoolRouter {
    constructor () {}
    /**
        Expected, that swap path and pairs parameters contain array, 
        each index of it should contain same length array as pairs/swapPaths respectively.
     */
    function mintWithSwapPath(
        address _etf,
        address[][] calldata _swapPaths, // array of tokens array to swap
        address[][] calldata _pairs, // Uniswap pairs to be used inside swaps
        uint[][] calldata _amounts, // amounts of tokens that should be used in swap
        uint _minShare,
        address _to
    ) external {
        for (uint256 i; i < _swapPaths.length; i++) {
            IERC20(_swapPaths[i][0]).transferFrom(
                msg.sender,
                _pairs[i][0],
                _amounts[i][0]
            );
            uint256 length = _pairs[i].length;
            for (uint256 y; y < length; y++) {
                // decomposition to avoid stack to deep
                (uint256 amount0Out, uint256 amount1Out) = sortAmounts(
                    _swapPaths[i][y],
                    _swapPaths[i][y + 1],
                    _amounts[i][y + 1]
                );
                address to = y == length - 1 ? _etf : _pairs[i][y+1];
                IUniswapV2Pair(_pairs[i][y]).swap(
                    amount0Out,
                    amount1Out,
                    to,
                    new bytes(0)
                );
            }
            require(
                Multipool(_etf).mint(_swapPaths[i][_swapPaths.length], _to) > _minShare, 
                "Receiver share is too low"
            );
        }
    }

    function sortAmounts(
        address tokenA,
        address tokenB,
        uint256 amountOut
    ) internal pure returns (uint256, uint256) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        require(tokenA != address(0), "UniswapV2Library: ZERO_ADDRESS");
        require(tokenB != address(0), "UniswapV2Library: ZERO_ADDRESS");

        return
            tokenA < tokenB ? (uint256(0), amountOut) : (amountOut, uint256(0));
    }

    function mintWithAsset(
        address _etf,
        address _token,
        uint _amount,
        uint _minShare,
        address _to
    ) external {
        IERC20(_token).transferFrom(msg.sender, _etf, _amount);
        require(
            Multipool(_etf).mint(_token, _to) > _minShare, 
            "Receive share is too low"
        );
    }

    function swap(
        address _etf,
        address _tokenIn,
        address _tokenOut,
        uint _amountIn,
        uint _minAmountOut,
        address _to
    ) external {
        IERC20(_tokenIn).transferFrom(msg.sender, _etf, _amountIn);
        require(
            Multipool(_etf).swap(_tokenIn, _tokenOut, _to) > _minAmountOut, 
            "Receive amount is too low"
        );
    }

    function burn(
        address _etf,
        uint _share,
        address _token,
        uint _minQuantity,
        address _to
    ) external {
        IERC20(_etf).transferFrom(msg.sender, address(this), _share);
        require(Multipool(_etf).burn(_share, _token, _to) > _minQuantity, "Received quantity is too low");
    }
}
