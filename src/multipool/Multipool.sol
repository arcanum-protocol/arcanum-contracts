// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only heart

import "forge-std/Test.sol";
import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MpAsset, MpContext} from "./MpMath.sol";
import {FeedInfo, FeedType} from "./PriceMath.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/utils/ReentrancyGuardUpgradeable.sol";
import { FixedPoint96 } from "uniswapv3/libraries/FixedPoint96.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Multipool is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    function initialize(string memory mpName, string memory mpSymbol, address owner, uint sharePrice) public initializer {
        __ERC20_init(mpName, mpSymbol);
        __ERC20Permit_init(mpName);
        __ReentrancyGuard_init();
        __Ownable_init(owner);
        initialSharePrice = sharePrice;
        targetShareAuthority = owner;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * ---------------- Variables ------------------
     */

    mapping(address => MpAsset) internal assets;
    mapping(address => FeedInfo) internal prices;

    uint internal totalTargetShares;

    uint internal halfDeviationFee;
    uint internal deviationLimit;
    uint internal depegBaseFee;
    uint internal baseFee;

    uint internal constant DENOMINATOR = 1e18;

    address public targetShareAuthority;

    uint internal totalCollectedCashbacks;
    uint internal collectedFees;

    bool public isPaused;
    uint internal initialSharePrice;

    modifier notPaused() {
        _;
    }

    // ---------------- Methods ------------------

    function getAsset(address assetAddress) public view returns (MpAsset memory asset) {
        asset = assets[assetAddress];
    }

    function getContext() internal view returns (MpContext memory context) {
        uint ts = totalSupply();
        context = MpContext({
           sharePrice: ts == 0 ? initialSharePrice: prices[address(this)].getPrice(),
           oldTotalSupply: ts,
           totalSupplyDelta: 0,
           totalTargetShares: totalTargetShares,
           deviationParam: halfDeviationFee * DENOMINATOR / deviationLimit,
           deviationLimit: deviationLimit,
           depegBaseFee: depegBaseFee,
           baseFee: baseFee,
           feeToPay: 0,
           cashbackDelta: 0,
           feeDelta: 0,
           totalCollectedCashbacks: totalCollectedCashbacks,
           collectedFees: collectedFees,
           cummulativeInAmount: 0,
           cummulativeOutAmount: 0
       });
    }

    function getTransferredAmount(MpAsset memory asset, address assetAddress) internal view returns (uint amount) {
        amount = IERC20(assetAddress).balanceOf(address(this)) - asset.quantity;
    }

    function getPricesAndSumQuotes(
        MpContext memory ctx, 
        AssetArg[] memory selectedAssets
    ) internal view returns (uint[] memory pr) {
        pr = new uint[](selectedAssets.length);
        for (uint i = 0; i < selectedAssets.length; i++) {
            uint price; 
            if (selectedAssets[i].addr == address(this)) { 
                price = ctx.sharePrice;
                ctx.totalSupplyDelta -= selectedAssets[i].amount;
            } else {
                price = prices[selectedAssets[i].addr].getPrice();
            }
            pr[i] = price;
            require(selectedAssets[i].amount != 0, "ASSET AMOUNT EQ 0");
            if (selectedAssets[i].amount > 0) {
                ctx.cummulativeInAmount += price * uint(selectedAssets[i].amount) / FixedPoint96.Q96;
            } else {
                ctx.cummulativeOutAmount += price * uint(-selectedAssets[i].amount) / FixedPoint96.Q96;
            }
        }
    }

    struct AssetArg {
        address addr;
        int amount;
    }

    function swap(
        AssetArg[] calldata selectedAssets, 
        bool isSleepageReverse,
        address to
    )
        public
        payable
        notPaused
        nonReentrant
    {
        MpContext memory ctx = getContext();
        uint[] memory currentPrices = getPricesAndSumQuotes(ctx, selectedAssets);

        for (uint i = 0; i < selectedAssets.length; i++) {
            MpAsset memory asset; 
            if (selectedAssets[i].addr != address(this)) {
                asset = assets[selectedAssets[i].addr];
            }
            uint price = currentPrices[i]; 
            int deltaAmount = selectedAssets[i].amount;
            if (!isSleepageReverse) {
                if (selectedAssets[i].amount > 0) {
                    uint transferred = getTransferredAmount(asset, selectedAssets[i].addr);
                    require(transferred >= uint(selectedAssets[i].amount), "INSUFFICIENT TRANSFERRED");
                } else {
                    uint amount = ctx.cummulativeInAmount * uint(-selectedAssets[i].amount) / ctx.cummulativeOutAmount;

                    require(int(amount) >= selectedAssets[i].amount, "SLIPPAGE ON OUT");
                    if (selectedAssets[i].addr != address(this)) {
                        IERC20(selectedAssets[i].addr).transfer(to, amount);
                    }

                    deltaAmount = -int(amount);
                }
            } else {
                if (selectedAssets[i].amount > 0) {
                    uint amount = ctx.cummulativeOutAmount * uint(selectedAssets[i].amount) / ctx.cummulativeInAmount;

                    uint transferred = getTransferredAmount(asset, selectedAssets[i].addr);
                    require(amount <= uint(selectedAssets[i].amount), "SLIPPAGE ON IN");
                    require(transferred >= amount, "INSUFFICIENT TRANSFERRED");

                    deltaAmount = int(amount);
                } else {
                    if (selectedAssets[i].addr != address(this)) {
                        IERC20(selectedAssets[i].addr).transfer(to, uint(-selectedAssets[i].amount));
                    }
                }
            }
            if (selectedAssets[i].addr != address(this)) {
                ctx.calculateFees(asset, deltaAmount, price);
                assets[selectedAssets[i].addr] = asset;
            } else {
                ctx.calculateFeesShareToken(deltaAmount);
            }
        }
        ctx.applyCollected();
        if (ctx.totalSupplyDelta > 0) {
            _mint(to, uint(ctx.totalSupplyDelta));
        } else if (ctx.totalSupplyDelta < 0) {
            _burn(address(this), uint(-ctx.totalSupplyDelta));
        }

        totalCollectedCashbacks = ctx.totalCollectedCashbacks;
        collectedFees = ctx.collectedFees;
    }

    // ---------------- Authorities ------------------

    function increaseCashback(address assetAddress) public notPaused nonReentrant returns (uint amount) {
        MpAsset storage asset = assets[assetAddress];
        amount = getTransferredAmount(asset, assetAddress);
        asset.collectedCashbacks += amount;
    }

    function updatePrice(address assetAddress, FeedType kind, bytes calldata feedData) public notPaused {
        prices[assetAddress] = FeedInfo ({
            kind: kind,
            data: feedData
        });
    }

    function updateTargetShares(address[] calldata assetAddresses, uint[] calldata shares) public onlyOwner notPaused {
        require(targetShareAuthority == msg.sender, "MULTIPOOL: TA");
        for (uint a = 0; a < assetAddresses.length; a++) {
            MpAsset storage asset = assets[assetAddresses[a]];
            totalTargetShares = totalTargetShares - asset.share + shares[a];
            asset.share = shares[a];
        }
    }

    function withdrawFees(address to) public onlyOwner notPaused returns (uint fees) {
        fees = collectedFees;
        collectedFees = 0;
        payable(to).transfer(fees);
    }

     // ---------------- Owner ------------------

    function togglePause() external onlyOwner {
        isPaused = !isPaused;
    }

   // function setTokenDecimals(address assetAddress, uint decimals) external onlyOwner {
   //     MpAsset storage asset = assets[assetAddress];
   //     asset.decimals = decimals;
   // }

    function setCurveParams(uint newDeviationLimit, uint newHalfDeviationFee, uint newDepegBaseFee, uint newBaseFee) external onlyOwner {
        deviationLimit = newDeviationLimit;
        halfDeviationFee = newHalfDeviationFee;
        depegBaseFee = newDepegBaseFee;
        baseFee = newBaseFee;
    }
}
