// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/farm/Farm.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {UniV3Feed} from "../src/lib/Price.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice} from "../test/MultipoolUtils.t.sol";

contract DeployFarm is Script {
    function run() external {
        // test deployer private key
        uint256 pkey = uint(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        address deployer = vm.addr(pkey);

        vm.startBroadcast(pkey);

        bytes32 arbiSalt = keccak256(abi.encode("chipi chipi"));
        MockERC20 arbi = new MockERC20{salt: arbiSalt}("ARBI", "Arbitrum Ecosystem Index", 0);
        arbi.mint(deployer, 1000e18);

        bytes32 spiSalt = keccak256(abi.encode("chapa chapa"));
        MockERC20 spi = new MockERC20{salt: spiSalt}("SPI", "Sharpe Portfolio Index", 0);
        spi.mint(deployer, 1000e18);

        Farm farmImpl = new Farm();
        bytes32 farmSalt = keccak256(abi.encode("dubi dubi"));

        Farm farm = Farm(
            address(
                new ERC1967Proxy{salt: farmSalt}(
                    address(farmImpl), abi.encodeWithSignature("initialize(address)", deployer)
                )
            )
        );

        bytes32 pointSalt = keccak256(abi.encode("dab dab"));
        MockERC20 points = new MockERC20{salt: pointSalt}("APOINTS", "Arcanum points", 0);
        points.mint(deployer, 1000e18);

        bytes32 arbSalt = keccak256(abi.encode("daba daba"));
        MockERC20 arb = new MockERC20{salt: arbSalt}("Arb", "Arbitrum", 0);
        arb.mint(deployer, 1000e18);

        bytes32 wbtcSalt = keccak256(abi.encode("magic pony"));
        MockERC20WithDecimals wbtc =
            new MockERC20WithDecimals{salt: wbtcSalt}("WBTC", "Wrapped bitcoin", 8);
        wbtc.mint(deployer, 1000e18);

        farm.addPool(address(arbi), address(arb), address(0));

        arb.approve(address(farm), 100e18);
        farm.updateDistribution(0, 100e18, 1585489599188);

        farm.addPool(address(spi), address(wbtc), address(points));

        wbtc.approve(address(farm), 100e8);
        farm.updateDistribution(1, 100e8, 158);

        points.approve(address(farm), 100e18);
        farm.updateDistribution2(1, 100e18, 158);

        console.log("farm", address(farm));
        console.log("deployer", address(deployer));
        console.log("arbi", address(arbi));
        console.log("spi", address(spi));
        console.log("wbtc", address(wbtc));
        console.log("arb", address(arb));
        console.log("points", address(points));

        vm.stopBroadcast();
    }
}

contract DeployFarmToProd is Script {
    function run() external {
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pkey);

        vm.startBroadcast(pkey);
        bytes32 farmImplSalt = keccak256(abi.encode("dubi dubi impl"));
        bytes32 farmSalt = keccak256(abi.encode("dubi dubi"));

        Farm farmImpl = new Farm{salt: farmImplSalt }();

        Farm farm = Farm(
            address(
                new ERC1967Proxy{salt: farmSalt}(
                    address(farmImpl), abi.encodeWithSignature("initialize(address)", deployer)
                )
            )
        );
        console.log("farm", address(farm));
        console.log("farm impl", address(farmImpl));
        console.log("deployer", address(deployer));
        vm.stopBroadcast();
    }
}
