// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing purposes
 * Features:
 * - 6 decimals (like real USDC)
 * - Permissionless minting (anyone can mint)
 * - Burnable (burn your own tokens or approved tokens)
 * - Permit support (EIP-2612) for gasless approvals
 */
contract MockUSDC is ERC20, ERC20Permit, ERC20Burnable {
    event Minted(address indexed to, uint256 amount, address indexed minter);

    constructor() ERC20("Mock USDC", "MUSDC") ERC20Permit("Mock USDC") {}

    /**
     * @dev Returns 6 decimals to match real USDC
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @dev Mint tokens to any address. Anyone can call this function.
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint (with 6 decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit Minted(to, amount, msg.sender);
    }

    /**
     * @dev Batch mint to multiple addresses
     * @param recipients Array of addresses to mint to
     * @param amounts Array of amounts to mint
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit Minted(recipients[i], amounts[i], msg.sender);
        }
    }
}
