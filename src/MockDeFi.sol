// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockDeFi {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    
    mapping(address => uint256) public principals;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public accruedYield;

    uint256 public constant DAILY_YIELD_BPS = 100; // 1% per day
    uint256 private constant BASIS_POINTS = 10000;

    error AmountZero();
    error InsufficientPrincipal();
    error TransferFailed();

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event YieldHarvested(address indexed user, uint256 amount);
    event YieldFunded(uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function fundYieldPool(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit YieldFunded(amount);
    }

    function _updateYield(address user) internal {
        uint256 timeElapsed = block.timestamp - lastUpdateTime[user];
        if (timeElapsed > 0 && principals[user] > 0) {
            uint256 newYield = (principals[user] * DAILY_YIELD_BPS * timeElapsed) / (1 days * BASIS_POINTS);
            accruedYield[user] += newYield;
        }
        lastUpdateTime[user] = block.timestamp;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert AmountZero();
        
        _updateYield(msg.sender);
        
        token.safeTransferFrom(msg.sender, address(this), amount);
        principals[msg.sender] += amount;
        
        emit Deposited(msg.sender, amount);
    }

    function harvest() external returns (uint256) {
        _updateYield(msg.sender);
        
        uint256 yieldToPay = accruedYield[msg.sender];
        if (yieldToPay == 0) return 0;

        uint256 balance = token.balanceOf(address(this));
        
        if (balance < yieldToPay) {
            yieldToPay = balance; 
        }
        
        accruedYield[msg.sender] = 0;
        token.safeTransfer(msg.sender, yieldToPay);
        
        emit YieldHarvested(msg.sender, yieldToPay);
        return yieldToPay;
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert AmountZero();
        
        _updateYield(msg.sender);
        
        if (principals[msg.sender] < amount) revert InsufficientPrincipal();
        
        principals[msg.sender] -= amount;
        token.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount);
    }

    function getPendingYield(address user) external view returns (uint256) {
        uint256 pending = accruedYield[user];
        if (principals[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime[user];
            uint256 newYield = (principals[user] * DAILY_YIELD_BPS * timeElapsed) / (1 days * BASIS_POINTS);
            pending += newYield;
        }
        return pending;
    }
}
