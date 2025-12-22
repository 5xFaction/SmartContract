// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {KaliYuga} from "../src/KaliYuga.sol";

contract KaliYugaTest is Test {
    MockUSDC public token;
    KaliYuga public game;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public dave = address(0x4);
    address public eve = address(0x5);
    
    uint256 constant EPOCH_DURATION = 1 days;
    uint256 constant YIELD_RATE = 100; // 1% per day

    function setUp() public {
        token = new MockUSDC();
        game = new KaliYuga(address(token), EPOCH_DURATION, YIELD_RATE);
        
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
        // PILLAR targets WIND, SHADOW
        KaliYuga.Clan[2] memory pillarTargets = game.getClanTargets(KaliYuga.Clan.PILLAR);
        assertEq(uint8(pillarTargets[0]), uint8(KaliYuga.Clan.WIND));
        assertEq(uint8(pillarTargets[1]), uint8(KaliYuga.Clan.SHADOW));
        
        // PILLAR predators BLADE, SPIRIT
        KaliYuga.Clan[2] memory pillarPredators = game.getClanPredators(KaliYuga.Clan.PILLAR);
        assertEq(uint8(pillarPredators[0]), uint8(KaliYuga.Clan.BLADE));
        assertEq(uint8(pillarPredators[1]), uint8(KaliYuga.Clan.SPIRIT));
    }

    function test_JoinClan() public {
        vm.prank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        
        assertEq(uint8(game.userClan(alice)), uint8(KaliYuga.Clan.PILLAR));
    }

    function test_RevertJoinClanTwice() public {
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        
        vm.expectRevert("Already bound to a clan");
        game.joinClan(KaliYuga.Clan.WIND);
        vm.stopPrank();
    }

    function test_Deposit() public {
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(1000e6);
        vm.stopPrank();
        
        (uint256 amount, KaliYuga.Clan clan, , ) = game.getWarriorInfo(alice);
        assertEq(amount, 1000e6);
        assertEq(uint8(clan), uint8(KaliYuga.Clan.PILLAR));
        assertEq(game.clanTVL(KaliYuga.Clan.PILLAR), 1000e6);
    }

    function test_DepositMultipleTimes() public {
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(1000e6);
        game.stakeInk(500e6);
        vm.stopPrank();
        
        (uint256 amount, , , ) = game.getWarriorInfo(alice);
        assertEq(amount, 1500e6);
        assertEq(game.clanTVL(KaliYuga.Clan.PILLAR), 1500e6);
    }

    function test_RevertDepositWithoutJoining() public {
        vm.prank(alice);
        vm.expectRevert("Join a clan first");
        game.stakeInk(1000e6);
    }

    function test_Withdraw() public {
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(1000e6);
        
        uint256 balanceBefore = token.balanceOf(alice);
        game.withdrawInk();
        uint256 balanceAfter = token.balanceOf(alice);
        vm.stopPrank();
        
        assertEq(balanceAfter - balanceBefore, 1000e6);
        assertEq(game.clanTVL(KaliYuga.Clan.PILLAR), 0);
        
        // Clan should still be set after withdrawInk
        assertEq(uint8(game.userClan(alice)), uint8(KaliYuga.Clan.PILLAR));
    }

    function test_PlayMultipleRounds() public {
        // Round 1
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(1000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        // Withdraw after round 1
        vm.prank(alice);
        game.withdrawInk();
        
        // Round 2 - stakeInk again (same clan, can't change)
        vm.prank(alice);
        game.stakeInk(2000e6);
        
        (uint256 amount, KaliYuga.Clan clan, , ) = game.getWarriorInfo(alice);
        assertEq(amount, 2000e6);
        assertEq(uint8(clan), uint8(KaliYuga.Clan.PILLAR));
    }

    function test_ScoreCalculation() public {
        // Setup: Simulate the example from the document
        // Brute: 35%, Sniper: 20%, Hacker: 15%, Swarm: 10%, Stealth: 20%
        
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(35_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinClan(KaliYuga.Clan.WIND);
        game.stakeInk(20_000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        game.joinClan(KaliYuga.Clan.SPIRIT);
        game.stakeInk(15_000e6);
        vm.stopPrank();
        
        vm.startPrank(dave);
        game.joinClan(KaliYuga.Clan.BLADE);
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(eve);
        game.joinClan(KaliYuga.Clan.SHADOW);
        game.stakeInk(20_000e6);
        vm.stopPrank();
        
        // PILLAR score = (WIND + SHADOW) - (BLADE + SPIRIT) = (20k + 20k) - (10k + 15k) = 40k - 25k = +15k
        int256 pillarScore = game.calculateScore(KaliYuga.Clan.PILLAR);
        assertEq(pillarScore, 15_000e6);
        
        // BLADE score = (SHADOW + PILLAR) - (SPIRIT + WIND) = (20k + 35k) - (15k + 20k) = 55k - 35k = +20k
        int256 bladeScore = game.calculateScore(KaliYuga.Clan.BLADE);
        assertEq(bladeScore, 20_000e6);
        
        // BLADE should have highest score (+20k)
        int256[5] memory allScores = game.getAllScores();
        int256 maxScore = type(int256).min;
        uint8 winnerIdx = 0;
        for (uint8 i = 0; i < 5; i++) {
            if (allScores[i] > maxScore) {
                maxScore = allScores[i];
                winnerIdx = i;
            }
        }
        assertEq(winnerIdx, 1); // BLADE is index 1 (SHADOW=0, BLADE=1, SPIRIT=2, PILLAR=3, WIND=4)
    }

    function test_EndEpochAndWinner() public {
        // Same setup as score test
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(35_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinClan(KaliYuga.Clan.WIND);
        game.stakeInk(20_000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        game.joinClan(KaliYuga.Clan.SPIRIT);
        game.stakeInk(15_000e6);
        vm.stopPrank();
        
        vm.startPrank(dave);
        game.joinClan(KaliYuga.Clan.BLADE);
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(eve);
        game.joinClan(KaliYuga.Clan.SHADOW);
        game.stakeInk(20_000e6);
        vm.stopPrank();
        
        // Fast forward past epoch
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        
        // End epoch
        game.clearCanvas();
        
        // Check result
        (KaliYuga.Clan winner, uint256 totalYield, uint256 winnerTVL, bool resolved) = game.epochResults(1);
        
        assertTrue(resolved);
        assertEq(uint8(winner), uint8(KaliYuga.Clan.BLADE));
        assertEq(winnerTVL, 10_000e6);
        
        // Total yield = 100k * 1% = 1000 USDC
        assertEq(totalYield, 1000e6);
    }

    function test_ClaimReward() public {
        // Setup - Make SHADOW win by setting higher predator TVL for others
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.SHADOW);
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinClan(KaliYuga.Clan.SHADOW);
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        game.joinClan(KaliYuga.Clan.BLADE);  // BLADE is predator to SHADOW
        game.stakeInk(40_000e6);
        vm.stopPrank();
        
        vm.startPrank(dave);
        game.joinClan(KaliYuga.Clan.SPIRIT); // SPIRIT is target of SHADOW
        game.stakeInk(30_000e6);
        vm.stopPrank();
        
        vm.startPrank(eve);
        game.joinClan(KaliYuga.Clan.WIND); // WIND is target of SHADOW
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        // SHADOW score = (SPIRIT + WIND) - (BLADE + PILLAR) = (30k + 10k) - (40k + 0) = 0k
        // BLADE score = (SHADOW + PILLAR) - (SPIRIT + WIND) = (20k + 0) - (30k + 10k) = -20k
        // SPIRIT score = (BLADE + PILLAR) - (WIND + SHADOW) = (40k + 0) - (10k + 20k) = +10k
        // WIND score = (SPIRIT + BLADE) - (PILLAR + SHADOW) = (30k + 40k) - (0 + 20k) = +50k
        // WIND wins with highest score!
        
        // End epoch
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        // Eve claims reward (WIND clan member)
        uint256 balanceBefore = token.balanceOf(eve);
        vm.prank(eve);
        game.claimEternalInk(1);
        uint256 balanceAfter = token.balanceOf(eve);
        
        // Total TVL = 100k, yield = 1k
        // WIND TVL = 10k, Eve has 10k (100% of WIND)
        // Eve reward = 1k * 100% = 1000 USDC
        assertEq(balanceAfter - balanceBefore, 1000e6);
    }

    function test_RevertClaimIfNotWinner() public {
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.SHADOW);
        game.stakeInk(50_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(50_000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        // PILLAR wins (beats SHADOW by targeting it)
        // Alice (SHADOW) tries to claim
        vm.prank(alice);
        vm.expectRevert("Your clan didn't win");
        game.claimEternalInk(1);
    }

    function test_RevertEndEpochTooEarly() public {
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(1000e6);
        vm.stopPrank();
        
        vm.expectRevert("Canvas cycle not complete");
        game.clearCanvas();
    }

    function test_MultipleEpochs() public {
        // Epoch 1
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.SHADOW);
        game.stakeInk(50_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(50_000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        assertEq(game.currentEpoch(), 2);
        
        // Epoch 2
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        game.clearCanvas();
        
        assertEq(game.currentEpoch(), 3);
    }

    function test_GetAllClanTVLs() public {
        vm.startPrank(alice);
        game.joinClan(KaliYuga.Clan.PILLAR);
        game.stakeInk(10_000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        game.joinClan(KaliYuga.Clan.WIND);
        game.stakeInk(20_000e6);
        vm.stopPrank();
        
        uint256[5] memory tvls = game.getAllClanTVLs();
        assertEq(tvls[0], 0);        // SHADOW
        assertEq(tvls[1], 0);        // BLADE
        assertEq(tvls[2], 0);        // SPIRIT
        assertEq(tvls[3], 10_000e6); // PILLAR
        assertEq(tvls[4], 20_000e6); // WIND
    }
}
