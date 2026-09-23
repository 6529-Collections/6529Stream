# Mint phase freeze implementation batch

## Scope and status

This batch implements the original optional Freeze Policy on base
`0d7b781b76b58e460be9d40df55c85ce81f1f628`. It is source-reviewed implementation
with matched ABI/storage and selected bytecode evidence. The focused native
cohort passes all 17 Ledger-freeze and six configuration cases on immutable
commit `8f2e91577733a18eeedbc47ea91325eb3e79b4e0`. The 11 actual-current freeze
and three new current continuity cases, broad current-stack tests,
fuzz/invariants, gas acceptance, CI and release artifacts remain pending the
coordinator's combined run. It does not
claim production readiness or an audited protocol.

The Manager and fallback retain every prior public ABI entry and all 19 storage
entries. Ledger retains every prior ABI entry and its 26-entry storage prefix;
one appended State field contains three mapping slots. Core is unchanged.
Permanent Manager/Ledger interface declarations, compiler settings, gas parameters,
16-counter/64-executor limits and original governance delays are unchanged.

The [caller guide](../docs/integrations/mint-phase-freeze.md) documents exact
selectors, classifier/terminal action planning and the import sequence. The new
capability IDs are Manager `0x75408bb0` and Ledger `0x364317e1`.

## Original requirements

| Freeze Policy invariant | Enforcement |
| --- | --- |
| Counters cannot be removed | Initial-only Manager configuration; Ledger compares ordered IDs at frozen registration/import |
| Counters cannot be disabled | Full counter tuple and registered projection are retained |
| Caps cannot increase | Exact static cap and effective definition commitment |
| Scope/key/update/resolver/cap-root cannot change | Full Manager counter tuple plus pinned defined/legacy interpretation |
| New counters cannot be added | Exact ordered counter inventory |
| Time window cannot extend | Exact start/end configuration, excluding only pause |
| Gate cannot loosen | Exact gate configuration and codehash pin |
| Executors cannot be added | Actual Manager set is checked against a monotonically shrinking canonical ceiling |
| Pause remains available | Original pause/unpause behavior and event remain; no hash/grace change |
| Cap/delta modes cannot loosen | Exact full counter tuple and Ledger projection |
| Module codehash pins cannot be removed | Original immutable dependencies and exact gate/royalty pins |
| Frozen phase cannot move to a different Ledger | Original import commitment rejects a frozen source inventory on another Ledger |

Freeze requires an existing phase, its original owner/reentrancy guards and the
exact executing class-2 action from immutable governance authority. The original
72-hour terminal veto floor applies. The Manager emits the exact normative
`MintPhaseFrozen` event. Freeze does not change policy hash, grace, consent or
accounting. Executor removal uses the original Artist consent and grace path;
removed executors cannot return. Zero-grace no-ops remain no-ops.

## Durable successor state

Original permanent writer retirement makes the captured source inventory stable.
Every frozen phase must be copied before original import completion. A candidate
already configured must match the source's immutable terms and remaining rights.
An unconfigured candidate inherits constraints before completion; its first
configuration seeds the actual remaining executor set before computing its new
policy and obtaining fresh Artist consent. Failed registration rolls back that
bootstrap. This preserves original import -> Core cutover -> Artist-authorized
configuration order without a circular prerequisite.

An inherited phase can remain unconfigured through more than one replacement.
Its original first-frozen policy hash remains provenance, not successor mint
permission. The canonical constraint hash and inventory cannot disappear.

For a configured snapshot royalty policy, the original wrapper hash binds its
Manager. The Ledger verifies that exact original preimage against the actual
224-byte policy before normalizing only the Manager wrapper. Distinct raw and
configured branch tags, application terms and the complete policy tuple prevent
cross-branch substitution. Resolver, runtime, election, mode-assignment and
source-policy facts remain exact. This does not implement or apply any held
royalty proposal. The focused royalty cases use an explicitly typed Manager
boundary; full actual snapshot-royalty successor execution is not claimed.

## Regression recipes

There are 37 new cases:

- 17 actual-Ledger cases with an explicitly mutable typed Manager boundary:
  immutable constraints, effective definitions, subset/re-add, wrong policy,
  paused/grace behavior, partial copying, completion barriers, preconfigured and
  unconfigured successors, multiple generations, retirement, legacy capability
  decoding, cross-Ledger refusal and constrained royalty-domain normalization.
- 11 actual-current Artist/Manager/Ledger/Governor Safe cases: original terminal
  delay, scoped guardian Safe veto, stale commitments, exact signed rollback and
  retry, additions/re-add, Artist-consented removals, predecessor tickets,
  original grace bounds, pause, no-ops and direct/wrong-class refusal.
- Three additions to the original current continuity suite: all frozen phases
  copied before cutover, fresh successor Artist consent with inherited rights,
  imported counter/nullifier preservation and exact Safe retry; different-Ledger
  refusal; and a current Artist contest stopping the frozen successor.
- Six original configuration/read ABI cases: all 16 counters and phase fields,
  pause receipt/no-op, cap/mismatch/empty-array failures, validation precedence,
  malformed array heads and zero-executor error preservation.

The combined ABI capture also includes existing mode-1/mode-2 consent/grace and
all original current continuity recipes: 65 tests across seven named suites.
Actual current suites retain their documented external entropy/test eligibility
boundaries and existing governed successor Artist read budgets.

## Matched evidence

All captures are retained under the ignored local directory
`artifacts/native-assembly/counter-scopes/` and must not be overwritten.

- `mint-phase-freeze-combined-abi-final-1`: 1,264 exact sources, 65 named tests,
  zero compiler errors. Input SHA-256
  `6c0863bfa639daf18c4e860bc1735d5c0a1063d460b69be1816562278b78849a`;
  output `7c16778f5558aa7b6cc134dce55dcb956021282b14d6aabda8ab6da7c4f04de8`.
- `mint-phase-freeze-compatibility-1`: all original 183 Manager, 185 fallback and
  88 Ledger ABI entries retained; unchanged recursive storage prefix/layout.
- `mint-phase-freeze-units-native-8f2e9157-1`: 159 exact committed sources,
  all 23 focused cases pass, exit zero in 283.585 seconds, with no source
  mismatches or captured oversized production products. Native JSON SHA-256
  `29d806aa09b36f83f62918d08b4e2adebed637823f6785b92f8929c81d5f94cc`;
  the separate log is empty. Solidity 0.8.19, IR/200, Paris and original metadata
  settings are retained. The original test-only 2,000,000-byte code limit,
  10,000,000,000 gas and 1 GiB memory envelope are unchanged; production runtime
  and init sizes are checked separately against 24,576 and 49,152 bytes.
  A copy of the prior valid mode-2 output/cache is reused through ordinary
  Foundry dependency invalidation, with exact snapshot and cache provenance in
  `capture.json`. The typed royalty cases do not establish actual-current
  snapshot-royalty successor acceptance.
- `mint-phase-freeze-size-final-1`: 153 exact sources, ten selected products,
  Solidity 0.8.19, via IR, optimizer 200, Paris, no CBOR/hash metadata; 42.907
  seconds, no compiler errors or oversized products. Input SHA-256
  `e211bef77a7ea03dac2702e60a1587f227f188cb71bcb8aa27d8ef37579d4bce`;
  output `4b8ffd7bac78f99b5aaee751fdff7ca4f3edbe08e24baaf72c50bd0bb9442b36`.

| Selected product | Runtime bytes | Init bytes |
| --- | ---: | ---: |
| Manager | 24,396 | 27,513 |
| Fallback | 24,513 | 27,630 |
| Ledger | 20,615 | 20,712 |
| Freeze control | 3,816 | 3,850 |
| Freeze state | 8,534 | 8,568 |
| Manager policy | 3,179 | 3,213 |
| Manager views | 4,435 | 4,467 |
| Phase state | 8,722 | 8,756 |
| Fallback recovery | 5,142 | 5,176 |
| Artist consent | 3,104 | 3,136 |

The original oversize capture `mint-phase-freeze-size-1` and intermediate fitting
`mint-phase-freeze-size-2` remain immutable. Final host fit comes from fixed-worker
configuration decoding, pause bookkeeping and read encodings. Dynamic argument
heads are checked against the original count limit before allocation, and phase
validation retains its original precedence. No storage or production cap changed.

Markdown checker tests (17), link checks, changelog checks, scoped formatting and
Windows-aware whitespace checks pass. Generated release artifacts are deferred
under the active coherent-batch validation sequencing.
