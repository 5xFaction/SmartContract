// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {Vault} from "../src/Vault.sol";

contract VaultScript is Script {
    MockUSDC public token;
    Vault public vault;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new MockUSDC();
        vault = new Vault(address(token));

        vm.stopBroadcast();
    }
}
