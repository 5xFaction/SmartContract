// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title NeonSyndicate
 * @notice A gamified DeFi protocol where 5 factions compete for yield
 * 
 * GAME MECHANICS:
 * - 5 Factions: BRUTE, SNIPER, HACKER, SWARM, STEALTH
 * - Each faction has 2 TARGETS (factions they beat) and 2 PREDATORS (factions that beat them)
 * - Score = (Target1 TVL + Target2 TVL) - (Predator1 TVL + Predator2 TVL)
 * - Highest score wins all the yield for that epoch
 * - Losers keep their principal (no-loss mechanism)
 * 
 * FACTION RELATIONSHIPS (Pentagon cycle):
 * BRUTE    -> beats SNIPER, HACKER    | loses to SWARM, STEALTH
 * SNIPER   -> beats SWARM, HACKER     | loses to BRUTE, STEALTH  
 * HACKER   -> beats SWARM, STEALTH    | loses to BRUTE, SNIPER
 * SWARM    -> beats BRUTE, STEALTH    | loses to HACKER, SNIPER
 * STEALTH  -> beats SNIPER, BRUTE     | loses to HACKER, SWARM
 */
contract NeonSyndicate {
    // ============ ENUMS ============
    enum Faction { NONE, BRUTE, SNIPER, HACKER, SWARM, STEALTH }
    
    // ============ STRUCTS ============
    struct UserDeposit {
        uint256 amount;
        Faction faction;
        uint256 epochJoined;
    }
    
    struct EpochResult {
        Faction winner;
        uint256 totalYield;
        uint256 winnerTVL;
        bool resolved;
    }
    
    // ============ STATE VARIABLES ============
    address public immutable token;        // MockUSDC address
    address public admin;
    
    uint256 public currentEpoch;
    uint256 public epochDuration;          // Duration in seconds (e.g., 1 day = 86400)
    uint256 public epochStartTime;
    uint256 public yieldRatePerDay;        // Yield rate in basis points (100 = 1%)
    
    // Faction TVL for current epoch
    mapping(Faction => uint256) public factionTVL;
    
    // User deposits
    mapping(address => UserDeposit) public userDeposits;
    
    // Historical epoch results
    mapping(uint256 => EpochResult) public epochResults;
    
    // Track if user claimed for specific epoch
    mapping(address => mapping(uint256 => bool)) public hasClaimed;
    
    // User's permanent faction (once chosen, cannot change)
    mapping(address => Faction) public userFaction;
    
    // Faction relationships: faction => [target1, target2]
    mapping(Faction => Faction[2]) public targets;
    // Faction relationships: faction => [predator1, predator2]
    mapping(Faction => Faction[2]) public predators;
    
    // ============ EVENTS ============
    event FactionJoined(address indexed user, Faction faction);
    event Deposited(address indexed user, Faction faction, uint256 amount, uint256 epoch);
    event Withdrawn(address indexed user, uint256 amount);
    event EpochEnded(uint256 indexed epoch, Faction winner, uint256 totalYield);
    event RewardClaimed(address indexed user, uint256 epoch, uint256 reward);
    
    // ============ CONSTRUCTOR ============
    constructor(address _token, uint256 _epochDuration, uint256 _yieldRatePerDay) {
        token = _token;
        admin = msg.sender;
        epochDuration = _epochDuration;
        yieldRatePerDay = _yieldRatePerDay;
        currentEpoch = 1;
        epochStartTime = block.timestamp;
        
        _initializeFactionRelationships();
    }
    
    /**
     * @notice Initialize the pentagon relationships between factions
     * Based on the game design document
     */
    function _initializeFactionRelationships() internal {
        // BRUTE beats SNIPER, HACKER | loses to SWARM, STEALTH
        targets[Faction.BRUTE] = [Faction.SNIPER, Faction.HACKER];
        predators[Faction.BRUTE] = [Faction.SWARM, Faction.STEALTH];
        
        // SNIPER beats SWARM, HACKER | loses to BRUTE, STEALTH
        targets[Faction.SNIPER] = [Faction.SWARM, Faction.HACKER];
        predators[Faction.SNIPER] = [Faction.BRUTE, Faction.STEALTH];
        
        // HACKER beats SWARM, STEALTH | loses to BRUTE, SNIPER
        targets[Faction.HACKER] = [Faction.SWARM, Faction.STEALTH];
        predators[Faction.HACKER] = [Faction.BRUTE, Faction.SNIPER];
        
        // SWARM beats BRUTE, STEALTH | loses to HACKER, SNIPER
        targets[Faction.SWARM] = [Faction.BRUTE, Faction.STEALTH];
        predators[Faction.SWARM] = [Faction.HACKER, Faction.SNIPER];
        
        // STEALTH beats SNIPER, BRUTE | loses to HACKER, SWARM
        targets[Faction.STEALTH] = [Faction.SNIPER, Faction.BRUTE];
        predators[Faction.STEALTH] = [Faction.HACKER, Faction.SWARM];
    }
    
    // ============ USER FUNCTIONS ============
    
    /**
     * @notice Join a faction permanently (can only be done once per address)
     * @param faction The faction to join (1-5)
     */
    function joinFaction(Faction faction) external {
        require(faction != Faction.NONE, "Invalid faction");
        require(userFaction[msg.sender] == Faction.NONE, "Already joined a faction");
        
        userFaction[msg.sender] = faction;
        
        emit FactionJoined(msg.sender, faction);
    }
    
    /**
     * @notice Deposit USDC to play in current epoch
     * Must have joined a faction first. Can deposit multiple times (adds to existing).
     * @param amount Amount of USDC to deposit
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        Faction faction = userFaction[msg.sender];
        require(faction != Faction.NONE, "Join a faction first");
        
        // Transfer tokens from user
        _transferFrom(msg.sender, address(this), amount);
        
        // Update or create deposit
        UserDeposit storage userDep = userDeposits[msg.sender];
        
        if (userDep.amount == 0) {
            // First deposit this round
            userDep.faction = faction;
            userDep.epochJoined = currentEpoch;
        }
        
        userDep.amount += amount;
        
        // Add to faction TVL
        factionTVL[faction] += amount;
        
        emit Deposited(msg.sender, faction, amount, currentEpoch);
    }
    
    /**
     * @notice Withdraw principal (can do anytime)
     * Note: If you withdraw mid-epoch, you forfeit that epoch's potential rewards
     * After withdraw, you can deposit again to play next round (same faction)
     */
    function withdraw() external {
        UserDeposit memory userDep = userDeposits[msg.sender];
        require(userDep.amount > 0, "No deposit found");
        
        uint256 amount = userDep.amount;
        Faction faction = userDep.faction;
        
        // Remove from faction TVL
        factionTVL[faction] -= amount;
        
        // Clear user deposit (but NOT their faction - they keep that forever)
        delete userDeposits[msg.sender];
        
        // Transfer principal back
        _transfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount);
    }
    
    // ============ EPOCH MANAGEMENT ============
    
    /**
     * @notice End the current epoch and determine winner
     * Can be called by anyone after epoch duration has passed
     */
    function endEpoch() external {
        require(block.timestamp >= epochStartTime + epochDuration, "Epoch not ended yet");
        
        // Calculate total TVL and yield
        uint256 totalTVL = getTotalTVL();
        uint256 totalYield = (totalTVL * yieldRatePerDay) / 10000;
        
        // Calculate scores and find winner
        Faction winner = Faction.NONE;
        int256 highestScore = type(int256).min;
        
        for (uint8 i = 1; i <= 5; i++) {
            Faction f = Faction(i);
            if (factionTVL[f] > 0) {
                int256 score = calculateScore(f);
                if (score > highestScore) {
                    highestScore = score;
                    winner = f;
                }
            }
        }
        
        // Store epoch result
        epochResults[currentEpoch] = EpochResult({
            winner: winner,
            totalYield: totalYield,
            winnerTVL: factionTVL[winner],
            resolved: true
        });
        
        emit EpochEnded(currentEpoch, winner, totalYield);
        
        // Start new epoch
        currentEpoch++;
        epochStartTime = block.timestamp;
    }
    
    /**
     * @notice Calculate score for a faction
     * Score = (Target1 TVL + Target2 TVL) - (Predator1 TVL + Predator2 TVL)
     */
    function calculateScore(Faction faction) public view returns (int256) {
        require(faction != Faction.NONE, "Invalid faction");
        
        Faction[2] memory factionTargets = targets[faction];
        Faction[2] memory factionPredators = predators[faction];
        
        uint256 targetTVL = factionTVL[factionTargets[0]] + factionTVL[factionTargets[1]];
        uint256 predatorTVL = factionPredators[0] != Faction.NONE ? 
            factionTVL[factionPredators[0]] + factionTVL[factionPredators[1]] : 0;
        
        return int256(targetTVL) - int256(predatorTVL);
    }
    
    /**
     * @notice Claim rewards for a past epoch (if your faction won)
     * @param epoch The epoch to claim rewards for
     */
    function claimReward(uint256 epoch) external {
        require(epoch < currentEpoch, "Epoch not ended");
        require(!hasClaimed[msg.sender][epoch], "Already claimed");
        
        EpochResult memory result = epochResults[epoch];
        require(result.resolved, "Epoch not resolved");
        
        UserDeposit memory userDep = userDeposits[msg.sender];
        require(userDep.amount > 0, "No deposit");
        require(userDep.faction == result.winner, "Your faction didn't win");
        require(userDep.epochJoined <= epoch, "Joined after epoch started");
        
        // Calculate user's share of the yield
        // reward = (userAmount / winnerTVL) * totalYield
        uint256 reward = (userDep.amount * result.totalYield) / result.winnerTVL;
        
        hasClaimed[msg.sender][epoch] = true;
        
        // Mint reward tokens (since this is mock yield)
        _mint(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, epoch, reward);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getTotalTVL() public view returns (uint256) {
        return factionTVL[Faction.BRUTE] + 
               factionTVL[Faction.SNIPER] + 
               factionTVL[Faction.HACKER] + 
               factionTVL[Faction.SWARM] + 
               factionTVL[Faction.STEALTH];
    }
    
    function getAllFactionTVLs() external view returns (uint256[5] memory) {
        return [
            factionTVL[Faction.BRUTE],
            factionTVL[Faction.SNIPER],
            factionTVL[Faction.HACKER],
            factionTVL[Faction.SWARM],
            factionTVL[Faction.STEALTH]
        ];
    }
    
    function getAllScores() external view returns (int256[5] memory) {
        return [
            calculateScore(Faction.BRUTE),
            calculateScore(Faction.SNIPER),
            calculateScore(Faction.HACKER),
            calculateScore(Faction.SWARM),
            calculateScore(Faction.STEALTH)
        ];
    }
    
    function getTimeUntilEpochEnd() external view returns (uint256) {
        uint256 endTime = epochStartTime + epochDuration;
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }
    
    function getUserInfo(address user) external view returns (
        uint256 amount,
        Faction faction,
        uint256 epochJoined,
        int256 currentScore
    ) {
        UserDeposit memory dep = userDeposits[user];
        amount = dep.amount;
        faction = dep.faction;
        epochJoined = dep.epochJoined;
        currentScore = faction != Faction.NONE ? calculateScore(faction) : int256(0);
    }
    
    function getFactionTargets(Faction faction) external view returns (Faction[2] memory) {
        return targets[faction];
    }
    
    function getFactionPredators(Faction faction) external view returns (Faction[2] memory) {
        return predators[faction];
    }
    
    // ============ INTERNAL TOKEN FUNCTIONS ============
    // These interact with MockUSDC
    
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
