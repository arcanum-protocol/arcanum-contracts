pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {MpCommonMath} from "../../src/multipool/MpCommonMath.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract MultipoolSingleAssetTest is Test {
    Multipool mp;

    function setUp() public {
        Multipool mpImpl = new Multipool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(mpImpl), "");
        mp = Multipool(address(proxy));
        mp.initialize("Name", "SYMBOL", address(this));
    }

    function mpUpdateTargetShare(address token, uint share) internal {
        address[] memory t = new address[](1);
        t[0] = address(token);

        uint[] memory s = new uint[](1);
        s[0] = share;
        mp.updateTargetShares(t, s);
    }

    function mpUpdatePrice(address token, uint price) internal {
        mp.updatePrice(token, price, 0, address(0));
    }

    function test_OnlyOwnerCanChangeParams() public {
        vm.expectRevert();
        vm.prank(address(0));
        mp.setBaseMintFee(1e16);

        vm.expectRevert();
        vm.prank(address(0));
        mp.setBaseBurnFee(1e16);

        vm.expectRevert();
        vm.prank(address(0));
        mp.setHalfDeviationFee(1e16);

        vm.expectRevert();
        vm.prank(address(0));
        mp.setDeviationLimit(1e16);

        vm.expectRevert();
        vm.prank(address(0));
        mp.setPriceAuthority(address(0));

        vm.expectRevert();
        vm.prank(address(0));
        mp.setTargetShareAuthority(address(0));
    }

    function test_SetPriceAndTargetShareSources() public {
        address alice = vm.addr(1);

        vm.expectRevert();
        vm.prank(alice);
        mpUpdateTargetShare(address(0), 10);

        vm.expectRevert();
        vm.prank(alice);
        mpUpdatePrice(address(0), 10);

        mpUpdateTargetShare(address(0), 10);
        mpUpdatePrice(address(0), 10);

        mp.setPriceAuthority(alice);
        mp.setTargetShareAuthority(alice);

        vm.prank(alice);
        mpUpdateTargetShare(address(0), 10);

        vm.prank(alice);
        mpUpdatePrice(address(0), 10);

        vm.expectRevert();
        mpUpdateTargetShare(address(0), 10);

        vm.expectRevert();
        mpUpdatePrice(address(0), 10);
    }

    function test_TogglePause() public {
        mpUpdateTargetShare(address(0), 10);
        mpUpdatePrice(address(0), 10);

        mp.togglePause();

        vm.expectRevert("MULTIPOOL: IP");
        mpUpdateTargetShare(address(0), 10);
        vm.expectRevert("MULTIPOOL: IP");
        mpUpdatePrice(address(0), 10);
    }

    function test_Decimals() public {
        MpAsset memory asset = MpAsset({
            quantity: 55e18,
            decimals: 24,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 0.0051875e18 - 0.0005e18,
            share: 50e18
        });
        assertEq(asset.to18(10e24), 10e18);
        assertEq(asset.toNative(10e18), 10e24);
        asset = MpAsset({
            quantity: 55e18,
            decimals: 6,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 0.0051875e18 - 0.0005e18,
            share: 50e18
        });
        assertEq(asset.to18(10e6), 10e18);
        assertEq(asset.toNative(10e18), 10e6);
    }
}
