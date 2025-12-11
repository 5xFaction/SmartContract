// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {NeonSyndicate} from "../src/NeonSyndicate.sol";

contract NeonSyndicateTest is Test {
    MockUSDC public token;
    NeonSyndicate public game;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public dave = address(0x4);
    address public eve = address(0x5);
    
    uint256 constant EPOCH_DURATION = 1 days;
    uint256 constant YIELD_RATE = 100; // 1% per day

    function setUp() public {
        token = new MockUSDC();
        game = new NeonSyndicate(address(token), EPOCH_DURATION, YIELD_RATE);
        
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

    function test_FactionRelationships() public view {
        // BRUTE targets SNIPER, HACKER
        NeonSyndicate.Faction[2] memory bruteTargets = game.getFactionTargets(NeonSyndicate.Faction.BRUTE);
        assertEq(uint8(bruteTargets[0]), uint8(NeonSyndicate.Faction.SNIPER));
        assertEq(uint8(bruteTargets[1]), uint8(NeonSyndicate.Faction.HACKER));
        
        // BRUTE predators SWARM, STEALTH
        NeonSyndicate.Faction[2] memory brutePredators = game.getFactionPredators(NeonSyndicate.Faction.BRUTE);
        assertEq(uint8(brutePredators[0]), uint8(NeonSyndicate.Faction.SWARM));
        assertEq(uint8(brutePredators[1]), uint8(NeonSyndicate.Faction.STEALTH));
    }

    function test_JoinFaction() public {
        vm.prank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        
        assertEq(uint8(game.userFaction(alice)), uint8(NeonSyndicate.Faction.BRUTE));
    }

    function test_RevertJoinFactionTwice() public {
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        
        vm.expectRevert("Already joined a faction");
        game.joinFaction(NeonSyndicate.Faction.SNIPER);
        vm.stopPrank();
    }

    function test_Deposit() public {
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(1000e6);
        vm.stopPrank();
        
        (uint256 amount, NeonSyndicate.Faction faction, , ) = game.getUserInfo(alice);
        assertEq(amount, 1000e6);
        assertEq(uint8(faction), uint8(NeonSyndicate.Faction.BRUTE));
        assertEq(game.factionTVL(NeonSyndicate.Faction.BRUTE), 1000e6);
    }

    function test_DepositMultipleTimes() public {
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(1000e6);
        game.deposit(500e6);
        vm.stopPrank();
        
        (uint256 amount, , , ) = game.getUserInfo(alice);
        assertEq(amount, 1500e6);
        assertEq(game.factionTVL(NeonSyndicate.Faction.BRUTE), 1500e6);
    }

    function test_RevertDepositWithoutJoining() public {
        vm.prank(alice);
        vm.expectRevert("Join a faction first");
        game.deposit(1000e6);
    }

    function test_Withdraw() public {
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(1000e6);
        
        uint256 balanceBefore = token.balanceOf(alice);
        game.withdraw();
        uint256 balanceAfter = token.balanceOf(alice);
        vm.stopPrank();
        
        assertEq(balanceAfter - balanceBefore, 1000e6);
        assertEq(game.factionTVL(NeonSyndicate.Faction.BRUTE), 0);
        
        // Faction should still be set after withdraw
        assertEq(uint8(game.userFaction(alice)), uint8(NeonSyndicate.Faction.BRUTE));
    }

    function test_PlayMultipleRounds() public {
        // Round 1
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(1000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.endEpoch();
        
        // Withdraw after round 1
        vm.prank(alice);
        game.withdraw();
        
        // Round 2 - deposit again (same faction, can't change)
        vm.prank(alice);
        game.deposit(2000e6);
        
        (uint256 amount, NeonSyndicate.Faction faction, , ) = game.getUserInfo(alice);
        assertEq(amount, 2000e6);
        assertEq(uint8(faction), uint8(NeonSyndicate.Faction.BRUTE));
    }

    function test_ScoreCalculation() public {
        // Setup: Simulate the example from the document
        // Brute: 35%, Sniper: 20%, Hacker: 15%, Swarm: 10%, Stealth: 20%
        
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(35_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinFaction(NeonSyndicate.Faction.SNIPER);
        game.deposit(20_000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        game.joinFaction(NeonSyndicate.Faction.HACKER);
        game.deposit(15_000e6);
        vm.stopPrank();
        
        vm.startPrank(dave);
        game.joinFaction(NeonSyndicate.Faction.SWARM);
        game.deposit(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(eve);
        game.joinFaction(NeonSyndicate.Faction.STEALTH);
        game.deposit(20_000e6);
        vm.stopPrank();
        
        // BRUTE score = (SNIPER + HACKER) - (SWARM + STEALTH) = (20k + 15k) - (10k + 20k) = 35k - 30k = +5k
        int256 bruteScore = game.calculateScore(NeonSyndicate.Faction.BRUTE);
        assertEq(bruteScore, 5_000e6);
        
        // STEALTH score = (SNIPER + BRUTE) - (HACKER + SWARM) = (20k + 35k) - (15k + 10k) = 55k - 25k = +30k
        int256 stealthScore = game.calculateScore(NeonSyndicate.Faction.STEALTH);
        assertEq(stealthScore, 30_000e6);
        
        // STEALTH should have highest score (winner in the document example)
        int256[5] memory allScores = game.getAllScores();
        int256 maxScore = type(int256).min;
        uint8 winnerIdx = 0;
        for (uint8 i = 0; i < 5; i++) {
            if (allScores[i] > maxScore) {
                maxScore = allScores[i];
                winnerIdx = i;
            }
        }
        assertEq(winnerIdx, 4); // STEALTH is index 4 (BRUTE=0, SNIPER=1, HACKER=2, SWARM=3, STEALTH=4)
    }

    function test_EndEpochAndWinner() public {
        // Same setup as score test
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(35_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinFaction(NeonSyndicate.Faction.SNIPER);
        game.deposit(20_000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        game.joinFaction(NeonSyndicate.Faction.HACKER);
        game.deposit(15_000e6);
        vm.stopPrank();
        
        vm.startPrank(dave);
        game.joinFaction(NeonSyndicate.Faction.SWARM);
        game.deposit(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(eve);
        game.joinFaction(NeonSyndicate.Faction.STEALTH);
        game.deposit(20_000e6);
        vm.stopPrank();
        
        // Fast forward past epoch
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        
        // End epoch
        game.endEpoch();
        
        // Check result
        (NeonSyndicate.Faction winner, uint256 totalYield, uint256 winnerTVL, bool resolved) = game.epochResults(1);
        
        assertTrue(resolved);
        assertEq(uint8(winner), uint8(NeonSyndicate.Faction.STEALTH));
        assertEq(winnerTVL, 20_000e6);
        
        // Total yield = 100k * 1% = 1000 USDC
        assertEq(totalYield, 1000e6);
    }

    function test_ClaimReward() public {
        // Setup
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.STEALTH);
        game.deposit(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinFaction(NeonSyndicate.Faction.STEALTH);
        game.deposit(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(80_000e6);
        vm.stopPrank();
        
        // End epoch
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.endEpoch();
        
        // Alice claims reward
        uint256 balanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        game.claimReward(1);
        uint256 balanceAfter = token.balanceOf(alice);
        
        // Total TVL = 100k, yield = 1k
        // STEALTH TVL = 20k, Alice has 10k (50% of STEALTH)
        // Alice reward = 1k * 50% = 500 USDC
        assertEq(balanceAfter - balanceBefore, 500e6);
    }

    function test_RevertClaimIfNotWinner() public {
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(50_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinFaction(NeonSyndicate.Faction.STEALTH);
        game.deposit(50_000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.endEpoch();
        
        // STEALTH wins (beats BRUTE)
        // Alice (BRUTE) tries to claim
        vm.prank(alice);
        vm.expectRevert("Your faction didn't win");
        game.claimReward(1);
    }

    function test_RevertEndEpochTooEarly() public {
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(1000e6);
        vm.stopPrank();
        
        vm.expectRevert("Epoch not ended yet");
        game.endEpoch();
    }

    function test_MultipleEpochs() public {
        // Epoch 1
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.STEALTH);
        game.deposit(50_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(50_000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.endEpoch();
        
        assertEq(game.currentEpoch(), 2);
        
        // Epoch 2
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.endEpoch();
        
        assertEq(game.currentEpoch(), 3);
    }

    function test_GetAllFactionTVLs() public {
        vm.startPrank(alice);
        game.joinFaction(NeonSyndicate.Faction.BRUTE);
        game.deposit(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinFaction(NeonSyndicate.Faction.SNIPER);
        game.deposit(20_000e6);
        vm.stopPrank();
        
        uint256[5] memory tvls = game.getAllFactionTVLs();
        assertEq(tvls[0], 10_000e6); // BRUTE
        assertEq(tvls[1], 20_000e6); // SNIPER
        assertEq(tvls[2], 0);        // HACKER
        assertEq(tvls[3], 0);        // SWARM
        assertEq(tvls[4], 0);        // STEALTH
    }
}
