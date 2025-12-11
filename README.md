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

A standard ERC20 token (`MUSDC`) used for testing and development purposes within the ecosystem. It allows for free minting to simulate user deposits.

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
forge test
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