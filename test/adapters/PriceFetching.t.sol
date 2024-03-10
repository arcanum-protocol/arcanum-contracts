// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {ISilo, ISiloLens, IBaseSilo} from "../../src/interfaces/ISiloPool.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {SiloPriceAdapter} from "../../src/multipool/SiloAdapter.sol";
import {FeedInfo, FeedType, PriceMath, UniV3Feed} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32} from "../MultipoolUtils.t.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract SiloAdapterTests is Test {
    receive() external payable {}

    uint arbitrumFork;

    function setUp() public {
        arbitrumFork = vm.createFork("https://rpc.ankr.com/arbitrum", 188758399);
    }

    function test_FetchDataFromSiloPoolAndAdapter() public {
        vm.selectFork(arbitrumFork);

        SiloPriceAdapter impl = new SiloPriceAdapter();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeWithSignature(
                "initialize(address,address)",
                address(this),
                address(0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536)
            )
        );
        SiloPriceAdapter siloAdapter = SiloPriceAdapter(address(proxy));

        IERC20 baseToken = IERC20(0x3082CC23568eA640225c2467653dB90e9250AaA0);
        ISilo silo = ISilo(0x19d3F8D09773065867e9fD11716229e73481c55A);

        ISilo.AssetStorage memory info = silo.assetStorage(address(baseToken));

        uint value = ISiloLens(0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536).totalDepositsWithInterest(
            silo, address(baseToken)
        );

        uint price =
            PriceMath.getTwapX96(address(0x446BF9748B4eA044dd759d9B9311C70491dF8F29), false, 60);

        uint priceX96 = price * (value) / IERC20(info.collateralToken).totalSupply();

        siloAdapter.createFeed(
            address(baseToken),
            ISilo(0x19d3F8D09773065867e9fD11716229e73481c55A),
            FeedInfo({
                kind: FeedType.UniV3,
                data: abi.encode(
                    UniV3Feed({
                        oracle: address(0x446BF9748B4eA044dd759d9B9311C70491dF8F29),
                        reversed: false,
                        twapInterval: 60
                    })
                    )
            })
        );
        assertEq(priceX96, siloAdapter.getPrice(0));
    }
}
