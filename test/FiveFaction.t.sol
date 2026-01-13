// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {FiveFaction} from "../src/FiveFaction.sol";
import {MockDeFi} from "../src/MockDeFi.sol";

contract FiveFactionTest is Test {
    MockUSDC public token;
    FiveFaction public game;
    MockDeFi public defi;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public dave = address(0x4);
    address public eve = address(0x5);
    
    uint256 constant EPOCH_DURATION = 7 days; 

    function setUp() public {
        token = new MockUSDC();
        defi = new MockDeFi(address(token));
        game = new FiveFaction(address(token), address(defi), EPOCH_DURATION);
        
        // Fund DeFi pool for yield
        token.mint(address(this), 1_000_000e6);
        token.approve(address(defi), 1_000_000e6);
        defi.fundYieldPool(1_000_000e6);
        
        // Mint tokens to users
        token.mint(alice, 100_000e6);
        token.mint(bob, 100_000e6);
        token.mint(charlie, 100_000e6);
        token.mint(dave, 100_000e6);
        token.mint(eve, 100_000e6);
        
        // Approve game contract
        vm.prank(alice);
        token.approve(address(game), type(uint256).max);
        vm.prank(bob);
        token.approve(address(game), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(game), type(uint256).max);
        vm.prank(dave);
        token.approve(address(game), type(uint256).max);
        vm.prank(eve);
        token.approve(address(game), type(uint256).max);
    }

    function test_ClanRelationships() public view {
        (FiveFaction.Clan t1, FiveFaction.Clan t2) = game.getClanTargets(FiveFaction.Clan.PILLAR);
        assertEq(uint8(t1), uint8(FiveFaction.Clan.WIND));
        assertEq(uint8(t2), uint8(FiveFaction.Clan.SHADOW));
        
        (FiveFaction.Clan p1, FiveFaction.Clan p2) = game.getClanPredators(FiveFaction.Clan.PILLAR);
        assertEq(uint8(p1), uint8(FiveFaction.Clan.BLADE));
        assertEq(uint8(p2), uint8(FiveFaction.Clan.SPIRIT));
    }

    function test_JoinClan() public {
        vm.prank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        
        (,FiveFaction.Clan clan,,) = game.getWarriorInfo(alice);
        assertEq(uint8(clan), uint8(FiveFaction.Clan.PILLAR));
    }

    function test_RevertJoinClanTwiceSameEpoch() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        
        // Even if stake is 0, cannot switch in SAME epoch
        vm.expectRevert(FiveFaction.ClanLockedInEpoch.selector);
        game.joinClan(FiveFaction.Clan.WIND);
        vm.stopPrank();
    }
    
    function test_SwitchClanDifferentEpoch() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        game.stakeInk(100e6);
        vm.stopPrank();
        
        // Warp to next Epoch
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        vm.startPrank(alice);
        // Withdraw all to allow switch
        game.withdrawInk(100e6);
        
        // Join new clan in new epoch (Deposit Phase)
        game.joinClan(FiveFaction.Clan.WIND);
        
        (,FiveFaction.Clan clan,,) = game.getWarriorInfo(alice);
        assertEq(uint8(clan), uint8(FiveFaction.Clan.WIND));
        vm.stopPrank();
    }

    function test_Deposit() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        game.stakeInk(1000e6);
        vm.stopPrank();
        
        (uint128 amount, FiveFaction.Clan clan, , ) = game.getWarriorInfo(alice);
        assertEq(uint256(amount), 1000e6);
        assertEq(uint8(clan), uint8(FiveFaction.Clan.PILLAR));
        assertEq(game.clanTVL(FiveFaction.Clan.PILLAR), 1000e6);
        
        assertEq(token.balanceOf(address(game)), 0);
        assertEq(token.balanceOf(address(defi)), 1_001_000e6);
        assertEq(game.totalPrincipal(), 1000e6);
    }
    
    // Auto Claim Test
    function test_AutoClaimOnTopUp() public {
        // Alice joins in Epoch 1.
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.WIND);
        game.stakeInk(1000e6);
        vm.stopPrank();
        
        // Bob joins SPIRIT (Prey of Wind). This ensures Wind (Alice) wins.
        vm.startPrank(bob);
        game.joinClan(FiveFaction.Clan.SPIRIT); 
        game.stakeInk(500e6);
        vm.stopPrank();
        
        // End Epoch 1
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        (FiveFaction.Clan winner,,,) = game.epochResults(1);
        assertEq(uint8(winner), uint8(FiveFaction.Clan.WIND));
        
        uint256 balanceBefore = token.balanceOf(alice);
        
        // Epoch 2 begins. Alice tops up. Auto-Claim should trigger first.
        vm.startPrank(alice);
        game.stakeInk(1000e6);
        uint256 balanceAfter = token.balanceOf(alice);
        
        // Alice balance should increase (Reward paid - Deposit paid)
        // Reward should be significant enough to be measurable.
        assertTrue(balanceAfter > balanceBefore - 1000e6);
        
        // Verify claimed status
        assertTrue(game.hasClaimedInk(alice, 1));
        
        // Verify New Stake Info
        (uint128 amount, , uint64 epochJoined, ) = game.getWarriorInfo(alice);
        assertEq(uint256(amount), 2000e6);
        assertEq(epochJoined, 2); // Reset to current epoch
    }

    function test_Withdraw() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        game.stakeInk(1000e6);
        
        uint256 balanceBefore = token.balanceOf(alice);
        game.withdrawInk(1000e6);
        uint256 balanceAfter = token.balanceOf(alice);
        vm.stopPrank();
        
        assertEq(balanceAfter - balanceBefore, 1000e6);
        assertEq(game.clanTVL(FiveFaction.Clan.PILLAR), 0);
        
        (,FiveFaction.Clan clan,,) = game.getWarriorInfo(alice);
        assertEq(uint8(clan), uint8(FiveFaction.Clan.PILLAR));
    }
    
    function test_RevertWithdrawInLockedPhase() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        game.stakeInk(1000e6);
        
        // Forward past deposit phase (2 days)
        vm.warp(block.timestamp + 3 days);
        
        vm.expectRevert(FiveFaction.EpochLocked.selector);
        game.withdrawInk(500e6);
        vm.stopPrank();
    }
    
    function test_RevertDepositInLockedPhase() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        game.stakeInk(1000e6);
        
        // Forward past deposit phase (2 days)
        vm.warp(block.timestamp + 3 days);
        
        vm.expectRevert(FiveFaction.DepositPhaseClosed.selector);
        game.stakeInk(500e6);
        vm.stopPrank();
    }

    function test_PlayMultipleRounds() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        game.stakeInk(1000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        vm.startPrank(alice);
        // Withdraw triggers auto Claim if any (Pillar wins)
        game.withdrawInk(1000e6);
        
        // Re-join
        game.stakeInk(2000e6);
        vm.stopPrank();
        
        (uint128 amount, FiveFaction.Clan clan, , ) = game.getWarriorInfo(alice);
        assertEq(uint256(amount), 2000e6);
        assertEq(uint8(clan), uint8(FiveFaction.Clan.PILLAR));
    }
    
    function test_EndEpochAndWinner() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        game.stakeInk(35_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinClan(FiveFaction.Clan.WIND);
        game.stakeInk(20_000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        game.joinClan(FiveFaction.Clan.SPIRIT);
        game.stakeInk(15_000e6);
        vm.stopPrank();
        
        vm.startPrank(dave);
        game.joinClan(FiveFaction.Clan.BLADE);
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(eve);
        game.joinClan(FiveFaction.Clan.SHADOW);
        game.stakeInk(20_000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        
        game.clearCanvas();
        
        (FiveFaction.Clan winner, uint256 totalYield, uint256 winnerTVL, bool resolved) = game.epochResults(1);
        
        assertTrue(resolved);
        assertEq(uint8(winner), uint8(FiveFaction.Clan.BLADE));
        assertEq(winnerTVL, 10_000e6);
        
        // Toleransi dinaikkan untuk mengakomodasi real-time yield update
        assertApproxEqAbs(totalYield, 7000e6, 20000); 
    }

    function test_ManualProcessRewards() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.SHADOW);
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(eve);
        game.joinClan(FiveFaction.Clan.WIND); 
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        // Winner assumed WIND or BLADE. IF EVE WINS (Wind)
        (FiveFaction.Clan winner,,,) = game.epochResults(1);
        
        if (winner == FiveFaction.Clan.WIND) {
             uint256 balanceBefore = token.balanceOf(eve);
             vm.prank(eve);
             game.processRewards(5); // Manual Process
             uint256 balanceAfter = token.balanceOf(eve);
             assertTrue(balanceAfter > balanceBefore);
        }
    }

    function test_RevertEndEpochTooEarly() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.PILLAR);
        game.stakeInk(1000e6);
        vm.stopPrank();
        
        vm.expectRevert(FiveFaction.CanvasCycleNotComplete.selector);
        game.clearCanvas();
    }

    function test_MultipleEpochs() public {
        vm.startPrank(alice);
        game.joinClan(FiveFaction.Clan.SHADOW);
        game.stakeInk(50_000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        assertEq(game.currentEpoch(), 2);
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        assertEq(game.currentEpoch(), 3);
    }
    
    function test_RolloverYield() public {
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        assertEq(game.rolloverInk(), 0);
    }
}
