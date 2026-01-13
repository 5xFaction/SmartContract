// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MockDeFi.sol";

contract FiveFaction is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Clan { NONE, SHADOW, BLADE, SPIRIT, PILLAR, WIND }
    
    struct UserDeposit {
        uint128 amount;
        uint64 epochJoined; 
        Clan clan; 
    }
    
    struct EpochResult {
        Clan winner;
        uint256 totalInk;
        uint256 winnerTVL;
        bool resolved;
    }
    
    IERC20 public immutable token;
    MockDeFi public immutable mockDeFi;
    
    uint256 public currentEpoch;
    uint256 public epochDuration;
    uint256 public epochStartTime;
    uint256 public constant DEPOSIT_PHASE_DURATION = 2 days;
    uint256 public constant MAX_CLAIM_LOOPS = 20; 
    
    uint256 public totalPrincipal;
    uint256 public rolloverInk; 

    mapping(Clan => uint256) public clanTVL;
    mapping(address => UserDeposit) public userDeposits;
    mapping(uint256 => EpochResult) public epochResults;
    mapping(address => mapping(uint256 => bool)) public hasClaimedInk;
    mapping(address => uint256) public clanLockedEpoch;

    // Custom Errors
    error InvalidClan();
    error AlreadyBound();
    error AmountZero();
    error JoinClanFirst();
    error NoStakeFound();
    error DeFiInsolvency();
    error CanvasCycleNotComplete();
    error EpochNotEnded();
    error AlreadyClaimed();
    error EpochNotResolved();
    error NotWinner();
    error JoinedAfterEpoch();
    error TransferFailed();
    error DepositPhaseClosed();
    error EpochLocked();
    error ClanLockedInEpoch();

    event ClanJoined(address indexed warrior, Clan clan);
    event InkStaked(address indexed warrior, Clan clan, uint256 amount, uint256 epoch);
    event InkWithdrawn(address indexed warrior, uint256 amount);
    event CanvasCleared(uint256 indexed epoch, Clan winner, uint256 totalGenereralYield, uint256 rollover);
    event EternalInkClaimed(address indexed warrior, uint256 epoch, uint256 ink);
    
    constructor(address _token, address _mockDeFi, uint256 _epochDuration) {
        token = IERC20(_token);
        mockDeFi = MockDeFi(_mockDeFi);
        epochDuration = _epochDuration; 
        currentEpoch = 1;
        epochStartTime = block.timestamp;

        token.approve(address(mockDeFi), type(uint256).max);
    }
    
    function _inDepositPhase() internal view returns (bool) {
        return block.timestamp < epochStartTime + DEPOSIT_PHASE_DURATION;
    }

    function joinClan(Clan clan) external {
        if (clan == Clan.NONE) revert InvalidClan();
        
        if (clanLockedEpoch[msg.sender] == currentEpoch) revert ClanLockedInEpoch();
        
        if (userDeposits[msg.sender].clan != Clan.NONE && userDeposits[msg.sender].amount > 0) revert AlreadyBound();
        
        userDeposits[msg.sender].clan = clan;
        clanLockedEpoch[msg.sender] = currentEpoch;
        
        emit ClanJoined(msg.sender, clan);
    }

    function _processPendingRewardsInternal(address user, uint256 limit) internal returns (bool) {
        UserDeposit memory dep = userDeposits[user];
        if (dep.amount == 0 || dep.clan == Clan.NONE) return true;
        
        uint256 start = dep.epochJoined;
        if (start == 0) start = 1; 
        
        uint256 processed = 0;
        bool done = true;
        
        for (uint256 i = start; i < currentEpoch; i++) {
            if (hasClaimedInk[user][i]) {
                continue;
            }

            if (processed >= limit) {
                done = false;
                break;
            }
            
            EpochResult memory res = epochResults[i];
            
            if (res.resolved && res.winner == dep.clan) {
                uint256 reward = (uint256(dep.amount) * res.totalInk) / res.winnerTVL;
                hasClaimedInk[user][i] = true;
                token.safeTransfer(user, reward);
                emit EternalInkClaimed(user, i, reward);
            } 
            
            processed++;
        }
        
        return done;
    }
    
    function processRewards(uint256 limit) external nonReentrant {
        _processPendingRewardsInternal(msg.sender, limit);
    }
    
    function stakeInk(uint128 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (!_inDepositPhase()) revert DepositPhaseClosed(); 
        
        bool done = _processPendingRewardsInternal(msg.sender, MAX_CLAIM_LOOPS);
        if (!done) {
            revert("Too many pending rewards. Claim manually first."); 
        }
        
        UserDeposit storage userDep = userDeposits[msg.sender];
        Clan clan = userDep.clan;
        if (clan == Clan.NONE) revert JoinClanFirst();
        
        token.safeTransferFrom(msg.sender, address(this), amount);
        mockDeFi.deposit(amount);

        userDep.epochJoined = uint64(currentEpoch);
        
        userDep.amount += amount;
        
        clanTVL[clan] += amount;
        totalPrincipal += amount;
        
        clanLockedEpoch[msg.sender] = currentEpoch;
        
        emit InkStaked(msg.sender, clan, amount, currentEpoch);
    }
    
    function withdrawInk(uint128 amount) external nonReentrant {
        if (!_inDepositPhase()) revert EpochLocked();
        
        bool done = _processPendingRewardsInternal(msg.sender, MAX_CLAIM_LOOPS);
        if (!done) {
             revert("Too many pending rewards. Claim manually first."); 
        }

        UserDeposit storage userDep = userDeposits[msg.sender];
        if (userDep.amount < amount) revert NoStakeFound();
        if (amount == 0) revert AmountZero();
        
        Clan clan = userDep.clan;
        
        mockDeFi.withdraw(amount);
        token.safeTransfer(msg.sender, amount);
        
        userDep.amount -= amount;
        clanTVL[clan] -= amount;
        totalPrincipal -= amount;
        
        emit InkWithdrawn(msg.sender, amount);
    }
    
    function clearCanvas() external nonReentrant {
        if (block.timestamp < epochStartTime + epochDuration) revert CanvasCycleNotComplete();
        
        uint256 yieldFromDeFi = mockDeFi.harvest();
        uint256 totalPot = yieldFromDeFi + rolloverInk;

        uint256[6] memory tvls;
        tvls[1] = clanTVL[Clan.SHADOW];
        tvls[2] = clanTVL[Clan.BLADE];
        tvls[3] = clanTVL[Clan.SPIRIT];
        tvls[4] = clanTVL[Clan.PILLAR];
        tvls[5] = clanTVL[Clan.WIND];

        if (totalPrincipal == 0) {
            rolloverInk = totalPot;
            epochResults[currentEpoch] = EpochResult({
                winner: Clan.NONE,
                totalInk: 0,
                winnerTVL: 0,
                resolved: true
            });
            emit CanvasCleared(currentEpoch, Clan.NONE, 0, rolloverInk);
            currentEpoch++;
            epochStartTime = block.timestamp;
            return;
        }

        Clan winner = Clan.NONE;
        int256 highestScore = type(int256).min;
        
        if (tvls[1] > 0) {
            int256 s = _calcScorePure(Clan.SHADOW, tvls);
            if (s > highestScore) { highestScore = s; winner = Clan.SHADOW; }
        }
        if (tvls[2] > 0) {
            int256 s = _calcScorePure(Clan.BLADE, tvls);
            if (s > highestScore) { highestScore = s; winner = Clan.BLADE; }
        }
        if (tvls[3] > 0) {
            int256 s = _calcScorePure(Clan.SPIRIT, tvls);
            if (s > highestScore) { highestScore = s; winner = Clan.SPIRIT; }
        }
        if (tvls[4] > 0) {
            int256 s = _calcScorePure(Clan.PILLAR, tvls);
            if (s > highestScore) { highestScore = s; winner = Clan.PILLAR; }
        }
        if (tvls[5] > 0) {
            int256 s = _calcScorePure(Clan.WIND, tvls);
            if (s > highestScore) { highestScore = s; winner = Clan.WIND; }
        }
        
        uint256 winnerSnapshotTVL = tvls[uint8(winner)];
        
        if (winner == Clan.NONE || winnerSnapshotTVL == 0) {
            rolloverInk = totalPot;
            winner = Clan.NONE;
            winnerSnapshotTVL = 0;
            totalPot = 0; 
        } else {
            rolloverInk = 0;
        }

        epochResults[currentEpoch] = EpochResult({
            winner: winner,
            totalInk: totalPot,
            winnerTVL: winnerSnapshotTVL,
            resolved: true
        });
        
        emit CanvasCleared(currentEpoch, winner, totalPot, rolloverInk);
        
        currentEpoch++;
        epochStartTime = block.timestamp;
    }

    function _calcScorePure(Clan clan, uint256[6] memory tvls) internal pure returns (int256) {
        (Clan t1, Clan t2) = _getTargets(clan);
        (Clan p1, Clan p2) = _getPredators(clan);
        
        uint256 targetTVL = tvls[uint8(t1)] + tvls[uint8(t2)];
        uint256 predatorTVL = 0;
        if (p1 != Clan.NONE) {
            predatorTVL = tvls[uint8(p1)] + tvls[uint8(p2)];
        }
        
        return int256(targetTVL) - int256(predatorTVL);
    }

    function _getTargets(Clan c) internal pure returns (Clan, Clan) {
        if (c == Clan.SHADOW) return (Clan.SPIRIT, Clan.WIND);
        if (c == Clan.BLADE) return (Clan.SHADOW, Clan.PILLAR);
        if (c == Clan.SPIRIT) return (Clan.BLADE, Clan.PILLAR);
        if (c == Clan.PILLAR) return (Clan.WIND, Clan.SHADOW);
        if (c == Clan.WIND) return (Clan.SPIRIT, Clan.BLADE);
        return (Clan.NONE, Clan.NONE);
    }

    function _getPredators(Clan c) internal pure returns (Clan, Clan) {
        if (c == Clan.SHADOW) return (Clan.BLADE, Clan.PILLAR);
        if (c == Clan.BLADE) return (Clan.SPIRIT, Clan.WIND);
        if (c == Clan.SPIRIT) return (Clan.WIND, Clan.SHADOW);
        if (c == Clan.PILLAR) return (Clan.BLADE, Clan.SPIRIT);
        if (c == Clan.WIND) return (Clan.PILLAR, Clan.SHADOW);
        return (Clan.NONE, Clan.NONE);
    }
    
    function calculateScore(Clan clan) public view returns (int256) {
        if (clan == Clan.NONE) revert InvalidClan();
        
        uint256[6] memory tvls;
        tvls[1] = clanTVL[Clan.SHADOW];
        tvls[2] = clanTVL[Clan.BLADE];
        tvls[3] = clanTVL[Clan.SPIRIT];
        tvls[4] = clanTVL[Clan.PILLAR];
        tvls[5] = clanTVL[Clan.WIND];
        
        return _calcScorePure(clan, tvls);
    }
    
    function getTotalTVL() public view returns (uint256) {
        return totalPrincipal;
    }
    
    function getAllClanTVLs() external view returns (uint256[5] memory) {
        return [
            clanTVL[Clan.SHADOW],
            clanTVL[Clan.BLADE],
            clanTVL[Clan.SPIRIT],
            clanTVL[Clan.PILLAR],
            clanTVL[Clan.WIND]
        ];
    }
    
    function getAllScores() external view returns (int256[5] memory) {
        uint256[6] memory tvls;
        tvls[1] = clanTVL[Clan.SHADOW];
        tvls[2] = clanTVL[Clan.BLADE];
        tvls[3] = clanTVL[Clan.SPIRIT];
        tvls[4] = clanTVL[Clan.PILLAR];
        tvls[5] = clanTVL[Clan.WIND];

        return [
            _calcScorePure(Clan.SHADOW, tvls),
            _calcScorePure(Clan.BLADE, tvls),
            _calcScorePure(Clan.SPIRIT, tvls),
            _calcScorePure(Clan.PILLAR, tvls),
            _calcScorePure(Clan.WIND, tvls)
        ];
    }
    
    function getTimeUntilCanvasClears() external view returns (uint256) {
        uint256 endTime = epochStartTime + epochDuration;
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }
    
    function getWarriorInfo(address warrior) external view returns (
        uint128 amount,
        Clan clan,
        uint64 epochJoined,
        int256 currentScore
    ) {
        UserDeposit memory dep = userDeposits[warrior];
        amount = dep.amount;
        clan = dep.clan;
        epochJoined = dep.epochJoined;
        
        if (clan != Clan.NONE) {
            currentScore = calculateScore(clan);
        } else {
            currentScore = 0;
        }
    }
    
    function getClanTargets(Clan clan) external pure returns (Clan, Clan) {
        return _getTargets(clan);
    }

    function getClanPredators(Clan clan) external pure returns (Clan, Clan) {
        return _getPredators(clan);
    }
}
