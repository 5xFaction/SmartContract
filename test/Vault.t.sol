// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {Vault} from "../src/Vault.sol";

contract VaultTest is Test {
    MockUSDC public token;
    Vault public vault;
    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        token = new MockUSDC();
        vault = new Vault(address(token));
    }

    function test_Deposit() public {
        token.mint(alice, 1000e6);
        
        vm.startPrank(alice);
        token.approve(address(vault), 1000e6);
        vault.deposit(1000e6);
        vm.stopPrank();
        
        (uint256 amount, , ) = vault.getDeposit(alice);
        assertEq(amount, 1000e6);
        assertEq(token.balanceOf(address(vault)), 1000e6);
    }

    function test_RewardAfterOneDay() public {
        token.mint(alice, 1000e6);
        
        vm.startPrank(alice);
        token.approve(address(vault), 1000e6);
        vault.deposit(1000e6);
        vm.stopPrank();
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);
        
        uint256 reward = vault.calculateReward(alice);
        assertEq(reward, 10e6); // 1% of 1000 = 10
    }

    function test_RewardAfterMultipleDays() public {
        token.mint(alice, 1000e6);
        
        vm.startPrank(alice);
        token.approve(address(vault), 1000e6);
        vault.deposit(1000e6);
        vm.stopPrank();
        
        // Fast forward 5 days
        vm.warp(block.timestamp + 5 days);
        
        uint256 reward = vault.calculateReward(alice);
        assertEq(reward, 50e6); // 5% of 1000 = 50
    }

    function test_Withdraw() public {
        token.mint(alice, 1000e6);
        
        vm.startPrank(alice);
        token.approve(address(vault), 1000e6);
        vault.deposit(1000e6);
        vm.stopPrank();
        
        // Fast forward 3 days
        vm.warp(block.timestamp + 3 days);
        
        vm.prank(alice);
        vault.withdraw();
        
        // Alice should have principal + 3% reward
        assertEq(token.balanceOf(alice), 1030e6);
        
        (uint256 amount, , ) = vault.getDeposit(alice);
        assertEq(amount, 0);
    }

    function test_ClaimRewards() public {
        token.mint(alice, 1000e6);
        
        vm.startPrank(alice);
        token.approve(address(vault), 1000e6);
        vault.deposit(1000e6);
        vm.stopPrank();
        
        // Fast forward 2 days
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(alice);
        vault.claimRewards();
        
        // Alice should have 2% reward, deposit still in vault
        assertEq(token.balanceOf(alice), 20e6);
        
        (uint256 amount, , ) = vault.getDeposit(alice);
        assertEq(amount, 1000e6);
    }

    function test_NoRewardBeforeOneDay() public {
        token.mint(alice, 1000e6);
        
        vm.startPrank(alice);
        token.approve(address(vault), 1000e6);
        vault.deposit(1000e6);
        vm.stopPrank();
        
        // Fast forward 12 hours (less than 1 day)
        vm.warp(block.timestamp + 12 hours);
        
        uint256 reward = vault.calculateReward(alice);
        assertEq(reward, 0);
    }

    function test_MultipleDeposits() public {
        token.mint(alice, 2000e6);
        
        vm.startPrank(alice);
        token.approve(address(vault), 2000e6);
        vault.deposit(1000e6);
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);
        
        // Deposit more (should claim previous rewards)
        vault.deposit(500e6);
        vm.stopPrank();
        
        // Alice should have received 10 MUSDC reward
        assertEq(token.balanceOf(alice), 510e6); // 2000 - 1000 - 500 + 10 reward
        
        (uint256 amount, , ) = vault.getDeposit(alice);
        assertEq(amount, 1500e6);
    }

    function test_RevertDepositZero() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be greater than 0");
        vault.deposit(0);
    }

    function test_RevertWithdrawNoDeposit() public {
        vm.prank(alice);
        vm.expectRevert("No deposit found");
        vault.withdraw();
    }

    function testFuzz_Deposit(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        
        token.mint(alice, amount);
        
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
        
        (uint256 depositedAmount, , ) = vault.getDeposit(alice);
        assertEq(depositedAmount, amount);
    }
}
