// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AgentPact} from "../contracts/AgentPact.sol";

/// @notice Deploy AgentPact to BSC Testnet (chain 97).
/// @dev Run with a throwaway testnet-only key. Never use a real wallet key.
///      forge script script/Deploy.s.sol --rpc-url bsc_testnet --broadcast
contract Deploy is Script {
    function run() external returns (AgentPact) {
        vm.startBroadcast();
        AgentPact pact = new AgentPact();
        vm.stopBroadcast();
        console.log("AgentPact deployed at:", address(pact));
        return pact;
    }
}
