// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title RoomLayout
/// @notice Fixed geometry, palette and furniture of the room. Every agent is drawn in
///         desk-local coordinates and placed with `deskX` / `deskY`, so later parts add an
///         agent without touching anything in this file.
/// @dev All values are compile-time constants. Nothing here reads storage or the chain.
library RoomLayout {
    /// @notice Number of desks in the room. Fixed for all six parts.
    uint256 internal constant DESKS = 6;

    /// @notice Canvas size, in SVG user units.
    uint256 internal constant WIDTH = 480;
    uint256 internal constant HEIGHT = 330;

    /// @dev Desk grid: three columns, two rows. Desk 1 is top-left, desk 6 bottom-right.
    uint256 internal constant DESK_X0 = 40;
    uint256 internal constant DESK_Y0 = 130;
    uint256 internal constant DESK_DX = 160;
    uint256 internal constant DESK_DY = 110;
    uint256 internal constant DESK_W = 90;

    // ---- palette (see STYLE.md) ----
    string internal constant WALL = "#1e2233";
    string internal constant FLOOR = "#2b3044";
    string internal constant TRIM = "#3a4160";
    string internal constant WOOD = "#c8a06a";
    string internal constant WOOD_DARK = "#9c7a4e";
    string internal constant PLATE = "#f4efe6";
    string internal constant SKY = "#7fa8d8";
    string internal constant MUTED = "#8b93ad";

    /// @notice Left edge of a desk top (desk-local x = 0). `desk` is 1-based.
    function deskX(uint256 desk) internal pure returns (uint256) {
        return DESK_X0 + DESK_DX * ((desk - 1) % 3);
    }

    /// @notice Top edge of a desk top (desk-local y = 0). `desk` is 1-based.
    function deskY(uint256 desk) internal pure returns (uint256) {
        return DESK_Y0 + DESK_DY * ((desk - 1) / 3);
    }

    /// @notice Opening `<svg>` tag. Defaults (monospace, 9px) apply to every nameplate.
    function svgOpen() internal pure returns (string memory) {
        return
            "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 480 330\" font-family=\"monospace\" font-size=\"9\">";
    }

    /// @notice Wall, floor, window, sign, and the shared desk symbol `#d`.
    function background() internal pure returns (string memory) {
        return string.concat(_walls(), _deskSymbol());
    }

    function _walls() private pure returns (string memory) {
        return string.concat(
            "<rect width=\"480\" height=\"330\" fill=\"",
            WALL,
            "\"/><rect y=\"110\" width=\"480\" height=\"220\" fill=\"",
            FLOOR,
            "\"/><rect y=\"108\" width=\"480\" height=\"4\" fill=\"",
            TRIM,
            "\"/><rect x=\"195\" y=\"18\" width=\"90\" height=\"50\" rx=\"3\" fill=\"",
            SKY,
            "\"/><path d=\"M240 18v50M195 43h90\" stroke=\"",
            WALL,
            "\" stroke-width=\"3\"/><text x=\"20\" y=\"36\" font-size=\"10\" fill=\"",
            MUTED,
            "\">THE ROOM</text>"
        );
    }

    function _deskSymbol() private pure returns (string memory) {
        return string.concat(
            "<defs><g id=\"d\"><rect width=\"90\" height=\"8\" rx=\"2\" fill=\"",
            WOOD,
            "\"/><g fill=\"",
            WOOD_DARK,
            "\"><rect x=\"4\" y=\"8\" width=\"6\" height=\"42\"/><rect x=\"80\" y=\"8\" width=\"6\" height=\"42\"/></g>",
            "<rect x=\"25\" y=\"16\" width=\"40\" height=\"13\" rx=\"2\" fill=\"",
            PLATE,
            "\"/></g></defs>"
        );
    }

    /// @notice One desk instance plus its nameplate text, in room coordinates.
    function drawDesk(uint256 n, string memory label) internal pure returns (string memory) {
        uint256 x = deskX(n);
        uint256 y = deskY(n);
        return string.concat(
            "<use href=\"#d\" x=\"",
            str(x),
            "\" y=\"",
            str(y),
            "\"/><text x=\"",
            str(x + 45),
            "\" y=\"",
            str(y + 26),
            "\">",
            label,
            "</text>"
        );
    }

    /// @notice Wraps a desk-local drawing so that (0,0) lands on the desk's top-left corner.
    function place(uint256 n, string memory drawing) internal pure returns (string memory) {
        return string.concat("<g transform=\"translate(", str(deskX(n)), " ", str(deskY(n)), ")\">", drawing, "</g>");
    }

    /// @notice Decimal rendering of small unsigned integers.
    function str(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        bytes memory buf = new bytes(78);
        uint256 i = 78;
        while (v != 0) {
            buf[--i] = bytes1(uint8(48 + v % 10));
            v /= 10;
        }
        bytes memory out = new bytes(78 - i);
        for (uint256 j; j < out.length; ++j) {
            out[j] = buf[i + j];
        }
        return string(out);
    }
}
