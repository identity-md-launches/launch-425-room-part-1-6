// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {Room} from "../src/Room.sol";

/// @title Deploy
/// @notice Reference deployment of the Room. Reads no keys and no RPC secrets: the only
///         input is `EXPECTED_CHAIN_ID`, which must match the connected chain and be one of
///         the allowed targets (Anvil 31337 or Sepolia 11155111). `0` skips the check so the
///         script can be dry-run offline. The operator supplies the signer on the command line.
/// @dev The production launch goes through the network's ProjectFactory using `launch.json`;
///      this script is the reviewable standalone equivalent and exercises the same init code.
contract Deploy is Script {
    uint256 public constant ANVIL = 31337;
    uint256 public constant SEPOLIA = 11155111;

    error UnexpectedChain(uint256 expected, uint256 actual);
    error ChainNotAllowed(uint256 chainId);

    function run() external returns (Room room) {
        uint256 expected = vm.envOr("EXPECTED_CHAIN_ID", uint256(0));
        check(expected, block.chainid);
        vm.startBroadcast();
        room = deploy();
        vm.stopBroadcast();
    }

    /// @notice Pure chain guard, tested directly.
    function check(uint256 expected, uint256 actual) public pure {
        if (expected == 0) return;
        if (expected != ANVIL && expected != SEPOLIA) revert ChainNotAllowed(expected);
        if (expected != actual) revert UnexpectedChain(expected, actual);
    }

    /// @notice The single deployment. No constructor arguments, no post-deploy calls.
    function deploy() public returns (Room) {
        return new Room();
    }
}
