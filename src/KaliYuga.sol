// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title KaliYuga - The Last Ink
 * @notice A gamified DeFi protocol where 5 clans compete for the Eternal Ink
 * 
 * 🎨 THEME: Mythology-Futuristic (Heavy Ink Style)
 * 
 * LORE:
 * The world has reached the end of times (Kali Yuga) where light has vanished.
 * Only the "Eternal Ink" remains as the source of power. Five clans fight to
 * claim the remnants of existence in an arena called "The White Canvas".
 * 
 * GAME MECHANICS:
 * - 5 Clans: SHADOW, BLADE, SPIRIT, PILLAR, WIND
 * - Each clan has 2 TARGETS (clans they beat) and 2 PREDATORS (clans that beat them)
 * - Score = (Target1 TVL + Target2 TVL) - (Predator1 TVL + Predator2 TVL)
 * - Highest score wins all the Eternal Ink for that epoch
 * - Losers keep their principal (no-loss mechanism)
 * 
 * CLAN RELATIONSHIPS (Pentagon Cycle):
 * SHADOW (影)   -> beats SPIRIT, WIND     | loses to BLADE, PILLAR    (Shadow traps spirits, approaches archers but can't escape blades or hard bodies)
 * BLADE (剣)    -> beats SHADOW, PILLAR   | loses to SPIRIT, WIND     (Sharp sword cuts shadows, pierces armor but can't slash spirits or dodge arrows)
 * SPIRIT (霊)   -> beats BLADE, PILLAR    | loses to WIND, SHADOW     (Spirits can't be cut, penetrate defense but dispersed by wind, trapped by shadows)
 * PILLAR (柱)   -> beats WIND, SHADOW     | loses to BLADE, SPIRIT    (Hard body immune to arrows, traps shadows but pierced by blades, penetrated by spirits)
 * WIND (風)     -> beats SPIRIT, BLADE    | loses to PILLAR, SHADOW   (Wind disperses spirits, attacks from afar but useless against hard bodies, outmaneuvered by shadows)
 */
contract KaliYuga {
    // ============ ENUMS ============
    enum Clan { NONE, SHADOW, BLADE, SPIRIT, PILLAR, WIND }
    
    // ============ STRUCTS ============
    struct UserDeposit {
        uint256 amount;
        Clan clan;
        uint256 epochJoined;
    }
    
    struct EpochResult {
        Clan winner;
        uint256 totalInk;          // Total Eternal Ink (yield) for this epoch
        uint256 winnerTVL;
        bool resolved;
    }
    
    // ============ STATE VARIABLES ============
    address public immutable token;        // MockUSDC address (represents Eternal Ink)
    address public admin;
    
    uint256 public currentEpoch;
    uint256 public epochDuration;          // Duration in seconds (e.g., 1 day = 86400)
    uint256 public epochStartTime;
    uint256 public inkRatePerDay;          // Ink generation rate in basis points (100 = 1%)
    
    // Clan TVL for current epoch (Total Value Locked on The White Canvas)
    mapping(Clan => uint256) public clanTVL;
    
    // User deposits
    mapping(address => UserDeposit) public userDeposits;
    
    // Historical epoch results (The Canvas History)
    mapping(uint256 => EpochResult) public epochResults;
    
    // Track if user claimed Eternal Ink for specific epoch
    mapping(address => mapping(uint256 => bool)) public hasClaimedInk;
    
    // User's permanent clan (once chosen, bound by fate)
    mapping(address => Clan) public userClan;
    
    // Clan relationships: clan => [target1, target2]
    mapping(Clan => Clan[2]) public targets;
    // Clan relationships: clan => [predator1, predator2]
    mapping(Clan => Clan[2]) public predators;
    
    // ============ EVENTS ============
    event ClanJoined(address indexed warrior, Clan clan);
    event InkStaked(address indexed warrior, Clan clan, uint256 amount, uint256 epoch);
    event InkWithdrawn(address indexed warrior, uint256 amount);
    event CanvasCleared(uint256 indexed epoch, Clan winner, uint256 totalInk);
    event EternalInkClaimed(address indexed warrior, uint256 epoch, uint256 ink);
    
    // ============ CONSTRUCTOR ============
    constructor(address _token, uint256 _epochDuration, uint256 _inkRatePerDay) {
        token = _token;
        admin = msg.sender;
        epochDuration = _epochDuration;
        inkRatePerDay = _inkRatePerDay;
        currentEpoch = 1;
        epochStartTime = block.timestamp;
        
        _initializeClanRelationships();
    }
    
    /**
     * @notice Initialize the pentagon relationships between clans
     * Based on the Kali-Yuga prophecy
     */
    function _initializeClanRelationships() internal {
        // SHADOW (Kage) beats SPIRIT, WIND | loses to BLADE, PILLAR
        // Shadow traps spirits and approaches archers, but can't escape sharp blades or hard bodies
        targets[Clan.SHADOW] = [Clan.SPIRIT, Clan.WIND];
        predators[Clan.SHADOW] = [Clan.BLADE, Clan.PILLAR];
        
        // BLADE (Steel) beats SHADOW, PILLAR | loses to SPIRIT, WIND
        // Sharp sword cuts shadows and pierces armor, but can't slash spirits or dodge arrows from afar
        targets[Clan.BLADE] = [Clan.SHADOW, Clan.PILLAR];
        predators[Clan.BLADE] = [Clan.SPIRIT, Clan.WIND];
        
        // SPIRIT (Ghost) beats BLADE, PILLAR | loses to WIND, SHADOW
        // Spirits can't be cut by swords and penetrate physical defense, but wind disperses them and shadows trap them
        targets[Clan.SPIRIT] = [Clan.BLADE, Clan.PILLAR];
        predators[Clan.SPIRIT] = [Clan.WIND, Clan.SHADOW];
        
        // PILLAR (Monk) beats WIND, SHADOW | loses to BLADE, SPIRIT
        // Hard body immune to arrows and traps shadows, but sharp blades pierce armor and spirits penetrate defense
        targets[Clan.PILLAR] = [Clan.WIND, Clan.SHADOW];
        predators[Clan.PILLAR] = [Clan.BLADE, Clan.SPIRIT];
        
        // WIND (Arrow) beats SPIRIT, BLADE | loses to PILLAR, SHADOW
        // Wind disperses spirits and attacks swordsmen from distance, but useless against hard bodies and outmaneuvered by shadows
        targets[Clan.WIND] = [Clan.SPIRIT, Clan.BLADE];
        predators[Clan.WIND] = [Clan.PILLAR, Clan.SHADOW];
    }
    
    // ============ WARRIOR FUNCTIONS ============
    
    /**
     * @notice Join a clan permanently (can only be done once per address)
     * Your fate is sealed once you choose your path
     * @param clan The clan to join (1-5)
     */
    function joinClan(Clan clan) external {
        require(clan != Clan.NONE, "Invalid clan");
        require(userClan[msg.sender] == Clan.NONE, "Already bound to a clan");
        
        userClan[msg.sender] = clan;
        
        emit ClanJoined(msg.sender, clan);
    }
    
    /**
     * @notice Stake your Eternal Ink to fight on The White Canvas
     * Must have joined a clan first. Can stake multiple times (adds to existing).
     * @param amount Amount of Eternal Ink to stake
     */
    function stakeInk(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        Clan clan = userClan[msg.sender];
        require(clan != Clan.NONE, "Join a clan first");
        
        // Transfer Eternal Ink from warrior
        _transferFrom(msg.sender, address(this), amount);
        
        // Update or create stake
        UserDeposit storage userDep = userDeposits[msg.sender];
        
        if (userDep.amount == 0) {
            // First stake this epoch
            userDep.clan = clan;
            userDep.epochJoined = currentEpoch;
        }
        
        userDep.amount += amount;
        
        // Add to clan TVL on The White Canvas
        clanTVL[clan] += amount;
        
        emit InkStaked(msg.sender, clan, amount, currentEpoch);
    }
    
    /**
     * @notice Withdraw your principal Eternal Ink (can do anytime)
     * Note: If you withdraw mid-epoch, you forfeit that epoch's potential rewards
     * After withdraw, you can stake again to fight in the next epoch (same clan, bound by fate)
     */
    function withdrawInk() external {
        UserDeposit memory userDep = userDeposits[msg.sender];
        require(userDep.amount > 0, "No stake found");
        
        uint256 amount = userDep.amount;
        Clan clan = userDep.clan;
        
        // Remove from clan TVL
        clanTVL[clan] -= amount;
        
        // Clear user deposit (but NOT their clan - fate cannot be changed)
        delete userDeposits[msg.sender];
        
        // Transfer principal Eternal Ink back
        _transfer(msg.sender, amount);
        
        emit InkWithdrawn(msg.sender, amount);
    }
    
    // ============ EPOCH MANAGEMENT (Canvas Cycles) ============
    
    /**
     * @notice End the current epoch and determine which clan claimed The White Canvas
     * Can be called by anyone after epoch duration has passed
     */
    function clearCanvas() external {
        require(block.timestamp >= epochStartTime + epochDuration, "Canvas cycle not complete");
        
        // Calculate total TVL and generated Eternal Ink
        uint256 totalTVL = getTotalTVL();
        uint256 totalInk = (totalTVL * inkRatePerDay) / 10000;
        
        // Calculate scores and find the dominant clan
        Clan winner = Clan.NONE;
        int256 highestScore = type(int256).min;
        
        for (uint8 i = 1; i <= 5; i++) {
            Clan c = Clan(i);
            if (clanTVL[c] > 0) {
                int256 score = calculateScore(c);
                if (score > highestScore) {
                    highestScore = score;
                    winner = c;
                }
            }
        }
        
        // Record this epoch in The Canvas History
        epochResults[currentEpoch] = EpochResult({
            winner: winner,
            totalInk: totalInk,
            winnerTVL: clanTVL[winner],
            resolved: true
        });
        
        emit CanvasCleared(currentEpoch, winner, totalInk);
        
        // Begin new epoch - The Canvas is reborn
        currentEpoch++;
        epochStartTime = block.timestamp;
    }
    
    /**
     * @notice Calculate dominance score for a clan
     * Score = (Target1 TVL + Target2 TVL) - (Predator1 TVL + Predator2 TVL)
     * Higher score means the clan has dominated their targets while keeping predators at bay
     */
    function calculateScore(Clan clan) public view returns (int256) {
        require(clan != Clan.NONE, "Invalid clan");
        
        Clan[2] memory clanTargets = targets[clan];
        Clan[2] memory clanPredators = predators[clan];
        
        uint256 targetTVL = clanTVL[clanTargets[0]] + clanTVL[clanTargets[1]];
        uint256 predatorTVL = clanPredators[0] != Clan.NONE ? 
            clanTVL[clanPredators[0]] + clanTVL[clanPredators[1]] : 0;
        
        return int256(targetTVL) - int256(predatorTVL);
    }
    
    /**
     * @notice Claim your share of Eternal Ink for a past epoch (if your clan won)
     * @param epoch The epoch to claim Eternal Ink for
     */
    function claimEternalInk(uint256 epoch) external {
        require(epoch < currentEpoch, "Epoch not ended");
        require(!hasClaimedInk[msg.sender][epoch], "Already claimed");
        
        EpochResult memory result = epochResults[epoch];
        require(result.resolved, "Epoch not resolved");
        
        UserDeposit memory userDep = userDeposits[msg.sender];
        require(userDep.amount > 0, "No stake");
        require(userDep.clan == result.winner, "Your clan didn't win");
        require(userDep.epochJoined <= epoch, "Joined after epoch started");
        
        // Calculate warrior's share of the Eternal Ink
        // reward = (userAmount / winnerTVL) * totalInk
        uint256 reward = (userDep.amount * result.totalInk) / result.winnerTVL;
        
        hasClaimedInk[msg.sender][epoch] = true;
        
        // Grant Eternal Ink to the victorious warrior (mint reward tokens)
        _mint(msg.sender, reward);
        
        emit EternalInkClaimed(msg.sender, epoch, reward);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getTotalTVL() public view returns (uint256) {
        return clanTVL[Clan.SHADOW] + 
               clanTVL[Clan.BLADE] + 
               clanTVL[Clan.SPIRIT] + 
               clanTVL[Clan.PILLAR] + 
               clanTVL[Clan.WIND];
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
        return [
            calculateScore(Clan.SHADOW),
            calculateScore(Clan.BLADE),
            calculateScore(Clan.SPIRIT),
            calculateScore(Clan.PILLAR),
            calculateScore(Clan.WIND)
        ];
    }
    
    function getTimeUntilCanvasClears() external view returns (uint256) {
        uint256 endTime = epochStartTime + epochDuration;
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }
    
    function getWarriorInfo(address warrior) external view returns (
        uint256 amount,
        Clan clan,
        uint256 epochJoined,
        int256 currentScore
    ) {
        UserDeposit memory dep = userDeposits[warrior];
        amount = dep.amount;
        clan = dep.clan;
        epochJoined = dep.epochJoined;
        currentScore = clan != Clan.NONE ? calculateScore(clan) : int256(0);
    }
    
    function getClanTargets(Clan clan) external view returns (Clan[2] memory) {
        return targets[clan];
    }
    
    function getClanPredators(Clan clan) external view returns (Clan[2] memory) {
        return predators[clan];
    }
    
    // ============ INTERNAL TOKEN FUNCTIONS ============
    // These interact with MockUSDC (Eternal Ink)
    
    function _transferFrom(address from, address to, uint256 amount) internal {
        (bool success, ) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        require(success, "Transfer failed");
    }
    
    function _transfer(address to, uint256 amount) internal {
        (bool success, ) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success, "Transfer failed");
    }
    
    function _mint(address to, uint256 amount) internal {
        (bool success, ) = token.call(
            abi.encodeWithSignature("mint(address,uint256)", to, amount)
        );
        require(success, "Mint failed");
    }
}
