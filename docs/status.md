# Project Status

6529Stream is pre-audit and not production-ready.

The current Gate A smoke baseline proves:

- Foundry is configured to compile `smart-contracts`.
- `forge build` runs against Solidity `0.8.19`.
- `forge test -vvv` executes real tests for admin guards, target-scoped
  function-admin permission regressions, domain-scoped pause controls,
  EIP-712 and ERC-1271 drop authorization, auction custody and payment credits,
  fixed-price pull-payment credits, curator reward claim credits, and
  randomness lifecycle behavior. Current emergency-withdrawal target-state
  tests also cover explicit emergency recipients, `StreamMinter` surplus
  withdrawal, and `NextGenRandomizerRNG` reserve boundaries.
- Randomizer tests now cover request lifecycle views, callback validation,
  raw-output hash storage, failed post-processing state, bounded deterministic
  post-processing retry, and the conservative provider-migration policy that
  blocks lifecycle-aware provider replacement while collection requests are
  pending.
- CI can run the same build/test smoke commands and publish logs.

The current tests are regression tripwires, not a correctness proof. Known
blockers remain tracked in `ops/ROADMAP.md`, including broader pull-payment
accounting and cross-contract invariants, fuller randomizer reserve lifecycle
accounting, callback-after-burn policy, canonical randomizer lifecycle
ownership, static-analysis triage, signer lifecycle operations, deployment
discipline, and the broader P0/P1 test suite.

Contributor and security intake files exist so future work can be packaged and
reviewed consistently, but they do not change the pre-audit status.
