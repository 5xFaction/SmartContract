// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
}

contract Vault {
    IERC20 public immutable token;
    
    struct Deposit {
        uint256 amount;
        uint256 depositTime;
    }
    
    mapping(address => Deposit) public deposits;
    
    uint256 public constant DAILY_RATE = 100; // 1% = 100 basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_DAY = 86400;
    
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 principal, uint256 reward);
    
    constructor(address _token) {
        token = IERC20(_token);
    }
    
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        
        if (deposits[msg.sender].amount > 0) {
            _claimRewards();
        }
        
        token.transferFrom(msg.sender, address(this), amount);
        
        deposits[msg.sender].amount += amount;
        deposits[msg.sender].depositTime = block.timestamp;
        
        emit Deposited(msg.sender, amount);
    }
    
    function withdraw() external {
        Deposit memory userDeposit = deposits[msg.sender];
        require(userDeposit.amount > 0, "No deposit found");
        
        uint256 reward = calculateReward(msg.sender);
        uint256 principal = userDeposit.amount;
        
        delete deposits[msg.sender];
        
        token.transfer(msg.sender, principal);
        
        if (reward > 0) {
            token.mint(msg.sender, reward);
        }
        
        emit Withdrawn(msg.sender, principal, reward);
    }
    
    function claimRewards() external {
        require(deposits[msg.sender].amount > 0, "No deposit found");
        _claimRewards();
    }
    
    function _claimRewards() internal {
        uint256 reward = calculateReward(msg.sender);
        
        if (reward > 0) {
            deposits[msg.sender].depositTime = block.timestamp;
            token.mint(msg.sender, reward);
        }
    }
    
    function calculateReward(address user) public view returns (uint256) {
        Deposit memory userDeposit = deposits[user];
        if (userDeposit.amount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - userDeposit.depositTime;
        uint256 daysElapsed = timeElapsed / SECONDS_PER_DAY;
        
        // reward = principal * 1% * days
        uint256 reward = (userDeposit.amount * DAILY_RATE * daysElapsed) / BASIS_POINTS;
        
        return reward;
    }
    
    function getDeposit(address user) external view returns (uint256 amount, uint256 depositTime, uint256 pendingReward) {
        Deposit memory userDeposit = deposits[user];
        return (userDeposit.amount, userDeposit.depositTime, calculateReward(user));
    }
}
