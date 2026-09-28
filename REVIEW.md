# Review: The Room, part 1

Scope: `src/Room.sol`, `src/RoomLayout.sol`, `src/agents/Agent1.sol`, `src/LaunchToken.sol`,
`script/Deploy.s.sol`, the tests, and the rendered `room.svg`. Reviewed against the brief
(value-free, deterministic, six desks, one agent, size budgets) and the launch floor
(`Project.protected.t.sol`, `Token.protected.t.sol`).

## What was re-run

```
forge build --offline                                   ok, no warnings
forge test --offline                                    35 passed, 0 failed (4 fuzz tests, 256 runs each)
forge fmt --check                                       clean
EXPECTED_CHAIN_ID=0 forge script script/Deploy.s.sol:Deploy --offline   ok, one deployment
python3 xml.dom.minidom parse of room.svg               well-formed; 6 <use>, labels desk 1 + 5x open
```

Measured: room+desks 1,133 B, agent 1,294 B, render 2,433 B, Room runtime 6,552 B,
LaunchToken runtime 1,323 B.

## Findings

1. **Sign collided with desk 2's monitor** (found during review, fixed). The wall sign was
   first centred at (240, 96); desk 2's monitor spans x 236..280, y 86..122. Moved the sign to
   (20, 36). Re-rendered and re-measured.
2. **`string.concat` with 19 arguments failed to compile** ("stack too deep"). Split into
   helpers of at most 12 arguments. STYLE.md warns later builders.
3. **Name shadowing warning** (`desk` function vs `desk` parameter). Renamed to `drawDesk`.
4. **Rejection of the previous attempt**: `src/LaunchToken.sol` was missing. The brief says
   "no token" for the Room; the launch process requires a LaunchToken regardless. Resolved by
   delivering the token as a separate contract that the Room does not reference in any way.
   Disposition: documented in README, tested in `test/LaunchToken.t.sol`.

No open findings.

## Checklist

- Access control: no state-changing functions exist on `Room`. `LaunchToken` has only the
  ERC-20 transfer/approve surface. No owner, no roles.
- Value: `Room` has no `receive`/`fallback`; sending ETH reverts (tested). No external calls,
  no `CALL`/`STATICCALL`/`DELEGATECALL`/`CALLCODE`/`SELFDESTRUCT`/`SSTORE` in Room runtime
  (tested by opcode scan that skips PUSH immediates, the same scan as the protected floor).
- Determinism: all Room functions are `pure`; two instances render byte-identical output
  (tested). No `block.*`, `msg.*`, or `tx.*` reads.
- Arithmetic: desk positions computed from `desk - 1` only after the range check, so no
  underflow path is reachable. `str()` handles 0 and any `uint256`.
- Bounds: `deskLabel`/`agentSvg` revert with `NoSuchDesk` for 0 and > 6 (unit + fuzz).
- Composition: `render() == roomSvg() + agentSvg(1) + "</svg>"` (tested), so the budgets
  measured on the parts are the budgets of the whole.
- Token floor: supply 10^27 to `msg.sender`, `decimals()` 18, exact transfer, curated admin
  selectors revert without changing supply, no forbidden opcodes. Mirrors the protected tests.
- Deploy: `run()` reads only `EXPECTED_CHAIN_ID` (via `envOr`, so an empty environment is
  fine); the guard `check()` and `deploy()` are tested directly. No key material anywhere.
- Constructor context: neither contract uses `msg.sender` for privileges. `LaunchToken` mints
  to `msg.sender`, which is the factory, as the floor requires.

## What the tests do not cover

- Visual correctness. The geometry was checked by hand (bounding boxes in STYLE.md) and the
  SVG parses, but no rasteriser was available in the sandbox to eyeball `room.svg`. A later
  builder should open it in a browser before extending the style.
- Gas of `render()` is a few hundred thousand when called in a transaction (the string
  concatenation dominates); it is meant for `eth_call`, which is free.
