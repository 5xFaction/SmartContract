// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {SimpleVault} from "../src/SimpleVault.sol";

contract MockUSDCScript is Script {
    MockUSDC public token;
    SimpleVault public vault;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy MockUSDC
        token = new MockUSDC();
        console.log("MockUSDC deployed at:", address(token));

        // Deploy SimpleVault
        vault = new SimpleVault(address(token));
        console.log("SimpleVault deployed at:", address(vault));

        vm.stopBroadcast();
    }
}
