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
        mp.updateTargetShare(address(0), 10);

        vm.expectRevert();
        vm.prank(alice);
        mp.updatePrice(address(0), 10);

        mp.updateTargetShare(address(0), 10);
        mp.updatePrice(address(0), 10);

        mp.setPriceAuthority(alice);
        mp.setTargetShareAuthority(alice);

        vm.prank(alice);
        mp.updateTargetShare(address(0), 10);

        vm.prank(alice);
        mp.updatePrice(address(0), 10);

        vm.expectRevert();
        mp.updateTargetShare(address(0), 10);

        vm.expectRevert();
        mp.updatePrice(address(0), 10);
    }

}
