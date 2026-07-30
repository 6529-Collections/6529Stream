# Active Context

## 2026-07-30 Final Core Headroom Closure

- Active issue: `#654`.
- Active branch: `codex/issue-654-final-closure`.
- Base: merged #670 bounded evidence-acceptance PR #714 at
  `ff78a39356497cccc2f810880a21a33b9213bb52`.
- The permanent target and its existing metadata/system Core-side rows are
  implemented; this does not include the concrete #670 artist/revenue
  satellites. The
  `StreamCore` row in the canonical bytecode proof is the final mutable runtime
  and margin owner. The risk generation step uses the cycle-free ABI checksum
  measurement, and check mode requires exact final-proof parity against the
  2,000-byte production floor.
- This closure satisfies the artifact-backed Core headroom requirement without
  claiming concrete #670 satellite source acceptance. ADR 0021's revenue
  architecture is Accepted but source-blocked; ADR 0022's artist architecture
  remains Proposed. Candidate-instance, governed-parameter, audit, deployment,
  and retained live evidence gates remain independently blocking.
- Historical runtime measurements below are chronology, not current authority.

## 2026-07-27 Atomic Operation-Identity Cutover

- The explicit protocol-owner shipping mandate releases this workstream to
  complete `#688`, `#671`, and `#654` through validated PRs and merge.
- Active issue: reopened `#688`.
- Active branch: `codex/issue-688-operation-root-cutover`.
- Final publication base and current `origin/main`:
  `0bc295d845e556ebb98e4fe59d891434a11072c9` after merged PR `#685`.
- Current committed corrective source checkpoint:
  `7c17e7644ca39257602cc5667f547026d22e855a`. The gate-nullifier cap,
  status/size/checker reconciliation, and refreshed evidence inputs are
  committed; the refreshed canonical artifacts are included in the corrective
  publication delta and have passed the authoritative Windows gate.
- PR #704 merged #672 as a zero-`StreamCore`-delta
  target-fixture/spec/measurement slice. It
  may pin the EIP-150 admission formula, worst-case post-coordinator EOA tail,
  pure policy-predicate boundaries, a separate high-parent-gas full-stipend
  path, rollback, and checksum-bound planning evidence. It does not prove an
  exact executable threshold at the low-level call. It must not edit
  `StreamCore`, claim current implementation conformance, fill #684 candidate
  measurement bindings, or close the actual Core seam.
- #671 is the next separate slice. It owns the shared
  `ROYALTY_RETURN_GAS_BUFFER` Core-read semantics and proof but must not add a
  23rd GGP or edit #684's missing candidate/evidence facts opportunistically.
- #654 is the final Core closure slice. The complete permanent target is
  implemented; this branch reconciles the bounded #670 evidence/semantic freeze,
  artifact-backed remeasurement, risk state, and live mirrors without
  overstating candidate, audit, deployment, or retained-live-evidence maturity.
- Core runtime and margin are owned by the `StreamCore` row in
  [`release-artifacts/latest/bytecode-release-proof.json`](../../../release-artifacts/latest/bytecode-release-proof.json),
  not duplicated in this active context. The complete target must remain at
  most 22,576 bytes for the exact 2,000-byte EIP-170 margin; the objective is at
  most 22,184 bytes. The historical 21,792-byte low-water mark and transitional
  operation-identity measurements are non-additive.
- The ten-minute serialization heartbeat was deleted when the shipping mandate
  explicitly released the lane.
- Current #672 measurement: 128,886 gas for the via-IR first-mint,
  all-zero-to-nonzero EOA-recipient post-coordinator tail. A 25% margin rounded
  up to the next 1,000 gas derives `POST_ENTROPY_PARENT_RESERVE = 162,000`.
  Focused validation is 10/10 Foundry tests under via IR, 26/26 Python hostile
  tests, direct checker current, and the one-test snapshot current.
- Exact frozen evidence remains byte-for-byte stable with zero
  `smart-contracts/StreamCore.sol` diff. The canonical bundle has 260
  configured paths and 428 records in each checksum index.
- Earlier diagnostic authoritative Windows gates exited `0` on
  `29d96466e49f7c72c02234c9b271a1fa2828db88` in 3,237.757 seconds and on
  `6b5d0ba3eed4758c4e3521470233266540c95a45` in 3,268.179 seconds. They prove
  the preserved slice is green but do not authorize publication because the
  shared tail advanced afterward.
- The single final-base publication-authorizing Windows `scripts/check.ps1`
  gate ran from `2026-07-26T20:07:36.9901476Z` through
  `2026-07-26T21:03:10.6197954Z` and exited `0` in 3,333.63 seconds. It
  includes 1,099/1,099 Foundry tests, 10/10 #672 via-IR tests, the exact
  128,886-gas snapshot, 113/113 checksum tests, 114/114 verifier tests,
  428/428 offline records, the canonical 53-target release build, direct
  24,152-byte Core size proof, and all deployment rehearsals.
- #672 merged in PR #704. The reopened #688 atomic operation-root
  Solidity/test/as-built cutover is now implemented locally and measures
  net-negative before #671 and #654. The prepared-operation identity and
  `isManagerOperationRootUsed` seam are current; typed primary settlement and
  repeat-sale correlation remain ADR 0019/#694 blockers. The permanent-Core
  implementation then completed the finality/headroom seam now closed under
  #654.

## Historical Permanent-Core Implementation Slice

- Issues at that point: `#654` permanent-Core implementation plus remaining
  `#671` integration acceptance and `#672` as-built binding.
- Branch: `codex/issue-654-entropy-router`.
- Base: merged `#671` evidence / `origin/main`
  `408c1b894f947fc0f8db34259f1c82ecd7e91439`.
- Result: the permanent Core consumes the storage-free overflow-safe admission
  source and authenticated three-row buffer model for `royaltyInfo()`,
  `tokenURI()`, and `contractURI()` without adding a 23rd GGP. Hostile tests
  cover maximum bounded returndata, malformed/oversized/reverting calls, full
  forwarded stipends, below/at/above actual Core thresholds, residues,
  independent 2x orderings, and the uint256 terminal raise chain.
- Measurement state: the six-scenario via-IR snapshot records a conservative
  725,735-gas worst completion path, deriving a 1,460,000 planning floor and
  2,910,000 planning genesis value. The checksum-bound artifact has no onchain
  authority, and candidate measurement/fixed-stipend facts remain incomplete.
<!-- historical-streamcore-size:start -->
- Historical measurement checkpoint: the permanent `StreamCore` implementation
  measured 18,997 bytes with 5,579 bytes of EIP-170 margin, a 5,131-byte
  reduction from the 24,128-byte transitional build. Those figures are retained
  as chronology only; the current authority is the bytecode proof linked above.
  The actual #671 read boundaries and #672 entropy completion seam were included.
  Do not claim candidate or production completion: the two concrete #670
  artist/revenue pointer rows remain unresolved, while #656/#684 own candidate,
  fixed-stipend, cadence, rehearsal, and independent-review evidence.
<!-- historical-streamcore-size:end -->

## Final Closure Actions

- Derive `RISK-SIZE-001` from the canonical proof and exact production floor.
- Reject below-floor, missing, inconsistent, and stale proof evidence.
- Refresh the canonical release tail once and close #654 only after exact-head
  focused, release, Slither, and full Windows validation is green.
- Keep the unimplemented #670 satellite source/security gates separate from
  Core headroom acceptance.
- Preserve #656/#684 fail-closed candidate and reviewed-evidence boundaries.

## Integration Gate

The active Core/mint order is final #654 artifact-backed closure while concrete
#670 adapter implementation/security acceptance stays separate. The current
publication must preserve the accepted ADR 0017 arithmetic and raise ordering,
exact 22-GGP catalog, measured net-negative Core delta, and honest candidate
incompleteness. It must also:

1. bind the #672 128,886-gas snapshot to the actual Core call boundary;
2. prove the exact #671 permanent-Core runtime and three read boundaries;
3. preserve ADR 0019/#694 settlement and repeated-sale blockers;
4. regenerate canonical source artifacts and the six-step release tail;
5. pass focused Foundry, exact Slither, offline release verification, and one
   authoritative Windows gate; and
6. report the complete changed-path inventory and exact final head before merge.

## Sequencing Guard

PR #704 merged the #672 planning/measurement slice and PR #708 merged #671's
evidence slice. The permanent Core now consumes both; no earlier serialization
hold remains.

<!-- historical-streamcore-size:start -->
Prior extraction reached a measured 21,792-byte Core runtime. The later
manager/prepared-mint slice produced the 24,152-byte pre-cutover transitional
build while legacy mint behavior remained live; 24,152 is later duplication,
not the pre-manager extraction baseline. The atomic operation-identity cutover
retires the duplicate mint path and lifetime Core replay map and measures
24,128 bytes, a 24-byte net reduction. Historical scratch deltas are not
additive savings.
<!-- historical-streamcore-size:end -->

The complete permanent target satisfies the proof-derived 2,000-byte margin and
approved at-most-22,184-byte objective. Its mutable measurement is owned only by
the bytecode proof linked above.

## Future Core Dependency

Issue `#667` requires the actual restricted Core metadata-refresh emitter
implementation used by its permissionless refresh-plan continuation. The
permanent target already pins:

- `emitMetadataUpdate(uint256,bytes32)` (`0xb826aa0c`);
- `emitBatchMetadataUpdate(uint256,uint256,bytes32)` (`0x908c18bd`);
- `lastAllocatedTokenId()` (`0x254b22bc`);
- canonical `IStreamFinalityRecoveryCore` ERC-165 ID `0xb5c73a01`, the XOR of
  those last two selectors;
- standard ERC-4906 `MetadataUpdate` / `BatchMetadataUpdate`; and
- `StreamMetadataRefresh(uint16,bytes32,uint256,uint256)`.

Current Core source implements those restricted selectors and their ERC-165
advertisement; focused tests and the runtime measurement include them. Do not
implement `#667`'s registry lifecycle or `#670`'s artist/royalty satellites in
this lane. The merge handoff must report the emitter selector/event ABI,
caller/range validation, measured runtime, and release-artifact overlap.

The #654 conformance proof must also show `supportsInterface(IERC165) == true`,
`supportsInterface(0xb5c73a01) == true`, and
`supportsInterface(0xffffffff) == false`, plus a real batch-emitter execution
path. A fallback-only target is nonconformant. Issue #667 owns the fail-closed
constructor probe and registry consumer. No production candidate or
completeness claim follows from the source seam alone.

## Maturity Guard

The protocol remains pre-audit and not production-ready. This work may define a
target or add evidence; it must not make a deployment or readiness claim.

## Current Evidence

- `python -u scripts/test_mint_manager_domain_constants.py` exits `0` with
  `56/56` tests passing in `152.951` seconds. The direct operation-identity
  checker also exits `0`. The Proposed ledger ABI now carries explicit
  collection and phase identity, has selector `0x82e8f383`, and independently
  loads current policy state even when the counter array is empty.
- The checker now scans all ten loaded normative documents for the
  sale-authorization assignment and mirror rows, every target event
  declaration, and every event-topic mirror. Exact duplicate, conflict,
  relocation, wrong-column, and outside-owner mutations fail with stable,
  sorted path diagnostics.
- The checksum generator computes the recursive first-party Python AST import
  closure rooted at the six canonical release-tail generators plus the offline
  verifier. The reviewed closure is exactly 20 runtime files plus eight focused
  tests. Its narrow dependency grammar allows ordinary static imports plus
  direct literal `importlib.import_module` and `__import__` forms; importer
  escapes and alternate loaders (`exec`/`eval`/`compile`, `runpy`,
  `importlib.util`/`machinery`, `exec_module`, and `load_module`) fail closed.
- Verifier tests reject independent or coordinated deletion, substitution,
  corruption, post-bundle mutation, symlink/reparse redirection, broad
  directory substitution, and removal of a non-root transitive runtime from
  both checksum indexes and disk.
- The canonical six-step release tail was regenerated exactly once in the
  documented order. Structural checksum tests pass `55/55`, verifier tests pass
  `47/47`, release-manifest tests pass `25/25`, and signed-tag integration
  passes `14/14`; every generator check mode and offline verification pass. The
  committed canonical outputs contain exactly 232 unique configured paths,
  394 `SHA256SUMS` records, 394 JSON records, the exact 20-file runtime closure,
  eight focused tests, and canonical coverage policy.
- Markdown link tests/check, changelog gate, Python compilation, and Windows
  CRLF-aware whitespace validation pass after the repair.
- A fresh authoritative Windows `scripts/check.ps1` gate exited `0` in
  `2,341.3` seconds (`2026-07-24T20:19:51.9187786Z` through approximately
  `2026-07-24T20:58:53.2187786Z`). One wrapper tree was preserved to terminal;
  all Forge, release-artifact, rehearsal, verifier, and policy stages passed.

## Open Decisions

- ADR 0018 is Accepted. The current corrective diff implements its atomic
  manager/ledger/Core operation-identity cutover but remains unmerged until the
  exact corrective head passes latest-head review and CI.
- Exact typed primary settlement, hostile callback handling, and
  execution-ID-bound repeated-sale replay remain ADR 0019 / #694 production
  blockers; operation-root uniqueness does not close them.
- Draft-PR publication is authorized for the exact validated corrective head.
  Merge remains gated on latest-head CI and resolved actionable review threads.

## Current Shared-Path Inventory

The exact corrective PR diff against base
`0bc295d845e556ebb98e4fe59d891434a11072c9` contains 101 paths: the 32
non-snapshot source/test/documentation paths reviewed by CodeRabbit plus 69
deterministic snapshot, deployment-evidence, and release-artifact paths. The
historical 26-path pre-implementation inventory below is retained only as the
earlier ADR 0018 planning baseline:

- `CHANGELOG.md`
- `docs/adr/0018-batch-operation-root-and-token-identity.md`
- `docs/launch-conformance-matrix.md`
- `docs/mint-policy-and-accounting.md`
- `docs/revenue-splits-and-royalties.md`
- `docs/stream-sales-and-auctions.md`
- `docs/tooling.md`
- `ops/workstreams/core-mint-critical-path/active-context.md`
- `ops/workstreams/core-mint-critical-path/run-log.md`
- `scripts/check_mint_manager_domain_constants.py`
- `scripts/check_signed_release_tag.py`
- `scripts/generate_release_checksums.py`
- `scripts/test_mint_manager_domain_constants.py`
- `scripts/test_release_checksums.py`
- `scripts/test_release_manifest.py`
- `scripts/test_signed_release_tag.py`
- `scripts/test_verify_release_artifacts.py`
- `scripts/verify_release_artifacts.py`
- `release-artifacts/latest/risk-register.json`
- `release-artifacts/latest/release-notes.json`
- `release-artifacts/latest/release-notes.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/bytecode-release-proof.json`
- `release-artifacts/latest/release-candidate-lockfile.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

## Next Actions

1. Hand the exact 26-path diff, unchanged reviewed-source hashes, canonical
   232/394 release proof, and authoritative gate result to final readback.
2. After final publication authorization, create one visible corrective commit,
   push it, update draft PR `#695`, resolve review threads with evidence, and
   request one incremental CodeRabbit review.

The later `#672` and `#654` implementation PRs form a separate release train;
do not stack them on or fold them into this ADR/spec/checker PR.

A quiet ten-minute task heartbeat named
`Resume 6529Stream #688 after upstream merges` monitored the serialized
upstream gate and became obsolete when the coordinator confirmed merged
`#689`.

Historical blocker state: three consecutive audits previously found
`origin/main` at `b4af30a5`, PR `#687` open, and no `#689` PR. Coordinator
confirmation of the `#687` and `#689` merges resumed the workstream.
