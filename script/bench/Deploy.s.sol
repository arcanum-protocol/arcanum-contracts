// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {Oracle} from "../../src/multipool/Oracle.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, toX16, toX16RatioTick, updatePrice} from "../../test/MultipoolUtils.t.sol";

// forge script ./script/bench/Deploy.s.sol --rpc-url=https://arbitrum-sepolia.drpc.org --broadcast
// -vvvv
contract Deploy is Script {
    function run() external {
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        // console.log(deployerPublicKey);
        vm.startBroadcast(deployerPrivateKey);

        Oracle oracleImpl = new Oracle();
        ERC1967Proxy oracleProxy =
            new ERC1967Proxy(address(oracleImpl), abi.encodeWithSignature("initialize()"));
        console.log("oracle ", address(oracleProxy));

        Multipool mpImpl = new Multipool{salt: keccak256(abi.encode("MultipoolSalt4", 1))}();
        ERC1967Proxy proxy =
            new ERC1967Proxy{salt: keccak256(abi.encode("ProxySalt4", 1))}(address(mpImpl), "");
        console2.log("mp ", address(proxy));

        Multipool mp = Multipool(address(proxy));
        mp.initialize("Name", "SYMBOL");

        // console2.log("Proxy address: ", address(mp));
        // console.log("Etf address: ", address(mpImpl));

        // Multipool mp = Multipool(address(0x063F8415d027F504c48533C32bd3f66A1E5c5c92));

        MockERC20WithDecimals[] memory tokens = new MockERC20WithDecimals[](5);
        // tokens[0] = MockERC20WithDecimals(0x6573027624bA52bebCAE1Ae07ed98b0B188F1E33);
        // tokens[1] = MockERC20WithDecimals(0x4c2ab15e33bc34610c63863bb3A39De0B79a0D15);
        // tokens[2] = MockERC20WithDecimals(0xF8b370484A153CD3df5dd6C1a027b007025077F2);
        // tokens[3] = MockERC20WithDecimals(0x102F9659Eb51E00477256a53DA460a475c4eaF75);
        // tokens[4] = MockERC20WithDecimals(0x2BeB75450683B0f6ac402387d392849949CE7A6D);

        //   0x65Fc395Ec32D69551B3966f8E5323fd233a8C9eC
        //   proxy  0x063F8415d027F504c48533C32bd3f66A1E5c5c92
        //   Proxy address:  0x063F8415d027F504c48533C32bd3f66A1E5c5c92
        //   Etf address:  0x6b18ce1544b01B1Fb0237c5ca9E89E3ec78866a8
        //   token 0  address:  0x6573027624bA52bebCAE1Ae07ed98b0B188F1E33
        //   token 1  address:  0x4c2ab15e33bc34610c63863bb3A39De0B79a0D15
        //   token 2  address:  0xF8b370484A153CD3df5dd6C1a027b007025077F2
        //   token 3  address:  0x102F9659Eb51E00477256a53DA460a475c4eaF75
        //   token 4  address:  0x2BeB75450683B0f6ac402387d392849949CE7A6D
        {
            uint8[5] memory decimals = [6, 6, 18, 18, 18];
            for (uint i = 0; i < tokens.length; i++) {
                tokens[i] = new MockERC20WithDecimals{
                    salt: keccak256(abi.encode("TokenSalt332234", "token", i))
                }("token", "token", decimals[i]);
                tokens[i].mint(deployerPublicKey, 10000e18);
                console2.log("token", i, " address: ", address(tokens[i]));
            }

            address[] memory tokensAddresses = new address[](5);
            tokensAddresses[0] = address(tokens[0]);
            tokensAddresses[1] = address(tokens[1]);
            tokensAddresses[2] = address(tokens[2]);
            tokensAddresses[3] = address(tokens[3]);
            tokensAddresses[4] = address(tokens[4]);

            uint16[] memory s = new uint16[](5);
            s[0] = 10;
            s[1] = 10;
            s[2] = 10;
            s[3] = 10;
            s[4] = 10;

            address[] memory tokensAddressesPrice = new address[](0);
            bytes32[] memory tokensPrice = new bytes32[](0);

            mp.updateAssets(tokensAddressesPrice, tokensPrice, tokensAddresses, s);
        }

        updatePrice(
            address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.09e18)))
        );
        mp.setFeeParams(
            toX16RatioTick(0.0003e5),
            toX16RatioTick(0.15e5),
            toX16RatioTick(0.6e5),
            toX16RatioTick(0.01e5),
            toX16RatioTick(0.01e5),
            toX16RatioTick(0.01e5),
            deployerPublicKey,
            deployerPublicKey,
            deployerPublicKey
        );

        vm.stopBroadcast();
    }
}
