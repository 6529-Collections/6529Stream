# Project Status

6529Stream is pre-audit and not production-ready.

The current Gate A smoke baseline proves:

- Foundry is configured to compile `smart-contracts`.
- `forge build` runs against Solidity `0.8.19`.
- `forge test -vvv` executes real tests for admin guards, target-scoped
  function-admin permission regressions, domain-scoped pause controls,
  signer-manager lifecycle controls with approved targets, EIP-712 and ERC-1271
  drop authorization,
  auction custody and payment credits, fixed-price pull-payment credits,
  curator reward claim credits, and randomness lifecycle behavior. Current
  emergency-withdrawal target-state tests also cover explicit emergency
  recipients, `StreamMinter` surplus withdrawal, `NextGenRandomizerRNG` reserve
  boundaries, dependency-script segment-safe content hashing, explicit
  local-initialization regressions, vendored OpenZeppelin utility-library
  provenance/behavior regressions, and retained airdrop mint-accounting
  behavior after removal of dead public/allowlist counters.
- Payment sequence fuzzing now covers mixed fixed-price mint, auction bid,
  auction settlement, curator claim, withdrawal, emergency withdrawal,
  randomizer reserve, and forced-balance operations, proving the current local
  ledgers keep category totals, owed totals, balance coverage, reserves, and
  emergency-withdrawable surplus coherent after each step. Current value-holding
  payment surfaces also expose ADR-style local-ledger aliases for reserved
  balances and surplus where applicable.
- Randomizer tests now cover request lifecycle views, callback validation,
  raw-output hash storage, failed post-processing state, bounded deterministic
  post-processing retry, and the conservative provider-migration policy that
  blocks lifecycle-aware provider replacement while collection requests are
  pending. They also prove `RandomizerNXT` cannot be configured as a
  production randomizer after removal of the concrete weak `XRandoms` helper
  from production source.
- Metadata tests now prove dependency chunk boundaries are included in typed
  content hashes while preserving the existing rendered generative script
  output, and `StreamMetadataGolden.t.sol` locks current off-chain pending/final
  URIs plus current on-chain pending/final JSON data URIs against fixtures.
- CI can run the same build/test smoke commands and publish logs.

The current tests are regression tripwires, not a correctness proof. Known
blockers remain tracked in `ops/ROADMAP.md`, including any future unified
pull-payment ledger abstraction or protocol-wide aggregation layer, fuller
randomizer reserve lifecycle accounting,
callback-after-burn policy, canonical randomizer lifecycle
ownership, lower-impact static-analysis cleanup beyond the now-triaged
high/medium baseline, signer/deployment ceremony runbooks, final metadata
schema/escaping, dependency version/freeze manifest work, deployment
discipline, and the broader P0/P1 test suite.

Contributor and security intake files exist so future work can be packaged and
reviewed consistently, but they do not change the pre-audit status.
