// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FiveFaction} from "../src/FiveFaction.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {MockDeFi} from "../src/MockDeFi.sol";

contract FiveFactionScript is Script {
    FiveFaction public game;
    MockUSDC public token;
    MockDeFi public defi;

    function run() public {
        vm.startBroadcast();

        token = new MockUSDC();
        console.log("MockUSDC deployed at:", address(token));
        
        defi = new MockDeFi(address(token));
        console.log("MockDeFi deployed at:", address(defi));

        game = new FiveFaction(address(token), address(defi), 7 days);
        console.log("FiveFaction deployed at:", address(game));

        token.mint(msg.sender, 1_000_000e6);
        token.approve(address(defi), 1_000_000e6);
        defi.fundYieldPool(1_000_000e6);
        
        console.log("MockDeFi funded with 1M yield liquidity");

        vm.stopBroadcast();
    }
}
