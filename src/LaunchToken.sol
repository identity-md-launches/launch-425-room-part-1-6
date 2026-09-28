// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title LaunchToken
/// @notice The fixed-supply ERC-20 the launch framework deploys next to the Room. It is
///         required by the launch process, not by the Room: the Room never references it,
///         holds it, or calls it.
/// @dev Minimal, self-contained ERC-20. No constructor arguments, 18 decimals, exactly
///      1,000,000,000 tokens minted once to the deployer. No mint, burn, owner, pause,
///      blocklist, fee or upgrade path. Nothing here can change the supply after construction.
contract LaunchToken {
    string public constant name = "The Room";
    string public constant symbol = "ROOM";
    uint8 public constant decimals = 18;

    /// @notice 1,000,000,000 tokens in minor units.
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    uint256 public immutable totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAddress();

    constructor() {
        totalSupply = TOTAL_SUPPLY;
        balanceOf[msg.sender] = TOTAL_SUPPLY;
        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}
