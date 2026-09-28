// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Room} from "../src/Room.sol";

contract RoomTest is Test {
    /// @dev Size budget from the brief. Later parts must fit five more agents under EIP-170.
    uint256 internal constant ROOM_BUDGET = 2_000;
    uint256 internal constant AGENT_BUDGET = 1_500;
    uint256 internal constant RUNTIME_BUDGET = 12_000;

    Room internal room;

    function setUp() public {
        room = new Room();
    }

    // ---------------------------------------------------------------- render()

    function test_renderStartsWithSvgAndEndsWithClosingTag() public view {
        bytes memory svg = bytes(room.render());
        assertTrue(_startsWith(svg, "<svg"), "must start with <svg");
        assertTrue(_endsWith(svg, "</svg>"), "must end with </svg>");
        assertEq(_count(svg, "<svg"), 1, "exactly one opening svg tag");
        assertEq(_count(svg, "</svg>"), 1, "exactly one closing svg tag");
    }

    function test_renderIsDeterministic() public {
        assertEq(keccak256(bytes(room.render())), keccak256(bytes(room.render())));
        Room other = new Room();
        assertEq(keccak256(bytes(other.render())), keccak256(bytes(room.render())));
    }

    function test_renderIsRoomPlusAgentsPlusClose() public view {
        string memory expected = string.concat(room.roomSvg(), room.agentSvg(1), "</svg>");
        assertEq(room.render(), expected);
    }

    function test_renderDrawsSixDesksWithNameplates() public view {
        bytes memory svg = bytes(room.render());
        assertEq(_count(svg, "<use href=\"#d\""), 6, "six desk instances");
        assertEq(_count(svg, ">desk 1<"), 1, "desk 1 nameplate");
        assertEq(_count(svg, ">open<"), 5, "five open nameplates");
        assertEq(_count(svg, "<g transform=\"translate("), 1, "one placed agent");
        // Agent 1 is anchored on desk 1's corner.
        assertEq(_count(svg, "translate(40 130)"), 1, "agent sits at desk 1");
    }

    function test_renderIsWellFormedEnough() public view {
        bytes memory svg = bytes(room.render());
        assertEq(_count(svg, "<g"), _count(svg, "</g>"), "balanced groups");
        assertEq(_count(svg, "<text"), _count(svg, "</text>"), "balanced text");
        assertEq(_count(svg, "<defs>"), _count(svg, "</defs>"), "balanced defs");
        assertEq(_count(svg, "<"), _count(svg, ">"), "balanced angle brackets");
    }

    // ------------------------------------------------------------ agentCount()

    function test_agentCountIsOne() public view {
        assertEq(room.agentCount(), 1);
    }

    function test_onlyDeskOneHasAnAgent() public view {
        assertGt(bytes(room.agentSvg(1)).length, 0, "desk 1 is occupied");
        for (uint256 d = 2; d <= 6; ++d) {
            assertEq(bytes(room.agentSvg(d)).length, 0, "desk should be empty");
        }
    }

    // ------------------------------------------------------------- deskLabel()

    function test_deskLabels() public view {
        assertEq(room.DESKS(), 6);
        assertEq(room.deskLabel(1), "desk 1");
        assertEq(room.deskLabel(2), "open");
        assertEq(room.deskLabel(3), "open");
        assertEq(room.deskLabel(4), "open");
        assertEq(room.deskLabel(5), "open");
        assertEq(room.deskLabel(6), "open");
    }

    function test_deskLabelZeroReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Room.NoSuchDesk.selector, 0));
        room.deskLabel(0);
    }

    function test_deskLabelSevenReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Room.NoSuchDesk.selector, 7));
        room.deskLabel(7);
    }

    function test_agentSvgOutOfRangeReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Room.NoSuchDesk.selector, 0));
        room.agentSvg(0);
        vm.expectRevert(abi.encodeWithSelector(Room.NoSuchDesk.selector, 7));
        room.agentSvg(7);
    }

    function testFuzz_deskLabelRejectsUnknownDesks(uint256 desk) public {
        vm.assume(desk == 0 || desk > 6);
        vm.expectRevert(abi.encodeWithSelector(Room.NoSuchDesk.selector, desk));
        room.deskLabel(desk);
    }

    function testFuzz_deskLabelMatchesOccupancy(uint256 desk) public view {
        desk = bound(desk, 1, 6);
        string memory label = room.deskLabel(desk);
        if (desk <= room.agentCount()) {
            assertEq(label, string.concat("desk ", vm.toString(desk)));
            assertGt(bytes(room.agentSvg(desk)).length, 0);
        } else {
            assertEq(label, "open");
            assertEq(bytes(room.agentSvg(desk)).length, 0);
        }
    }

    // ------------------------------------------------------------ size budget

    function test_roomAndDesksFitTheBudget() public view {
        assertLe(bytes(room.roomSvg()).length, ROOM_BUDGET, "room + desks > 2000 bytes");
    }

    function test_oneAgentFitsTheBudget() public view {
        assertLe(bytes(room.agentSvg(1)).length, AGENT_BUDGET, "agent > 1500 bytes");
    }

    function test_runtimeFitsTheBudget() public view {
        uint256 size = address(room).code.length;
        assertGt(size, 0);
        assertLe(size, RUNTIME_BUDGET, "runtime > 12000 bytes");
    }

    // --------------------------------------------------------- value-free rules

    function test_rejectsEther() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(room).call{value: 1}("");
        assertFalse(ok, "Room must not accept ETH");
        assertEq(address(room).balance, 0);
    }

    function test_unknownSelectorReverts() public {
        (bool ok,) = address(room).call(abi.encodeWithSignature("setLabel(uint256,string)", 1, "x"));
        assertFalse(ok);
        (bool ok2,) = address(room).call(abi.encodeWithSignature("transferOwnership(address)", address(1)));
        assertFalse(ok2);
    }

    function test_runtimeHasNoEscapeOpcodes() public view {
        bytes memory code = address(room).code;
        for (uint256 j; j < code.length; ++j) {
            uint8 op = uint8(code[j]);
            if (op >= 0x60 && op <= 0x7f) {
                j += op - 0x5f;
                continue;
            }
            assertTrue(op != 0xf4, "DELEGATECALL");
            assertTrue(op != 0xf2, "CALLCODE");
            assertTrue(op != 0xff, "SELFDESTRUCT");
            assertTrue(op != 0xf1 && op != 0xfa, "CALL/STATICCALL");
            assertTrue(op != 0x55, "SSTORE");
        }
    }

    // ---------------------------------------------------------------- helpers

    function _startsWith(bytes memory s, bytes memory p) internal pure returns (bool) {
        if (s.length < p.length) return false;
        for (uint256 i; i < p.length; ++i) {
            if (s[i] != p[i]) return false;
        }
        return true;
    }

    function _endsWith(bytes memory s, bytes memory p) internal pure returns (bool) {
        if (s.length < p.length) return false;
        uint256 off = s.length - p.length;
        for (uint256 i; i < p.length; ++i) {
            if (s[off + i] != p[i]) return false;
        }
        return true;
    }

    function _count(bytes memory s, bytes memory p) internal pure returns (uint256 n) {
        if (p.length == 0 || s.length < p.length) return 0;
        for (uint256 i; i + p.length <= s.length; ++i) {
            bool hit = true;
            for (uint256 j; j < p.length; ++j) {
                if (s[i + j] != p[j]) {
                    hit = false;
                    break;
                }
            }
            if (hit) ++n;
        }
    }
}
