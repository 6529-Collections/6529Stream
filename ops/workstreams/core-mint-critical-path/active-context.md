# Active Context

## 2026-07-26 Shipping Resumption

- Explicit protocol-owner shipping mandate releases this workstream to own
  `#672`, `#671`, and `#654` through review-ready PRs and coordinator-managed
  merge/closure.
- Active issue: `#672`.
- Active branch: `codex/issue-672-post-entropy-completion-gas`.
- Final publication base and current `origin/main`:
  `513bd7e079eafe109df6ae1ae21bfbca6fec6786` after merged PR `#701`.
  The reviewed #672 source/spec/test bytes were preserved through the complete
  shared-tail sequence; only the exact combined release-tool binding and
  deterministic generated release files changed during final reconciliation.
- Current committed source head:
  `274f3a67ed03fb946fd4e74e482506602c2f9ca1`. The final generated tail and
  this terminal-state context remain to be committed together before
  publication.
- #672 is a zero-`StreamCore`-delta target-fixture/spec/measurement slice. It
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
- Size control is unchanged: current transitional Core is 24,152 bytes; every
  pre-#654 slice is bytecode-neutral, and every Core-changing slice must prove
  an exact net-negative runtime. The complete target must be at most 22,576
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
- After #672 merges, prioritize the reopened #688 atomic operation-root
  Solidity/test/as-built cutover before #671 and #654. Proposed ADR 0018 did
  not implement the source cutover, and #670 depends on the prepared-operation
  identity and `isManagerOperationRootUsed` seam.

## Current Slice

- Issue: `#672`
- Branch: `codex/issue-672-post-entropy-completion-gas`
- Base: `513bd7e079eafe109df6ae1ae21bfbca6fec6786`
- Result: a checksum-bound planning measurement and target fixture for the
  post-entropy EOA completion tail, with zero StreamCore bytecode delta. It
  does not claim that the current Core implements the admission boundary or
  that #684 candidate measurement binding exists.
- Publication state: final authoritative local validation is green. Record the
  terminal milestone, run lightweight workstream-only checks, commit, push,
  open the draft PR, and obtain CI and substantive CodeRabbit review.
- Closure state: merge the #672 evidence PR first, but keep issue #672 open
  until #654 implements and remeasures the actual entropy-coordinator cutover.

## Next Slice

- Issue: reopened `#688`.
- Required result: implement the Proposed ADR 0018 atomic operation-root
  source cutover in Solidity, Foundry tests, and as-built documentation,
  including the prepared-operation identity and
  `isManagerOperationRootUsed` seam needed by #670.
- Keep #671 and #654 separate; #671 follows #688, and #654 remains the final
  entropy-coordinator Core implementation and remeasurement slice.

## Integration Gate

The fixed shared integration train is
`#692 -> #688 -> #690 -> #669 -> #694 -> #691 -> #693 -> #670 -> #656 -> #677 -> #658`.
PR `#692` for issue `#689` merged at
`1031ffec0c2c7cfb0525d97790a66ecabfd8fe17`.
The isolated #688 branch is rebased on that exact main commit without importing
another worktree. The remaining publication work is to:

1. keep the #689 canonical risk-tracker provenance correction intact;
2. bind ADR 0018 into the release-manifest and checksum source inventories;
3. close the three verified post-publication-review P1 families: stale
   current/bound policy-hash mirrors, global cross-document normative ownership,
   and deterministic release-tool checksum trust closure;
4. pass focused source/checker review before any further regeneration;
5. after independent GO, regenerate the canonical dependent tail exactly once
   in documented order and run a fresh authoritative Windows gate; and
6. declare the exact shared paths and head before updating the draft PR.

Issue `#690` follows this first `#688` ADR/spec/checker slice with its own
fail-closed/schema work. Issues `#669`, `#694`, `#691`, `#693`, `#670`, `#656`,
and `#677` remain serialized downstream before `#658` final generated-release
evidence.
The coordinator must not let `#658` finalize its release chain from a base that
omits merged `#688`. Report the complete changed-path inventory, especially
`CHANGELOG.md`, maturity/spec/tooling inputs, roadmap/backlog inputs, canonical
generator/test inventory changes, and every regenerated release artifact.

## Sequencing Guard

Do not begin `#672` until the coordinator confirms the `#688` spec slice has
merged. Do not begin `#654` until the required `#672` predecessor state has
merged.

Prior extraction reached a measured 21,792-byte Core runtime. The later
manager/prepared-mint slice produced the current 24,152-byte transitional build
while legacy mint behavior remained live; 24,152 is later duplication, not the
pre-manager extraction baseline. The #672 slice must be either
spec/test/measurement-only with zero Core delta, or pair any
admission/completion-gas Core addition with a measured removal and prove an
exact before/after net-negative runtime. The complete target must be at most
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
