# Neon Syndicate & Vault Protocols

This repository contains a collection of smart contracts implementing a gamified DeFi protocol (`NeonSyndicate`) and a standard yield vault (`Vault`), built using the Foundry framework.

## Contracts Overview

### 1. NeonSyndicate (Gamified DeFi)

**NeonSyndicate** is a unique "no-loss" gamified yield protocol where 5 factions compete for rewards based on Total Value Locked (TVL) relationships.

**Factions:**
*   **BRUTE**
*   **SNIPER**
*   **HACKER**
*   **SWARM**
*   **STEALTH**

**Game Mechanics:**
*   **Pentagon Cycle**: Each faction has 2 **Targets** (factions they beat) and 2 **Predators** (factions that beat them).
*   **Scoring**: `Score = (Target1 TVL + Target2 TVL) - (Predator1 TVL + Predator2 TVL)`
*   **Winning**: The faction with the highest score at the end of an epoch wins the total generated yield.
*   **Yield**: Rewards are distributed proportionally to depositors in the winning faction.
*   **No-Loss**: Losing factions keep their principal deposits and can try again in the next epoch.

**Relationships:**
| Faction | Beats (Targets) | Loses To (Predators) |
| :--- | :--- | :--- |
| **BRUTE** | SNIPER, HACKER | SWARM, STEALTH |
| **SNIPER** | SWARM, HACKER | BRUTE, STEALTH |
| **HACKER** | SWARM, STEALTH | BRUTE, SNIPER |
| **SWARM** | BRUTE, STEALTH | HACKER, SNIPER |
| **STEALTH** | SNIPER, BRUTE | HACKER, SWARM |

### 2. Vault (Simple Yield)

**Vault** is a straightforward staking contract.

*   **Logic**: Users deposit tokens and earn a fixed daily yield.
*   **Rate**: 1% per day (100 basis points).
*   **Rewards**: Rewards are minted (mock logic) upon withdrawal or claiming.

### 3. MockUSDC

**MockUSDC** is a production-ready mock USDC token built with OpenZeppelin standards for testing and development.

**Features:**
- ✅ **6 Decimals**: Matches real USDC precision
- ✅ **Permissionless Minting**: Anyone can mint tokens (perfect for testing)
- ✅ **ERC20Burnable**: Supports both `burn()` and `burnFrom()`
- ✅ **EIP-2612 Permit**: Gasless approvals using signatures
- ✅ **Batch Minting**: Mint to multiple addresses in one transaction
- ✅ **Event Emissions**: Full event tracking for all operations

**Key Functions:**
```solidity
// Mint tokens to any address
function mint(address to, uint256 amount) external

// Batch mint to multiple addresses
function batchMint(address[] calldata recipients, uint256[] calldata amounts) external

// Burn your own tokens
function burn(uint256 amount) external

// Burn approved tokens
function burnFrom(address account, uint256 amount) external

// Gasless approval via signature (EIP-2612)
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external
```

**Testing:**
- ✅ **27 comprehensive tests** - all passing
- ✅ **4 fuzz test suites** - 256 runs each
- ✅ **Integration tested** with SimpleVault contract
- ✅ **Full coverage** of edge cases and error scenarios

### 4. SimpleVault

**SimpleVault** is a demonstration contract showing real-world integration with MockUSDC.

**Features:**
- Deposit USDC tokens
- Withdraw USDC tokens
- Track individual user balances
- Uses SafeERC20 for secure transfers


## Getting Started

### Prerequisites

*   **Foundry**: You need to have Foundry installed.
    ```bash
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    ```

### Installation

Clone the repository and install dependencies:

```bash
git clone <repo-url>
cd SmartContract
forge install
```

### Build

Compile the contracts:

```bash
forge build
```

### Testing

Run the test suite to verify contract logic:

```bash
# Run all tests
forge test

# Run MockUSDC tests specifically with verbose output
forge test --match-contract MockUSDCTest -vvv

# Run with gas reporting
forge test --match-contract MockUSDCTest --gas-report

# Run fuzz tests with more iterations
forge test --match-contract MockUSDCTest --fuzz-runs 1000
```


## Deployment

Deployment scripts are located in the `script/` directory.

To deploy the **Vault**:
```bash
forge script script/Vault.s.sol:VaultScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

To deploy **MockUSDC**:
```bash
forge script script/MockUSDC.s.sol:MockUSDCScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

## License

UNLICENSED