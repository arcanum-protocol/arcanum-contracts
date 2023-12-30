// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract MultipoolSwapEstimate is Test, MultipoolUtils {

    using ECDSA for bytes32;

    receive() external payable {}

    function test_PassNotEnoughSignatures() public {
        vm.startPrank(owner);
        mp.setAuthorityRights(owner, false, true);
        mp.setAuthorityRights(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266), true, false);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));
        mp.setSharePriceParams(60, 0);
        uint[] memory p = new uint[](5);
        p[0] = toX96(0.01e18);
        p[1] = toX96(0.02e18);
        p[2] = toX96(0.03e18);
        p[3] = toX96(0.04e18);
        p[4] = toX96(0.05e18);

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        uint[] memory s = new uint[](5);
        s[0] = 10e18;
        s[1] = 10e18;
        s[2] = 10e18;
        s[3] = 10e18;
        s[4] = 10e18;

        mp.updateTargetShares(t, s);

        for (uint i = 0; i < t.length; i++) {
            updatePrice(address(mp), address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
        }
        setCurveParams(toX32(0.15e18), toX32(0.0003e18), toX32(0.01e18), toX32(0.6e18));
        vm.stopPrank();

        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / p[1];

        vm.warp(1701399851);
        ForcePushArgs memory fp;
        fp.contractAddress = address(mp);
        fp.timestamp = 1701395175;
        fp.sharePrice = 7922816251426433759354395033;
        fp.signatures = new bytes[](0);

        vm.expectRevert(abi.encodeWithSignature("InvalidForcePushSignatureNumber()"));
        mp.checkSwap(
            fp,
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(val)}),
                        AssetArgs({assetAddress: address(mp), amount: -1e18})
                    ]
                )
            ),
            true
        );
    }

    function test_CheckForcePushSignaturePreventsDuplication() public {
        vm.startPrank(owner);
        mp.setAuthorityRights(owner, false, true);
        mp.setAuthorityRights(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266), true, false);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));
        mp.setSharePriceParams(60, 0);
        uint[] memory p = new uint[](5);
        p[0] = toX96(0.01e18);
        p[1] = toX96(0.02e18);
        p[2] = toX96(0.03e18);
        p[3] = toX96(0.04e18);
        p[4] = toX96(0.05e18);

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        uint[] memory s = new uint[](5);
        s[0] = 10e18;
        s[1] = 10e18;
        s[2] = 10e18;
        s[3] = 10e18;
        s[4] = 10e18;

        mp.updateTargetShares(t, s);

        for (uint i = 0; i < t.length; i++) {
            updatePrice(address(mp), address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
        }
        setCurveParams(toX32(0.15e18), toX32(0.0003e18), toX32(0.01e18), toX32(0.6e18));
        vm.stopPrank();

        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / p[1];

        vm.warp(1701391951);
        ForcePushArgs memory fp;
        fp.contractAddress = address(mp);
        fp.timestamp = 1702111278;
        fp.sharePrice = 7922816251426433759354395033;
        fp.signatures = new bytes[](2);
        fp.signatures[0] = hex"e38c327593c584e1df70f649273fa89b25497bedcbea5a6b4fcc055235f085cd3a5630a7361e7b68eb795141e82cca9e1e535dd09074adb304aec400fc73048f1c";
        fp.signatures[1] = hex"e38c327593c584e1df70f649273fa89b25497bedcbea5a6b4fcc055235f085cd3a5630a7361e7b68eb795141e82cca9e1e535dd09074adb304aec400fc73048f1c";

        vm.expectRevert(abi.encodeWithSignature("SignaturesNotSortedOrNotUnique()"));
        mp.checkSwap(
            fp,
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(val)}),
                        AssetArgs({assetAddress: address(mp), amount: -1e18})
                    ]
                )
            ),
            true
        );

        fp.signatures = new bytes[](0);

        vm.expectRevert(abi.encodeWithSignature("InvalidForcePushSignatureNumber()"));
        mp.checkSwap(
            fp,
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(val)}),
                        AssetArgs({assetAddress: address(mp), amount: -1e18})
                    ]
                )
            ),
            true
        );
    }

    function test_CheckMultipleForcePushSignaturesWork() public {
        vm.startPrank(owner);
        mp.setAuthorityRights(owner, false, true);
        mp.setAuthorityRights(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266), true, false);


        (address priceAuth, uint priceAuthPk) = makeAddrAndKey("Multipool price authority");
        mp.setAuthorityRights(priceAuth, true, false);

        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));
        mp.setSharePriceParams(60, 1);
        uint[] memory p = new uint[](5);
        p[0] = toX96(0.01e18);
        p[1] = toX96(0.02e18);
        p[2] = toX96(0.03e18);
        p[3] = toX96(0.04e18);
        p[4] = toX96(0.05e18);

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        uint[] memory s = new uint[](5);
        s[0] = 10e18;
        s[1] = 10e18;
        s[2] = 10e18;
        s[3] = 10e18;
        s[4] = 10e18;

        mp.updateTargetShares(t, s);

        for (uint i = 0; i < t.length; i++) {
            updatePrice(address(mp), address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
        }
        setCurveParams(toX32(0.15e18), toX32(0.0003e18), toX32(0.01e18), toX32(0.6e18));
        vm.stopPrank();

        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / p[1];

        vm.warp(1701391951);
        ForcePushArgs memory fp;
        fp.contractAddress = address(mp);
        fp.timestamp = 1702111278;
        fp.sharePrice = 7922816251426433759354395033;
        fp.signatures = new bytes[](2);

        {
            bytes32 message =
                keccak256(abi.encodePacked(fp.contractAddress, uint(fp.timestamp), uint(fp.sharePrice), uint(block.chainid))).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 _s) = vm.sign(priceAuthPk, message);
            bytes memory signature2 = abi.encodePacked(r, _s, v);

            fp.signatures[1] = hex"e38c327593c584e1df70f649273fa89b25497bedcbea5a6b4fcc055235f085cd3a5630a7361e7b68eb795141e82cca9e1e535dd09074adb304aec400fc73048f1c";
            fp.signatures[0] = signature2;
        }

        (int expectedFee, int[] memory amounts) = mp.checkSwap(
            fp,
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(val)}),
                        AssetArgs({assetAddress: address(mp), amount: -1e18})
                    ]
                )
            ),
            true
        );

        assertEq(expectedFee, 99999997764825820);
        assertEq(amounts.length, 2);
        assertEq(amounts[1], int(val));
        assertEq(amounts[0], -int(100e18 + 990));

        {
            bytes32 message =
                keccak256(abi.encodePacked(fp.contractAddress, uint(fp.timestamp), uint(fp.sharePrice), uint(block.chainid))).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 _s) = vm.sign(priceAuthPk, message);
            bytes memory signature2 = abi.encodePacked(r, _s, v);

            fp.signatures[0] = hex"e38c327593c584e1df70f649273fa89b25497bedcbea5a6b4fcc055235f085cd3a5630a7361e7b68eb795141e82cca9e1e535dd09074adb304aec400fc73048f1c";
            fp.signatures[1] = signature2;
        }

        vm.expectRevert(abi.encodeWithSignature("SignaturesNotSortedOrNotUnique()"));
        mp.checkSwap(
            fp,
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(val)}),
                        AssetArgs({assetAddress: address(mp), amount: -1e18})
                    ]
                )
            ),
            true
        );

        {
            bytes32 message =
                keccak256(abi.encodePacked(fp.contractAddress, uint(fp.timestamp), uint(fp.sharePrice), uint(block.chainid))).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 _s) = vm.sign(priceAuthPk, message);
            bytes memory signature2 = abi.encodePacked(r, _s, v);

            fp.signatures[1] = signature2;
            fp.signatures[0] = hex"a38c327593c584e1df70f649273fa89b25497bedcbea5a6b4fcc055235f085cd3a5630a7361e7b68eb795141e82cca9e1e535dd09074adb304aec400fc73048f1c";
        }

        vm.expectRevert(abi.encodeWithSignature("InvalidForcePushAuthority()"));
        mp.checkSwap(
            fp,
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(val)}),
                        AssetArgs({assetAddress: address(mp), amount: -1e18})
                    ]
                )
            ),
            true
        );
    }
}
