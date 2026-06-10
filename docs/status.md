# Project Status

6529Stream is pre-audit and not production-ready.

The current Gate A smoke baseline proves:

- Foundry is configured to compile `smart-contracts`.
- `forge build` runs against Solidity `0.8.19`.
- `forge test -vvv` executes real tests for admin guards, EIP-712 and ERC-1271
  drop authorization, auction custody and payment credits, fixed-price
  pull-payment credits, curator reward claim credits, and randomness/pending
  metadata behavior. Current emergency-withdrawal target-state tests also cover
  `StreamMinter` surplus withdrawal and `NextGenRandomizerRNG` reserve
  boundaries.
- CI can run the same build/test smoke commands and publish logs.

The current tests are regression tripwires, not a correctness proof. Known
blockers remain tracked in `ops/ROADMAP.md`, including broader pull-payment
accounting and cross-contract invariants, fuller randomizer reserve lifecycle
accounting and callback hardening, static-analysis triage, admin/pause
controls, deployment discipline, and the broader P0/P1 test suite.

Contributor and security intake files exist so future work can be packaged and
reviewed consistently, but they do not change the pre-audit status.
