# Active Context

## 2026-07-27 Atomic Operation-Identity Cutover

- The explicit protocol-owner shipping mandate releases this workstream to
  complete `#688`, `#671`, and `#654` through validated PRs and merge.
- Active issue: reopened `#688`.
- Active branch: `codex/issue-688-operation-root-cutover`.
- Final publication base and current `origin/main`:
  `0bc295d845e556ebb98e4fe59d891434a11072c9` after merged PR `#685`.
- Current committed Solidity checkpoint:
  `8b7ce86396fa943ef332b6831e79a998237285a9`. The as-built
  status/size/checker reconciliation is committed; refreshed Slither evidence
  and canonical generated artifacts remain to be committed before publication.
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
- #654 remains the final Core slice. Missing entropy-coordinator, metadata
  router, restricted ERC-4906 emitters, and interface-support seams are work to
  implement and measure there rather than reasons to idle now.
- Size control is unchanged: the atomic operation-identity cutover measures
  24,135 bytes, a 17-byte reduction from the 24,152-byte pre-cutover
  transitional baseline. Every pre-#654 Core-changing slice must prove an exact
  net-negative runtime. The complete target must be at most 22,576
  bytes for the exact 2,000-byte EIP-170 margin; the objective is at most
  22,184 bytes. The historical 21,792-byte low-water mark is non-additive.
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
  repeat-sale correlation remain ADR 0019/#694 blockers, and #654 still owns
  the complete Core finality/headroom seam.

## Current Slice

- Issue: reopened `#688`.
- Branch: `codex/issue-688-operation-root-cutover`.
- Base: `0bc295d845e556ebb98e4fe59d891434a11072c9`.
- Solidity checkpoint: `8b7ce86396fa943ef332b6831e79a998237285a9`.
- Result: the atomic operation-root source cutover is implemented across the
  manager, ledger, Core hooks, fixed libraries, Foundry tests, checker, and
  as-built documentation. The current via-IR diagnostic measures `StreamCore`
  at 24,135 bytes, 17 bytes smaller than the 24,152-byte pre-cutover baseline.
- Publication state: focused source reconciliation and validation are in
  progress. Freeze the reviewed source, regenerate canonical artifacts and the
  release tail once, run one authoritative Windows gate, then publish and
  obtain CI plus substantive CodeRabbit review.
- Static-analysis state: the exact full Slither 0.11.5 replay against the
  frozen Solidity checkpoint introduces no new first-party production
  High/Medium finding. Explicit initialization and narrowly documented
  fully-assigned paths remove two prior `uninitialized-local` rows, leaving 28
  Open rows (3 High and 25 Medium): one confirmed gap, five design-review
  rows, and 22 pending dispositions. No remaining row is accepted or marked
  false positive.
- Closure state: do not claim typed settlement/repeat-sale completion or
  production readiness. ADR 0019/#694 remains the typed primary-settlement and
  repeated-identical-sale blocker; #654 remains the final complete-Core
  finality/headroom implementation and measurement slice.

## Next Slice

- Issue: `#671`.
- Required result: implement the shared `ROYALTY_RETURN_GAS_BUFFER` Core-read
  semantics and proof without editing #684 governance evidence or adding a 23rd
  governed gas parameter.
- Keep #654 separate; it remains the final entropy-coordinator Core
  implementation and complete target remeasurement slice.

## Integration Gate

The active Core/mint order is `#688 -> #671 -> #654`. The #688 publication
must preserve the accepted ADR 0018 normative fields, current/bound policy-hash
split, manager-scoped ledger replay, zero generic callback surface, exact
selector/typehash/topic rows, and as-built preimage attribution. It must also:

1. retain the #672 zero-Core-delta evidence and 128,886-gas planning snapshot;
2. prove the #688 Core change is exactly net-negative on the final base;
3. preserve ADR 0019/#694 settlement and repeated-sale blockers;
4. regenerate canonical source artifacts before the six-step release tail;
5. pass focused Foundry, exact Slither, offline release verification, and one
   authoritative Windows gate; and
6. report the complete changed-path inventory and exact final head before merge.

## Sequencing Guard

PR #704 merged the #672 planning/measurement slice. Do not begin #654's final
Core implementation until the atomic #688 cutover and #671 shared-buffer slice
have merged.

Prior extraction reached a measured 21,792-byte Core runtime. The later
manager/prepared-mint slice produced the 24,152-byte pre-cutover transitional
build while legacy mint behavior remained live; 24,152 is later duplication,
not the pre-manager extraction baseline. The atomic operation-identity cutover
retires the duplicate mint path and lifetime Core replay map and measures
24,135 bytes, a 17-byte net reduction. The #672 slice was
spec/test/measurement-only with zero Core delta. The complete target must be at most
22,576 bytes to preserve the exact 2,000-byte production margin, with
restoration to the approved at-most-22,184-byte baseline as the objective.
Historical scratch deltas are not additive savings.

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

Current Core source does not yet implement those restricted selectors. Keep
that source/ABI/bytecode seam in the `#654` complete-target measurement stage,
after `#672`, because adding the real emitter spends Core runtime and must be
compiled before proving the exact 2,000-byte production margin. Do not
implement `#667`'s registry lifecycle or `#670`'s artist/royalty satellites in
this lane. Before finalizing `#654`, report the emitter's selector/event ABI,
caller/range validation, measured runtime delta, and release-artifact overlap
to the coordinator.

The #654 conformance proof must also show `supportsInterface(IERC165) == true`,
`supportsInterface(0xb5c73a01) == true`, and
`supportsInterface(0xffffffff) == false`, plus a real batch-emitter execution
path. A fallback-only target is nonconformant. Issue #667 owns the fail-closed
constructor probe and registry consumer and may merge its satellite source
without Core edits, but no production candidate or completeness claim can
precede the #654 Core seam.

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

- ADR 0018 remains Proposed only. The current corrective diff and generated
  tail are green but still await final exact-diff readback and explicit
  publication authorization. The ADR cannot be described as accepted.
- Exact typed primary settlement, hostile callback handling, and
  execution-ID-bound repeated-sale replay remain ADR 0019 / #694 production
  blockers; operation-root uniqueness does not close them.
- Draft-PR update and publication remain gated on exact shared-path/head
  handoff and explicit coordinator publication authorization.

## Current Shared-Path Inventory

The exact 26-path diff against the post-`#692` base after canonical
regeneration and the full Windows gate is:

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
