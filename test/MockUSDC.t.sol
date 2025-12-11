// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC public token;
    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        token = new MockUSDC();
    }

    function test_TokenMetadata() public view {
        assertEq(token.name(), "Mock USDC");
        assertEq(token.symbol(), "MUSDC");
        assertEq(token.decimals(), 6);
    }

    function test_Mint() public {
        token.mint(alice, 1000e6);
        assertEq(token.balanceOf(alice), 1000e6);
        assertEq(token.totalSupply(), 1000e6);
    }

    function test_AnyoneCanMint() public {
        vm.prank(alice);
        token.mint(alice, 500e6);
        assertEq(token.balanceOf(alice), 500e6);

        vm.prank(bob);
        token.mint(bob, 300e6);
        assertEq(token.balanceOf(bob), 300e6);
    }

    function test_Burn() public {
        token.mint(alice, 1000e6);
        
        vm.prank(alice);
        token.burn(400e6);
        
        assertEq(token.balanceOf(alice), 600e6);
        assertEq(token.totalSupply(), 600e6);
    }

    function test_Transfer() public {
        token.mint(alice, 1000e6);
        
        vm.prank(alice);
        token.transfer(bob, 300e6);
        
        assertEq(token.balanceOf(alice), 700e6);
        assertEq(token.balanceOf(bob), 300e6);
    }

    function test_Approve() public {
        vm.prank(alice);
        token.approve(bob, 500e6);
        
        assertEq(token.allowance(alice, bob), 500e6);
    }

    function test_TransferFrom() public {
        token.mint(alice, 1000e6);
        
        vm.prank(alice);
        token.approve(bob, 500e6);
        
        vm.prank(bob);
        token.transferFrom(alice, bob, 300e6);
        
        assertEq(token.balanceOf(alice), 700e6);
        assertEq(token.balanceOf(bob), 300e6);
        assertEq(token.allowance(alice, bob), 200e6);
    }

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        token.mint(to, amount);
        assertEq(token.balanceOf(to), amount);
    }

    function test_RevertBurnInsufficientBalance() public {
        token.mint(alice, 100e6);
        
        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        token.burn(200e6);
    }

    function test_RevertTransferInsufficientBalance() public {
        token.mint(alice, 100e6);
        
        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        token.transfer(bob, 200e6);
    }
}
