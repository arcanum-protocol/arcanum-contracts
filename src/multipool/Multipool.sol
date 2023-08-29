// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only heart

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MpAsset, MpContext} from "./MpCommonMath.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract Multipool is ERC20, Ownable {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        priceAuthority = msg.sender;
        targetShareAuthority = msg.sender;
        withdrawAuthority = msg.sender;
    }

    event AssetTargetShareChange(address indexed asset, uint share);
    event AssetQuantityChange(address indexed asset, uint quantity);
    event AssetPriceChange(address indexed asset, uint price);
    event WithdrawFees(address indexed asset, uint value);

    event TargetShareAuthorityChange(address authority);
    event PriceAuthorityChange(address authority);
    event WithdrawAuthorityChange(address authority);

    event HalfDeviationFeeChange(uint value);
    event DeviationLimitChange(uint value);
    event BaseMintFeeChange(uint value);
    event BaseBurnFeeChange(uint value);
    event BaseTradeFeeChange(uint value);
    event DepegBaseFeeChange(uint value);

    /**
     * ---------------- Variables ------------------
     */

    mapping(address => MpAsset) public assets;
    uint public usdCap;
    uint public totalTargetShares;

    uint public halfDeviationFee;
    uint public deviationLimit;
    uint public depegBaseFee;

    uint public baseMintFee;
    uint public baseBurnFee;
    uint public baseTradeFee;
    uint public constant DENOMINATOR = 1e18;

    address public feeReceiver;
    address public priceAuthority;
    address public targetShareAuthority;
    address public withdrawAuthority;

    /**
     * ---------------- Methods ------------------
     */

    function getAssets(address assetAddress) public view returns (MpAsset memory asset) {
        asset = assets[assetAddress];
    }

    function getMintData(address assetAddress)
        public
        view
        returns (MpContext memory context, MpAsset memory asset, uint ts)
    {
        context = getContext(0);
        asset = assets[assetAddress];
        ts = totalSupply();
    }

    function getBurnData(address assetAddress)
        public
        view
        returns (MpContext memory context, MpAsset memory asset, uint ts)
    {
        context = getContext(1);
        asset = assets[assetAddress];
        ts = totalSupply();
    }

    function getTradeData(address assetInAddress, address assetOutAddress)
        public
        view
        returns (MpContext memory context, MpAsset memory assetIn, MpAsset memory assetOut, uint ts)
    {
        context = getContext(2);
        assetIn = assets[assetInAddress];
        assetOut = assets[assetOutAddress];
        ts = totalSupply();
    }

    // 0 - mint
    // 1 - burn
    // 2 - swap
    function getContext(uint action) public view returns (MpContext memory context) {
        context = MpContext({
            usdCap: usdCap,
            totalTargetShares: totalTargetShares,
            halfDeviationFee: halfDeviationFee,
            deviationLimit: deviationLimit,
            operationBaseFee: action == 0 ? baseMintFee : (action == 1 ? baseBurnFee : baseTradeFee),
            userCashbackBalance: 0e18,
            depegBaseFee: depegBaseFee
        });
    }

    function getTransferredAmount(MpAsset memory asset, address assetAddress) public view returns (uint amount) {
        amount = IERC20(assetAddress).balanceOf(address(this)) - asset.quantity - asset.collectedFees
            - asset.collectedCashbacks;
    }

    function shareToAmount(uint share, MpContext memory context, MpAsset memory asset, uint totalSupply)
        public
        pure
        returns (uint amount)
    {
        amount = (share * context.usdCap * DENOMINATOR) / totalSupply / asset.price;
    }

    function mint(address assetAddress, uint share, address to) public returns (uint amountIn, uint refund) {
        require(share != 0, "MULTIPOOL: ZS");
        MpAsset memory asset = assets[assetAddress];
        require(asset.price != 0, "MULTIPOOL: ZP");
        require(asset.share != 0, "MULTIPOOL: ZT");
        MpContext memory context = getContext(0);

        uint transferredAmount = getTransferredAmount(asset, assetAddress);
        uint amountOut = totalSupply() != 0 ? shareToAmount(share, context, asset, totalSupply()) : transferredAmount;

        amountIn = context.evalMint(asset, amountOut);
        require(amountIn <= transferredAmount, "MULTIPOOL: IQ");

        usdCap = context.usdCap;
        // add unused quantity to refund
        refund = context.userCashbackBalance;
        uint returnAmount = (transferredAmount - amountIn) + refund;

        _mint(to, share);
        assets[assetAddress] = asset;
        if (returnAmount > 0) {
            IERC20(assetAddress).transfer(to, returnAmount);
        }
        emit AssetQuantityChange(assetAddress, asset.quantity);
    }

    // share here needs to be specified and can't be taken by balance of because
    // if there is too much share you will be frozen by deviaiton limit overflow
    function burn(address assetAddress, uint share, address to) public returns (uint amountOut, uint refund) {
        require(share != 0, "MULTIPOOL: ZS");
        MpAsset memory asset = assets[assetAddress];
        require(asset.price != 0, "MULTIPOOL: ZP");
        MpContext memory context = getContext(1);

        uint amountIn = shareToAmount(share, context, asset, totalSupply());
        amountOut = context.evalBurn(asset, amountIn);

        usdCap = context.usdCap;
        refund = context.userCashbackBalance;

        _burn(address(this), share);
        assets[assetAddress] = asset;
        IERC20(assetAddress).transfer(to, amountOut + refund);
        _transfer(address(this), to, balanceOf(address(this)));
        emit AssetQuantityChange(assetAddress, asset.quantity);
    }

    function swap(address assetInAddress, address assetOutAddress, uint share, address to)
        public
        returns (uint amountIn, uint amountOut, uint refundIn, uint refundOut)
    {
        require(assetInAddress != assetOutAddress, "MULTIPOOL: SA");
        require(share != 0, "MULTIPOOL: ZS");
        MpAsset memory assetIn = assets[assetInAddress];
        MpAsset memory assetOut = assets[assetOutAddress];
        require(assetIn.price != 0, "MULTIPOOL: ZP");
        require(assetIn.share != 0, "MULTIPOOL: ZT");
        require(assetOut.price != 0, "MULTIPOOL: ZP");
        require(assetOut.share != 0, "MULTIPOOL: ZT");
        MpContext memory context = getContext(2);

        uint transferredAmount = getTransferredAmount(assetIn, assetInAddress);
        {
            {
                uint _amountOut = shareToAmount(share, context, assetIn, totalSupply());
                amountIn = context.evalMint(assetIn, _amountOut);
                require(amountIn <= transferredAmount, "MULTIPOOL: IQ");

                refundIn = context.userCashbackBalance;
                context.userCashbackBalance = 0;
            }
        }

        {
            {
                uint _amountIn = shareToAmount(share, context, assetOut, totalSupply() + share);
                amountOut = context.evalBurn(assetOut, _amountIn);

                refundOut = context.userCashbackBalance;
                usdCap = context.usdCap;
            }
        }

        assets[assetInAddress] = assetIn;
        assets[assetOutAddress] = assetOut;

        if (amountOut + refundOut > 0) {
            IERC20(assetOutAddress).transfer(to, (amountOut + refundOut));
        }
        if (refundIn + (transferredAmount - amountIn) > 0) {
            IERC20(assetInAddress).transfer(to, refundIn + (transferredAmount - amountIn));
        }
        emit AssetQuantityChange(assetInAddress, assetIn.quantity);
        emit AssetQuantityChange(assetOutAddress, assetOut.quantity);
    }

    function increaseCashback(address assetAddress) public returns (uint amount) {
        MpAsset storage asset = assets[assetAddress];
        amount = getTransferredAmount(asset, assetAddress);
        asset.collectedCashbacks += amount;
    }

    /**
     * ---------------- Authorities ------------------
     */

    function updatePrices(address[] calldata assetAddresses, uint[] calldata prices) public {
        require(priceAuthority == msg.sender, "MULTIPOOL: PA");
        for (uint a = 0; a < assetAddresses.length; a++) {
            MpAsset storage asset = assets[assetAddresses[a]];
            usdCap = usdCap - (asset.quantity * asset.price) / DENOMINATOR + (asset.quantity * prices[a]) / DENOMINATOR;
            asset.price = prices[a];
            emit AssetPriceChange(assetAddresses[a], prices[a]);
        }
    }

    function updateTargetShares(address[] calldata assetAddresses, uint[] calldata shares) public {
        require(targetShareAuthority == msg.sender, "MULTIPOOL: TA");
        for (uint a = 0; a < assetAddresses.length; a++) {
            MpAsset storage asset = assets[assetAddresses[a]];
            totalTargetShares = totalTargetShares - asset.share + shares[a];
            asset.share = shares[a];
            emit AssetTargetShareChange(assetAddresses[a], shares[a]);
        }
    }

    function withdrawFees(address assetAddress, address to) public returns (uint fees) {
        require(withdrawAuthority == msg.sender, "MULTIPOOL: WA");
        MpAsset storage asset = assets[assetAddress];
        fees = asset.collectedFees;
        asset.collectedFees = 0;
        IERC20(assetAddress).transfer(to, fees);
        emit WithdrawFees(assetAddress, fees);
    }

    /**
     * ---------------- Owner ------------------
     */

    function setDeviationLimit(uint newDeviationLimit) external onlyOwner {
        deviationLimit = newDeviationLimit;
        emit DeviationLimitChange(newDeviationLimit);
    }

    function setHalfDeviationFee(uint newHalfDeviationFee) external onlyOwner {
        halfDeviationFee = newHalfDeviationFee;
        emit HalfDeviationFeeChange(newHalfDeviationFee);
    }

    function setBaseTradeFee(uint newBaseTradeFee) external onlyOwner {
        baseTradeFee = newBaseTradeFee;
        emit BaseTradeFeeChange(newBaseTradeFee);
    }

    function setBaseMintFee(uint newBaseMintFee) external onlyOwner {
        baseMintFee = newBaseMintFee;
        emit BaseMintFeeChange(newBaseMintFee);
    }

    function setDepegBaseFee(uint newDepegBaseFee) external onlyOwner {
        depegBaseFee = newDepegBaseFee;
        emit DepegBaseFeeChange(newDepegBaseFee);
    }

    function setBaseBurnFee(uint newBaseBurnFee) external onlyOwner {
        baseBurnFee = newBaseBurnFee;
        emit BaseBurnFeeChange(newBaseBurnFee);
    }

    function setPriceAuthority(address newPriceAuthority) external onlyOwner {
        priceAuthority = newPriceAuthority;
        emit PriceAuthorityChange(newPriceAuthority);
    }

    function setTargetShareAuthority(address newTargetShareAuthority) external onlyOwner {
        targetShareAuthority = newTargetShareAuthority;
        emit TargetShareAuthorityChange(newTargetShareAuthority);
    }

    function setWithdrawAuthority(address newWithdrawAuthority) external onlyOwner {
        withdrawAuthority = newWithdrawAuthority;
        emit WithdrawAuthorityChange(newWithdrawAuthority);
    }
}
