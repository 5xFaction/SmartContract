// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {SimpleVault} from "../src/SimpleVault.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract MockUSDCTest is Test, IERC20Errors {
    MockUSDC public token;
    SimpleVault public vault;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Events to test
    event Minted(address indexed to, uint256 amount, address indexed minter);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        token = new MockUSDC();
        vault = new SimpleVault(address(token));
    }

    /*//////////////////////////////////////////////////////////////
                           METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TokenMetadata() public view {
        assertEq(token.name(), "Mock USDC");
        assertEq(token.symbol(), "MUSDC");
        assertEq(token.decimals(), 6);
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint() public {
        vm.expectEmit(true, true, false, true);
        emit Minted(alice, 1000e6, address(this));
        
        token.mint(alice, 1000e6);
        
        assertEq(token.balanceOf(alice), 1000e6);
        assertEq(token.totalSupply(), 1000e6);
    }

    function test_AnyoneCanMint() public {
        vm.prank(alice);
        token.mint(alice, 500e6);
        assertEq(token.balanceOf(alice), 500e6);

        vm.prank(bob);
        token.mint(bob, 300e6);
        assertEq(token.balanceOf(bob), 300e6);
        
        assertEq(token.totalSupply(), 800e6);
    }

    function test_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidReceiver.selector, address(0)));
        token.mint(address(0), 100e6);
    }

    function test_BatchMint() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e6;
        amounts[1] = 200e6;
        amounts[2] = 300e6;
        
        token.batchMint(recipients, amounts);
        
        assertEq(token.balanceOf(alice), 100e6);
        assertEq(token.balanceOf(bob), 200e6);
        assertEq(token.balanceOf(charlie), 300e6);
        assertEq(token.totalSupply(), 600e6);
    }

    function test_RevertBatchMintLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e6;
        amounts[1] = 200e6;
        amounts[2] = 300e6;
        
        vm.expectRevert("Length mismatch");
        token.batchMint(recipients, amounts);
    }

    /*//////////////////////////////////////////////////////////////
                           BURNING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Burn() public {
        token.mint(alice, 1000e6);
        
        vm.prank(alice);
        token.burn(400e6);
        
        assertEq(token.balanceOf(alice), 600e6);
        assertEq(token.totalSupply(), 600e6);
    }

    function test_BurnFrom() public {
        token.mint(alice, 1000e6);
        
        vm.prank(alice);
        token.approve(bob, 500e6);
        
        vm.prank(bob);
        token.burnFrom(alice, 300e6);
        
        assertEq(token.balanceOf(alice), 700e6);
        assertEq(token.allowance(alice, bob), 200e6);
        assertEq(token.totalSupply(), 700e6);
    }

    function test_RevertBurnInsufficientBalance() public {
        token.mint(alice, 100e6);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, alice, 100e6, 200e6));
        token.burn(200e6);
    }

    function test_RevertBurnFromInsufficientAllowance() public {
        token.mint(alice, 1000e6);
        
        vm.prank(alice);
        token.approve(bob, 100e6);
        
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, bob, 100e6, 200e6));
        token.burnFrom(alice, 200e6);
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Transfer() public {
        token.mint(alice, 1000e6);
        
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 300e6);
        token.transfer(bob, 300e6);
        
        assertEq(token.balanceOf(alice), 700e6);
        assertEq(token.balanceOf(bob), 300e6);
    }

    function test_TransferFrom() public {
        token.mint(alice, 1000e6);
        
        vm.prank(alice);
        token.approve(bob, 500e6);
        
        vm.prank(bob);
        token.transferFrom(alice, charlie, 300e6);
        
        assertEq(token.balanceOf(alice), 700e6);
        assertEq(token.balanceOf(charlie), 300e6);
        assertEq(token.allowance(alice, bob), 200e6);
    }

    function test_RevertTransferInsufficientBalance() public {
        token.mint(alice, 100e6);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, alice, 100e6, 200e6));
        token.transfer(bob, 200e6);
    }

    function test_RevertTransferToZeroAddress() public {
        token.mint(alice, 100e6);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 50e6);
    }

    /*//////////////////////////////////////////////////////////////
                           APPROVAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Approve() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, 500e6);
        token.approve(bob, 500e6);
        
        assertEq(token.allowance(alice, bob), 500e6);
    }

    function test_IncreaseAllowance() public {
        vm.startPrank(alice);
        token.approve(bob, 100e6);
        token.approve(bob, 300e6);
        vm.stopPrank();
        
        assertEq(token.allowance(alice, bob), 300e6);
    }

    /*//////////////////////////////////////////////////////////////
                           PERMIT TESTS (EIP-2612)
    //////////////////////////////////////////////////////////////*/

    function test_Permit() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        address spender = bob;
        uint256 value = 1000e6;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(owner, spender, value, deadline, v, r, s);

        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), 1);
    }

    function test_RevertPermitExpired() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        uint256 deadline = block.timestamp - 1; // Expired

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                1000e6,
                0,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(); // ERC2612ExpiredSignature
        token.permit(owner, bob, 1000e6, deadline, v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS (with Vault)
    //////////////////////////////////////////////////////////////*/

    function test_VaultDeposit() public {
        // Mint tokens to alice
        token.mint(alice, 1000e6);
        
        vm.startPrank(alice);
        // Approve vault to spend alice's tokens
        token.approve(address(vault), 500e6);
        
        // Deposit into vault
        vault.deposit(500e6);
        vm.stopPrank();
        
        // Check balances
        assertEq(vault.balanceOf(alice), 500e6);
        assertEq(token.balanceOf(alice), 500e6);
        assertEq(token.balanceOf(address(vault)), 500e6);
        assertEq(vault.totalDeposits(), 500e6);
    }

    function test_VaultWithdraw() public {
        // Setup: Alice deposits
        token.mint(alice, 1000e6);
        vm.startPrank(alice);
        token.approve(address(vault), 500e6);
        vault.deposit(500e6);
        
        // Withdraw
        vault.withdraw(300e6);
        vm.stopPrank();
        
        // Check balances
        assertEq(vault.balanceOf(alice), 200e6);
        assertEq(token.balanceOf(alice), 800e6);
        assertEq(token.balanceOf(address(vault)), 200e6);
    }

    function test_VaultMultipleUsers() public {
        // Alice deposits
        token.mint(alice, 1000e6);
        vm.startPrank(alice);
        token.approve(address(vault), 500e6);
        vault.deposit(500e6);
        vm.stopPrank();
        
        // Bob deposits
        token.mint(bob, 2000e6);
        vm.startPrank(bob);
        token.approve(address(vault), 1000e6);
        vault.deposit(1000e6);
        vm.stopPrank();
        
        // Check balances
        assertEq(vault.balanceOf(alice), 500e6);
        assertEq(vault.balanceOf(bob), 1000e6);
        assertEq(vault.totalDeposits(), 1500e6);
        assertEq(token.balanceOf(address(vault)), 1500e6);
    }

    function test_VaultPermitDeposit() public {
        // Setup permit
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        token.mint(owner, 1000e6);
        
        uint256 value = 500e6;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                address(vault),
                value,
                0,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Execute permit and deposit
        token.permit(owner, address(vault), value, deadline, v, r, s);
        
        vm.prank(owner);
        vault.deposit(value);
        
        // Verify
        assertEq(vault.balanceOf(owner), 500e6);
        assertEq(token.balanceOf(owner), 500e6);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= type(uint256).max / 2); // Prevent overflow
        
        token.mint(to, amount);
        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_Transfer(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount <= type(uint256).max / 2);
        vm.assume(transferAmount <= mintAmount);
        
        token.mint(alice, mintAmount);
        
        vm.prank(alice);
        token.transfer(bob, transferAmount);
        
        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }

    function testFuzz_Burn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount <= type(uint256).max / 2);
        vm.assume(burnAmount <= mintAmount);
        
        token.mint(alice, mintAmount);
        
        vm.prank(alice);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(alice), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function testFuzz_BatchMint(uint8 numRecipients) public {
        vm.assume(numRecipients > 0 && numRecipients <= 50);
        
        address[] memory recipients = new address[](numRecipients);
        uint256[] memory amounts = new uint256[](numRecipients);
        
        uint256 totalAmount;
        
        for (uint256 i = 0; i < numRecipients; i++) {
            recipients[i] = address(uint160(i + 1));
            amounts[i] = (i + 1) * 100e6;
            totalAmount += amounts[i];
        }
        
        token.batchMint(recipients, amounts);
        
        assertEq(token.totalSupply(), totalAmount);
        
        for (uint256 i = 0; i < numRecipients; i++) {
            assertEq(token.balanceOf(recipients[i]), amounts[i]);
        }
    }
}
