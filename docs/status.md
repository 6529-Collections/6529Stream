# Project Status

6529Stream is pre-audit and not production-ready.

The current Gate A smoke baseline proves:

- Foundry is configured to compile `smart-contracts`.
- `forge build` runs against Solidity `0.8.19`.
- `forge test -vvv` executes real initial characterization tests for admin
  guards, current drop behavior, fixed-price payout behavior, and
  randomness/pending metadata behavior.
- CI can run the same build/test smoke commands and publish logs.

The current tests are regression tripwires, not a correctness proof. Known
blockers remain tracked in `ops/ROADMAP.md`, including authorization, auction
custody, pull-payment accounting, randomizer hardening, static-analysis triage,
and the broader P0/P1 test suite.

Contributor and security intake files exist so future work can be packaged and
reviewed consistently, but they do not change the pre-audit status.
