# 5xFaction Smart Contracts

This repository contains a collection of smart contracts for gamified DeF protocols and vaults, built using the Foundry framework.

## Contracts Overview

### 1. Kali-Yuga: The Last Ink 🎨⚔️ (NEW - Mythology-Futuristic Theme)

> *The world has reached the end of times (Kali Yuga) where light has vanished. Only the "Eternal Ink" remains as the source of power. Five clans fight to claim the remnants of existence in an arena called "The White Canvas".*

**Kali-Yuga** is a unique \"no-loss\" gamified yield protocol where 5 clans compete for the Eternal Ink based on Total Value Locked (TVL) relationships.

**Visual Style**: Heavy ink aesthetic inspired by manga like Vagabond

**The Five Clans:**
* 🌑 **SHADOW** (影 Kage) - Assassins who merge with shadows
* ⚔️ **BLADE** (剣 Ken) - Samurai with giant swords that cut anything
* 👻 **SPIRIT** (霊 Rei) - Invisible entities that attack the mind
* 🗿 **PILLAR** (柱 Hashira) - Absolute defense with extraordinary physical power
* 🌪️ **WIND** (風 Kaze) - Archers who attack from invisible distances

**Game Mechanics:**
* **Pentagon Cycle**: Each clan has 2 **Targets** (clans they beat) and 2 **Predators** (clans that beat them)
* **Scoring**: `Score = (Target1 TVL + Target2 TVL) - (Predator1 TVL + Predator2 TVL)`
* **Winning**: The clan with the highest score wins all the Eternal Ink for that epoch
* **Rewards**: Eternal Ink is distributed proportionally to warriors in the winning clan
* **No-Loss**: Losing clans keep their principal and can fight again in the next epoch

**Clan Relationships (Pentagon Cycle):**
| Clan | Beats (Targets) | Loses To (Predators) | Lore |
| :--- | :--- | :--- | :--- |
| **SHADOW** | SPIRIT, WIND | BLADE, PILLAR | Shadow traps spirits and approaches archers, but can't escape sharp blades or hard bodies |
| **BLADE** | SHADOW, PILLAR | SPIRIT, WIND | Sharp sword cuts shadows and pierces armor, but can't slash spirits or dodge distant arrows |
| **SPIRIT** | BLADE, PILLAR | WIND, SHADOW | Spirits can't be cut and penetrate defense, but wind disperses them and shadows trap them |
| **PILLAR** | WIND, SHADOW | BLADE, SPIRIT | Hard body immune to arrows and traps shadows, but sharp blades pierce and spirits penetrate |
| **WIND** | SPIRIT, BLADE | PILLAR, SHADOW | Wind disperses spirits and attacks from afar, but useless against hard bodies and outmaneuvered by shadows |

**Contract**: `KaliYuga.sol` | **Test**: `KaliYuga.t.sol` (15 tests, all passing ✅)

#### 🚀 Deployed on Arbitrum Sepolia

| Contract | Address | Explorer |
|----------|---------|----------|
| **Kali-Yuga** | `0xab434F974E83aDd2223FDc876f93FE27AB6F37F2` | [View on Arbiscan](https://sepolia.arbiscan.io/address/0xab434F974E83aDd2223FDc876f93FE27AB6F37F2) |
| **MockUSDC (Eternal Ink)** | `0x27BC2C9B9980f6F2994C604730712472F2D864DF` | [View on Arbiscan](https://sepolia.arbiscan.io/address/0x27BC2C9B9980f6F2994C604730712472F2D864DF) |
| **SimpleVault** | `0x9BDf74A54f0c0455a83703a4511BBE686AD071d9` | [View on Arbiscan](https://sepolia.arbiscan.io/address/0x9BDf74A54f0c0455a83703a4511BBE686AD071d9) |

**Network**: Arbitrum Sepolia (Chain ID: 421614)  
**RPC URL**: https://sepolia-rollup.arbitrum.io/rpc

---

### 2. Vault (Simple Yield)

**Vault** is a straightforward staking contract.

*   **Logic**: Users deposit tokens and earn a fixed daily yield.
*   **Rate**: 1% per day (100 basis points).
*   **Rewards**: Rewards are minted (mock logic) upon withdrawal or claiming.

### 2. MockUSDC

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

### 3. SimpleVault

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