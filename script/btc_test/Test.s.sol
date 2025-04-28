// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {Oracle} from "../../src/multipool/Oracle.sol";
import {MultipoolFactory, MultipoolCreationParams} from "../../src/multipool/Factory.sol";
import {Trader} from "../../src/trader/Trader.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {
    toX96,
    toX32,
    toX16,
    updatePrice,
    AbstractFixedValueOracle,
    computeContractAddress
} from "../../test/MultipoolUtils.t.sol";

// forge script ./script/bench/Deploy.s.sol --rpc-url=127.0.0.1:8545 --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        // console.log(deployerPublicKey);
        vm.startBroadcast(deployerPrivateKey);

        uint16[] memory s = new uint16[](2);
        bytes32[] memory prices = new bytes32[](2);
        address[] memory tokensAddresses = new address[](2);
        MockERC20WithDecimals btc =
            new MockERC20WithDecimals{salt: keccak256(abi.encode("Btc"))}("Bitcoin", "BTC", 18);
        btc.mint(deployerPublicKey, 100e18);
        tokensAddresses[0] = address(btc);
        MockERC20WithDecimals usdt =
            new MockERC20WithDecimals{salt: keccak256(abi.encode("Usdt"))}("Usdt", "USDT", 18);
        usdt.mint(deployerPublicKey, 10000000e18);

        tokensAddresses[1] = address(usdt);

        {
            bytes32 val;
            bytes memory data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(49.68e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[0] = val;
            data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.00061e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[1] = val;
        }

        s[0] = 50;
        s[1] = 50;

        Oracle oracle = new Oracle{salt: keccak256(abi.encode("Oracle"))}();
        ERC1967Proxy oracleProxy =
            new ERC1967Proxy(address(oracle), abi.encodeWithSignature("initialize()"));
        oracle = Oracle(payable(address(oracleProxy)));
        // oracle.initialize();
        oracle.toggleOracle(deployerPublicKey);
        oracle.togglePanicAuthority(deployerPublicKey);
        oracle.updateFraudData(false, 1000);
        oracle.updateStakeLimits(1e18, 30e18, 3600);
        oracle.updateRewardPerSecond(1e8);

        oracle.stake(deployerPublicKey, 5e18, deployerPublicKey);

        Multipool mpImpl = new Multipool{salt: keccak256(abi.encode("Multipool"))}();

        MultipoolFactory factoryImpl =
            new MultipoolFactory{salt: keccak256(abi.encode("Factory"))}();
        ERC1967Proxy factoryProxy =
            new ERC1967Proxy{salt: keccak256(abi.encode("FactoryProxy"))}(address(factoryImpl), "");

        MultipoolFactory f = MultipoolFactory(address(factoryProxy));
        f.initialize(deployerPublicKey, address(mpImpl));
        address mp = computeContractAddress(address(f), address(mpImpl), 1);

        MultipoolCreationParams memory params = MultipoolCreationParams({
            name: "MpSepolia",
            symbol: "MPS",
            initialSharePrice: uint96(toX32(0.1e18)),
            deviationIncreaseFee: toX16(0.15e18),
            deviationLimit: toX16(0.0003e18),
            feeToCashbackRatio: toX16(0.6e18),
            baseFee: toX16(1e15),
            managementFeeRecepient: deployerPublicKey,
            managementFee: toX16(0.15e18),
            oracleAddress: address(oracle),
            strategyManager: deployerPublicKey,
            assetAddresses: tokensAddresses,
            priceData: prices,
            targetShares: s,
            initialLiquidityAsset: tokensAddresses[0],
            nonce: 1,
            owner: deployerPublicKey
        });
        btc.transfer(address(mp), 1e14);
        f.createMultipool(params);

        MultipoolRouter r = new MultipoolRouter(address(f));
        vm.stopBroadcast();
    }
}

interface IUniswapV3Pool {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;
}

interface IUniswapV3Router {
    function factory() external returns (address);

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams memory params)
        external
        payable
        returns (uint256 amountOut);

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        returns (uint256 amountIn);
}

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    )
        external
        view
        returns (address pool);

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    )
        external
        returns (address pool);
}

interface IPositionManager {
    function factory() external view returns (address);

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /// @notice Creates a new position wrapped in a NFT
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created
    /// but not initialized
    /// a method does not exist, i.e. the pool is assumed to be initialized.
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function createAndInitializePoolIfNecessary(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint160 sqrtPriceX96
    )
        external
        returns (address pool);
}
