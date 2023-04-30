// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Multipool is ERC20, Ownable {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        feeReceiver = msg.sender;
    }

    event AssetPercentsChange(address indexed asset, uint percent);
    event AssetQuantityChange(address indexed asset, uint quantity);
    event AssetPriceChange(address indexed asset, uint price);

    /** ---------------- Variables ------------------ */

    struct Asset {
        uint quantity;
        uint price;
        uint collectedFees;
        uint collectedCashbacks;
        uint percent;
    }

    mapping(address => Asset) public assets;
    uint public totalCurrentUsdAmount;
    uint public totalAssetPercents;

    uint public curveDelay;
    uint public restrictPercent;

    uint public baseMintFee = 1e16;
    uint public baseBurnFee = 1e16;
    uint public baseTradeFee = 5e15; // 0.005 + 0.005 = 0.01
    uint public denominator = 1e18;

    mapping(address => uint) public transferFees;
    address public feeReceiver;

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount); // Call parent hook
        uint transferFee = transferFees[to];
        if (transferFee != 0) {
            _transfer(to, feeReceiver, (amount * transferFee) / denominator);
        }
    }

    /** ---------------- View ------------------ */

    function pegCurve(uint depegRate) public view returns (uint) {
        return
            depegRate >= restrictPercent
                ? 100 * 1e18
                : (curveDelay * depegRate * denominator) /
                    (restrictPercent * denominator - depegRate) /
                    restrictPercent;
    }

    function abs(uint x, uint y) internal pure returns (uint) {
        return x > y ? x - y : y - x;
    }

    function pos(int x) internal pure returns (int) {
        return x > 0 ? x : -x;
    }

    function calculateCompensationFee(
        Asset memory asset,
        uint newQuantity,
        uint _totalCurrentUsdAmount
    )
        internal
        view
        returns (uint fee, uint cashback, uint newTotalCurrentUsdAmount)
    {
        if (totalCurrentUsdAmount == 0) {
            newTotalCurrentUsdAmount = _totalCurrentUsdAmount;
            newTotalCurrentUsdAmount -=
                (asset.quantity * asset.price) /
                denominator;
            newTotalCurrentUsdAmount +=
                (newQuantity * asset.price) /
                denominator;
            return (0, 0, newTotalCurrentUsdAmount);
        }

        uint oldDepegRate = abs(
            (asset.quantity * asset.price) / _totalCurrentUsdAmount,
            (asset.percent * denominator) / totalAssetPercents
        );

        newTotalCurrentUsdAmount = _totalCurrentUsdAmount;
        newTotalCurrentUsdAmount -=
            (asset.quantity * asset.price) /
            denominator;
        newTotalCurrentUsdAmount += (newQuantity * asset.price) / denominator;

        uint newDepegRate = abs(
            (newQuantity * asset.price) / _totalCurrentUsdAmount,
            (asset.percent * denominator) / totalAssetPercents
        );

        return
            newDepegRate > oldDepegRate
                ? (pegCurve(newDepegRate), uint(0), newTotalCurrentUsdAmount)
                : (
                    uint(0),
                    (asset.collectedCashbacks * (oldDepegRate - newDepegRate)) /
                        oldDepegRate,
                    newTotalCurrentUsdAmount
                );
    }

    function applyAssetChanges(
        Asset memory asset,
        int _balanceDelta,
        uint fee,
        uint cashback,
        uint _baseFee
    ) internal view returns (uint usdAmount, uint assetAmount) {
        if (fee + _baseFee > 100 * 1e18) {
            fee = 100 * 1e18 - _baseFee;
        }
        uint collectedCashback = (fee * uint(pos(_balanceDelta))) /
            denominator /
            100;
        uint collectedFees = (_baseFee * uint(pos(_balanceDelta))) /
            denominator /
            100;

        asset.quantity = uint(
            int(asset.quantity) +
                _balanceDelta -
                int(collectedCashback) -
                int(collectedFees)
        );
        asset.collectedCashbacks += collectedCashback;
        asset.collectedFees += collectedFees;

        assetAmount = uint(pos(_balanceDelta));
        assetAmount -= collectedCashback;
        assetAmount += cashback;
        assetAmount -= collectedFees; 
        usdAmount = (assetAmount * asset.price) / denominator;
    }

    function processAssetDeviaion(
        Asset memory asset,
        int _balanceDelta,
        uint _baseFee,
        uint _totalCurrentUsdAmount
    )
        internal
        view
        returns (uint usdAmount, uint assetAmount, uint returnTotalCurrentUsdAmount)
    {
        uint newBalance = uint(int(asset.quantity) + _balanceDelta);
        (
            uint fee,
            uint cashback,
            uint newTotalCurrentUsdAmount
        ) = calculateCompensationFee(asset, newBalance, _totalCurrentUsdAmount);
        (uint _usdAmount, uint _assetAmount) = applyAssetChanges(
            asset,
            _balanceDelta,
            fee,
            cashback,
            _baseFee
        );
        usdAmount = _usdAmount;
        assetAmount = _assetAmount;
        returnTotalCurrentUsdAmount = newTotalCurrentUsdAmount;
    }

    function _mintLp(
        Asset memory asset,
        uint availableBalance,
        uint _baseFee,
        uint _totalCurrentUsdAmount
    ) private view returns (uint share, uint newTotalCurrentUsdAmount) {
        require(asset.percent != 0, "cant' take this asset");
        (
            uint usdValue,
            ,
            uint _newTotalCurrentUsdAmount
        ) = processAssetDeviaion(
                asset,
                int(availableBalance),
                _baseFee,
                _totalCurrentUsdAmount
            );
        newTotalCurrentUsdAmount = _newTotalCurrentUsdAmount;
        share = totalSupply() == 0
            ? usdValue
            : (usdValue * _totalCurrentUsdAmount) / totalSupply();
    }

    function _burnLp(
        Asset memory asset,
        uint _share,
        uint _baseFee,
        uint _totalCurrentUsdAmount
    ) private view returns (uint quantity, uint newTotalCurrentUsdAmount) {
        uint quantityToRemove = (_share * totalSupply()) /
            totalCurrentUsdAmount;
        (
            ,
            uint toRemove,
            uint _newTotalCurrentUsdAmount
        ) = processAssetDeviaion(
                asset,
                -int(quantityToRemove),
                _baseFee,
                _totalCurrentUsdAmount
            );
        newTotalCurrentUsdAmount = _newTotalCurrentUsdAmount;
        quantity = toRemove;
    }

    /** ---------------- DRY Methods ------------------ */

    function dryMint(
        uint _amount,
        address _asset
    ) public view returns (uint share) {
        Asset memory asset = assets[_asset];
        (uint _share, ) = _mintLp(
            asset,
            _amount,
            baseMintFee,
            totalCurrentUsdAmount
        );
        share = _share;
    }

    function dryBurn(
        uint _share,
        address _asset
    ) public view returns (uint quantity) {
        Asset memory asset = assets[_asset];
        (uint _quantity, ) = _burnLp(
            asset,
            _share,
            baseBurnFee,
            totalCurrentUsdAmount
        );
        quantity = _quantity;
    }

    function drySwap(
        uint _amountIn,
        address _assetIn,
        address _assetOut
    ) public view returns (uint quantity) {
        Asset memory assetIn = assets[_assetIn];
        Asset memory assetOut = assets[_assetOut];
        (uint _share, uint _totalCurrentUsdAmount) = _mintLp(
            assetIn,
            _amountIn,
            baseTradeFee,
            totalCurrentUsdAmount
        );
        (uint _quantity, ) = _burnLp(
            assetOut,
            _share,
            baseTradeFee,
            _totalCurrentUsdAmount
        );
        quantity = _quantity;
    }

    /** ---------------- Methods ------------------ */

    function mint(address _asset, address _to) public returns (uint share) {
        Asset memory asset = assets[_asset];
        uint availableBalance = IERC20(_asset).balanceOf(address(this)) -
            asset.quantity -
            asset.collectedFees -
            asset.collectedCashbacks;
        (uint _share, uint _totalCurrentUsdAmount) = _mintLp(
            asset,
            availableBalance,
            baseMintFee,
            totalCurrentUsdAmount
        );
        share = _share;
        totalCurrentUsdAmount = _totalCurrentUsdAmount;
        _mint(_to, share);
        emit AssetQuantityChange(_asset, asset.quantity);
        assets[_asset] = asset;
    }

    function burn(
        uint _share,
        address _asset,
        address _to
    ) public returns (uint quantity) {
        Asset memory asset = assets[_asset];
        (uint _quantity, uint _totalCurrentUsdAmount) = _burnLp(
            asset,
            _share,
            baseBurnFee,
            totalCurrentUsdAmount
        );
        quantity = _quantity;
        totalCurrentUsdAmount = _totalCurrentUsdAmount;
        emit AssetQuantityChange(_asset, asset.quantity);
        _burn(msg.sender, _share);
        IERC20(_asset).transfer(_to, quantity);
        assets[_asset] = asset;
    }

    function swap(
        address _assetIn,
        address _assetOut,
        address _to
    ) public returns (uint quantity) {
        Asset memory assetIn = assets[_assetIn];
        Asset memory assetOut = assets[_assetOut];
        uint availableBalance = IERC20(_assetIn).balanceOf(address(this)) -
            assetIn.quantity -
            assetIn.collectedFees -
            assetIn.collectedCashbacks;

        (uint _share, uint _totalCurrentUsdAmount) = _mintLp(
            assetIn,
            availableBalance,
            baseTradeFee,
            totalCurrentUsdAmount
        );
        (uint _quantity, uint _newTotalCurrentUsdAmount) = _burnLp(
            assetOut,
            _share,
            baseTradeFee,
            _totalCurrentUsdAmount
        );
        quantity = _quantity;

        totalCurrentUsdAmount = _newTotalCurrentUsdAmount;

        emit AssetQuantityChange(_assetIn, assetIn.quantity);
        emit AssetQuantityChange(_assetOut, assetOut.quantity);

        assets[_assetIn] = assetIn;
        assets[_assetOut] = assetOut;

        IERC20(_assetOut).transfer(_to, quantity);
    }

    /** ---------------- Owner ------------------ */

    function updatePrice(address _asset, uint _price) public onlyOwner {
        Asset memory asset = assets[_asset];
        totalCurrentUsdAmount -= (asset.quantity * asset.price) / denominator;
        totalCurrentUsdAmount += (asset.quantity * _price) / denominator;
        asset.price = _price;
        assets[_asset] = asset;
        emit AssetPriceChange(_asset, _price);
    }

    function updateAssetPercents(
        address _asset,
        uint _percent
    ) public onlyOwner {
        Asset memory asset = assets[_asset];
        totalAssetPercents -= asset.percent;
        totalAssetPercents += _percent;
        asset.percent = _percent;
        assets[_asset] = asset;
        emit AssetPercentsChange(_asset, _percent);
    }

    function setRestrictPercent(uint _restrictPercent) external onlyOwner {
        restrictPercent = _restrictPercent;
    }

    function setCurveDelay(uint _curveDelay) external onlyOwner {
        curveDelay = _curveDelay;
    }

    function setBaseTradeFee(uint _baseTradeFee) external onlyOwner {
        baseTradeFee = _baseTradeFee;
    }
}
