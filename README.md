# FiveFaction Smart Contracts

## Contracts Overview

| Contract Name | Address | Description                                                           |
| ------------- | ------- | --------------------------------------------------------------------- |
| FiveFaction   | `TBD`   | Core game logic, epoch management, and staking system.                |
| MockUSDC      | `TBD`   | ERC20 Stablecoin used for staking and rewards.                        |
| MockDeFi      | `TBD`   | Yield generator simulating external DeFi protocol (Zero-Loss source). |

## Core Functions Scope

### FiveFaction.sol

| Function Name                   | Visibility | Description                                                                                                           |
| ------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------- |
| `joinClan(Clan clan)`           | External   | Binds user to a Clan. Requires active Deposit Phase. resetting clan is allowed if stake is 0.                         |
| `stakeInk(uint128 amount)`      | External   | Deposits tokens into the game. Auto-claims pending rewards first. Locks funds in DeFi protocol.                       |
| `withdrawInk(uint128 amount)`   | External   | Withdraws tokens principal. Auto-claims pending rewards first. Only allowed during Deposit Phase.                     |
| `processRewards(uint256 limit)` | External   | Manually processes pending rewards for users with long inactivity history (batch processing).                         |
| `clearCanvas()`                 | External   | Finalizes the current epoch. Calculates winner based on Prey/Predator logic, distributes yield, and rolls over epoch. |
| `getWarriorInfo(address)`       | View       | Returns user's current stake, clan, joined epoch, and current potential score.                                        |
| `getAllClanTVLs()`              | View       | Returns total value locked for all 5 clans.                                                                           |

## Deployment Guide

### Prerequisites

- Foundry (forge) installed
- Ethereum Wallet Private Key
- RPC URL (Base Sepolia / Optimism Goerli recommended)

### 1. Environment Setup

Create a `.env` file in the root directory:

```bash
PRIVATE_KEY=your_private_key_here
RPC_URL=your_rpc_url_here
ETHERSCAN_API_KEY=your_etherscan_key_here
```

### 2. Build Contracts

```bash
forge build
```

### 3. Run Tests

Ensure all logic invariants pass before deployment.

```bash
forge test
```

### 4. Deploy to Network

Run the deployment script which handles MockUSDC, MockDeFi, and FiveFaction linking.

```bash
source .env
```

```bash
forge script script/FiveFaction.s.sol:FiveFactionScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### Security Invariants (Audit Note)

1. **Historical Integrity:** Users cannot change their stake without first settling all pending rewards from previous epochs (Auto-Claim enforced).
2. **Epoch Locking:** Principal withdrawals and Clan switching are strictly prohibited outside the Deposit Phase (first 2 days of Epoch).
3. **Gas Safety:** Reward processing iterates only over unclaimed epochs and enforces a loop limit to prevent Denial of Service.
