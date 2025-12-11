// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract MockUSDCScript is Script {
    MockUSDC public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new MockUSDC();

        vm.stopBroadcast();
    }
}
