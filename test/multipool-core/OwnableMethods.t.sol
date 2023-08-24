pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import { Multipool, MpContext, MpAsset } from "../../src/multipool/Multipool.sol";

contract MultipoolSingleAssetTest is Test {
    Multipool mp;

    function setUp() public {
        mp = new Multipool('Name', 'SYMBOL');
    }

    function mpUpdateTargetShare(address token, uint share) internal {
       address[] memory t = new address[](1);
       t[0] = address(token);

       uint[] memory s = new uint[](1);
       s[0] = share;
        mp.updateTargetShares(t,s);
    }

    function mpUpdatePrice(address token, uint price) internal {
       address[] memory t = new address[](1);
       t[0] = address(token);

       uint[] memory p = new uint[](1);
       p[0] = price;
        mp.updatePrices(t,p);
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

}
