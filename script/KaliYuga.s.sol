// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {KaliYuga} from "../src/KaliYuga.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract KaliYugaScript is Script {
    KaliYuga public game;
    MockUSDC public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy Eternal Ink (MockUSDC)
        token = new MockUSDC();
        console.log("Eternal Ink (MockUSDC) deployed at:", address(token));

        // Deploy Kali-Yuga: The Last Ink Game
        // Epoch: 1 day, Ink Rate: 1% per day
        game = new KaliYuga(address(token), 1 days, 100);
        console.log("Kali-Yuga: The Last Ink deployed at:", address(game));

        console.log("\n=== THE WHITE CANVAS AWAITS ===");
        console.log("Five clans battle for the Eternal Ink...");
        console.log("SHADOW | BLADE | SPIRIT | PILLAR | WIND");

        vm.stopBroadcast();
    }
}
