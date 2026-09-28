// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {LaunchToken} from "../src/LaunchToken.sol";

contract LaunchTokenTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000e18;

    LaunchToken internal token;
    address internal deployer = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        token = new LaunchToken();
    }

    function test_metadata() public view {
        assertEq(token.name(), "The Room");
        assertEq(token.symbol(), "ROOM");
        assertEq(token.decimals(), 18);
    }

    function test_fixedSupplyMintedToDeployer() public view {
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.totalSupply(), 10 ** 27);
        assertEq(token.balanceOf(deployer), SUPPLY);
    }

    function test_transferMovesExactAmount() public {
        uint256 amount = 1_000e18;
        assertTrue(token.transfer(alice, amount));
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(deployer), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferInsufficientBalanceReverts() public {
        vm.prank(alice);
        vm.expectRevert(LaunchToken.InsufficientBalance.selector);
        token.transfer(bob, 1);
    }

    function test_transferToZeroReverts() public {
        vm.expectRevert(LaunchToken.ZeroAddress.selector);
        token.transfer(address(0), 1);
    }

    function test_approveAndTransferFrom() public {
        assertTrue(token.approve(alice, 500));
        assertEq(token.allowance(deployer, alice), 500);
        vm.prank(alice);
        assertTrue(token.transferFrom(deployer, bob, 300));
        assertEq(token.balanceOf(bob), 300);
        assertEq(token.allowance(deployer, alice), 200);
        vm.prank(alice);
        vm.expectRevert(LaunchToken.InsufficientAllowance.selector);
        token.transferFrom(deployer, bob, 201);
    }

    function test_infiniteAllowanceIsNotDecremented() public {
        token.approve(alice, type(uint256).max);
        vm.prank(alice);
        token.transferFrom(deployer, bob, 1);
        assertEq(token.allowance(deployer, alice), type(uint256).max);
    }

    function test_noAdminCallChangesSupply() public {
        address attacker = address(0xBEEF);
        string[6] memory sigs = [
            "mint(address,uint256)",
            "mint(uint256)",
            "burn(uint256)",
            "transferOwnership(address)",
            "upgradeTo(address)",
            "initialize(address)"
        ];
        for (uint256 i; i < sigs.length; ++i) {
            vm.prank(attacker);
            (bool ok,) = address(token).call(abi.encodeWithSignature(sigs[i], attacker, type(uint128).max));
            assertFalse(ok, sigs[i]);
            assertEq(token.totalSupply(), SUPPLY);
            assertEq(token.balanceOf(attacker), 0);
        }
    }

    function test_runtimeHasNoEscapeOpcodes() public view {
        bytes memory code = address(token).code;
        assertGt(code.length, 0);
        for (uint256 j; j < code.length; ++j) {
            uint8 op = uint8(code[j]);
            if (op >= 0x60 && op <= 0x7f) {
                j += op - 0x5f;
                continue;
            }
            assertTrue(op != 0xf4 && op != 0xf2 && op != 0xff, "forbidden opcode");
        }
    }

    function testFuzz_transferConservesSupply(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != deployer);
        amount = bound(amount, 0, SUPPLY);
        token.transfer(to, amount);
        assertEq(token.balanceOf(to) + token.balanceOf(deployer), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
