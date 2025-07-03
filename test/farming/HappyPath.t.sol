// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {UserInfo, PoolInfo, FarmingMath} from "../../src/lib/Farm.sol";
import {Farm} from "../../src/farm/Farm.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";

contract MockMp is MockERC20 {

    uint availableRewards;
    constructor(string memory name, string memory symbol, uint _totalSupply) MockERC20(name, symbol, _totalSupply) {}

    
    function updateAvailableRewards(uint newRewards) external {
        availableRewards = newRewards;
    }

    function lpFeesBalance() external view returns (uint fee) {
        fee = availableRewards;
    }

    function claimLpFees(address to) external returns (uint fee) {
        fee = availableRewards;
        payable(to).transfer(fee);
        availableRewards = 0;
    }
}

contract FarmingTests is Test {
    Farm farm;
    MockERC20 protocolToken;
    MockMp mockMp;
    address bobby;
    address bobbysFriend;

    receive() external payable {}

    function setUp() public {
        (bobby,) = makeAddrAndKey("Bobby");
        (bobbysFriend,) = makeAddrAndKey("bobbysFriend");

        protocolToken = new MockERC20("protocolToken", "protocolToken", 0);
        mockMp = new MockMp("MP", "MP", 0);

        Farm impl = new Farm();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeWithSignature("initialize(address,address)", 
            address(this), address(protocolToken))
        );
        farm = Farm(payable(address(proxy)));

        protocolToken.mint(address(this), 100e18);
        mockMp.mint(address(this), 100e18);
    }

    function updateRewards(uint amount) internal {
        vm.deal(address(mockMp), amount);
        mockMp.updateAvailableRewards(amount);
    }

    function test_FarmingHappyPath() public {
        vm.expectRevert("ERC20: insufficient allowance");
        farm.updateDistribution(address(mockMp), 100e18, 1590);

        protocolToken.approve(address(farm), 10e18);

        farm.updateDistribution(address(mockMp), 10e18, 1590);

        vm.expectRevert("ERC20: insufficient allowance");
        farm.deposit(address(mockMp), 1e18);

        updateRewards(1e18);

        assertEq(mockMp.balanceOf(address(this)), 100e18);

        mockMp.approve(address(farm), 1e18);
        farm.deposit(address(mockMp), 1e18);

        assertEq(mockMp.balanceOf(address(this)), 99e18);

        uint bn = vm.getBlockNumber();

        vm.roll(bn + 1000);
        uint balanceBefore = address(this).balance;

        assertEq(protocolToken.balanceOf(address(this)), 90e18);

        farm.deposit(address(mockMp), 0);

        // TODO previous rewards are not distributed, because you farm only from the moment of deposit
        assertEq(address(this).balance, balanceBefore);
        assertEq(protocolToken.balanceOf(address(this)), 90e18 + 1590 * 1000);

        updateRewards(1e18);

        vm.roll(bn + 1000 + 1);

        farm.deposit(address(mockMp), 0);

        assertEq(address(this).balance, balanceBefore + 1e18);
        assertEq(protocolToken.balanceOf(address(this)), 90e18 + 1590 * 1001);

        assertEq(address(bobby).balance, 0);
        assertEq(protocolToken.balanceOf(bobby), 0);

        vm.prank(bobby);
        farm.deposit(address(mockMp), 0);
        
        // no dep no rewards
        assertEq(address(bobby).balance, 0);
        assertEq(protocolToken.balanceOf(bobby), 0);

        vm.roll(bn + 1000 + 1 + 1000);

        // underflow
        vm.expectRevert();
        farm.withdraw(address(mockMp), 1e18 + 1);

        farm.withdraw(address(mockMp), 1e18);
        assertEq(mockMp.balanceOf(address(this)), 100e18);
        assertEq(protocolToken.balanceOf(address(this)), 90e18 + 1590 * 2001);
    }


    function test_FarmingWaitWithNoDistribution() public {
        uint bn = vm.getBlockNumber();

        mockMp.approve(address(farm), 1e18);
        
        vm.expectRevert("Address: call to non-contract"); // call transferFrom to zero address
        farm.deposit(address(mockMp), 1e18);

        farm.updateDistribution(address(mockMp), 0, 0);

        uint balanceBefore = address(this).balance;

        farm.deposit(address(mockMp), 1e18);

        vm.roll(bn + 1000);

        farm.deposit(address(mockMp), 0);

        assertEq(address(this).balance, balanceBefore);
        assertEq(mockMp.balanceOf(address(this)), 99e18);
        assertEq(protocolToken.balanceOf(address(this)), 100e18);

        updateRewards(1e3);

        vm.roll(bn + 1000);

        farm.deposit(address(mockMp), 0);

        assertEq(address(this).balance, balanceBefore + 1e3);
        assertEq(mockMp.balanceOf(address(this)), 99e18);
        assertEq(protocolToken.balanceOf(address(this)), 100e18);


        protocolToken.approve(address(farm), 1e18);
        farm.updateDistribution(address(mockMp), 1e18, 10);

        vm.roll(bn + 1000 + 1000);

        farm.deposit(address(mockMp), 0);

        assertEq(address(this).balance, balanceBefore + 1e3);
        assertEq(mockMp.balanceOf(address(this)), 99e18);
        assertEq(protocolToken.balanceOf(address(this)), 99e18 + 1000 * 10);

    }

    function test_UpdateDistributionWithInsufficientBalance() public {
        vm.expectRevert("ERC20: insufficient allowance"); 
        farm.updateDistribution(address(mockMp), 1e18, 10);

        vm.expectRevert();  // underflow
        farm.updateDistribution(address(mockMp), -1e18, 10);

    }

    function test_CheckMultipleDistrubutionUpdatesWork() public {
        protocolToken.approve(address(farm), 10e18);
        farm.updateDistribution(address(mockMp), 10e18, 10);

        mockMp.approve(address(farm), 1e18);
        farm.deposit(address(mockMp), 1e18);

        uint bn = vm.getBlockNumber();

        vm.roll(bn + 1000);

        farm.updateDistribution(address(mockMp), 0, 13);

        vm.roll(bn + 1000 + 1510);

        farm.deposit(address(mockMp), 0);

        assertEq(protocolToken.balanceOf(address(this)), 90e18 + 1000 * 10 + 1510 * 13);
    }

    function test_MultipleDepositorsWithSameDeps() public {
        uint bn = vm.getBlockNumber();

        protocolToken.approve(address(farm), 10e18);
        farm.updateDistribution(address(mockMp), 10e18, 899);

        vm.roll(bn + 150);

        updateRewards(1e6);

        mockMp.mint(bobby, 10e18);
        vm.prank(bobby);
        mockMp.approve(address(farm), 10e18);
        vm.prank(bobby);
        farm.deposit(address(mockMp), 10e18);

        vm.roll(bn + 150 + 150);

        updateRewards(1e6);

        mockMp.mint(bobbysFriend, 10e18);
        vm.prank(bobbysFriend);
        mockMp.approve(address(farm), 10e18);
        vm.prank(bobbysFriend);
        farm.deposit(address(mockMp), 10e18);

        vm.roll(bn + 150 + 150 + 150);

        updateRewards(1e6);

        mockMp.approve(address(farm), 10e18);
        farm.deposit(address(mockMp), 10e18);

        vm.roll(bn + 150 + 150 + 150 + 150);
        updateRewards(1e6);
        
        vm.prank(bobbysFriend);
        farm.deposit(address(mockMp), 0);
        vm.prank(bobby);
        farm.deposit(address(mockMp), 0);

        uint balanceBefore = address(this).balance;
        farm.deposit(address(mockMp), 0);

        // total 3e6
        // sum = 2 999 999
        assertEq(address(this).balance, balanceBefore); // third 1e6 / 3
        assertEq(address(bobby).balance, 1e6); // first 1e6 + 1e6/2 + 1e6/3
        assertEq(address(bobbysFriend).balance, 666666); // second 1e6 + 1e6/2

        // totalDistributed = 899 * 450 = 404550
        // ~404 532
        assertEq(protocolToken.balanceOf(address(this)), 90e18 + 30645);
        assertEq(protocolToken.balanceOf(bobby), 275460);
        assertEq(protocolToken.balanceOf(bobbysFriend), 98427);
    }

    

    function test_MultipleDepositorsWithDifferentDeps() public {
        uint bn = vm.getBlockNumber();

        protocolToken.approve(address(farm), 10e18);
        farm.updateDistribution(address(mockMp), 10e18, 899);

        vm.roll(bn + 150);

        updateRewards(1e6);

        mockMp.mint(bobby, 10e18);
        vm.prank(bobby);
        mockMp.approve(address(farm), 10e18);
        vm.prank(bobby);
        farm.deposit(address(mockMp), 10e18);

        vm.roll(bn + 150 + 150);

        updateRewards(1e6);

        mockMp.mint(bobbysFriend, 7e18);
        vm.prank(bobbysFriend);
        mockMp.approve(address(farm), 7e18);
        vm.prank(bobbysFriend);
        farm.deposit(address(mockMp), 7e18);

        vm.roll(bn + 150 + 150 + 150);

        updateRewards(1e6);

        mockMp.approve(address(farm), 5e18);
        farm.deposit(address(mockMp), 5e18);

        vm.roll(bn + 150 + 150 + 150 + 150);
        updateRewards(1e6);
        
        vm.prank(bobbysFriend);
        farm.deposit(address(mockMp), 0);
        vm.prank(bobby);
        farm.deposit(address(mockMp), 0);

        uint balanceBefore = address(this).balance;
        farm.deposit(address(mockMp), 0);

        // total 3e6
        // sum = 2 999 999
        assertEq(address(this).balance, balanceBefore + 681818);
        assertEq(address(bobby).balance, 1363636); // first 1e6 + 1e6/2 + 1e6/3
        assertEq(address(bobbysFriend).balance, 954545);

        // totalDistributed = 899 * 450 = 404550
        // ~404 532
        assertEq(protocolToken.balanceOf(address(this)), 90e18 + 30645);
        assertEq(protocolToken.balanceOf(bobby), 275460);
        assertEq(protocolToken.balanceOf(bobbysFriend), 98427);
    }

}
