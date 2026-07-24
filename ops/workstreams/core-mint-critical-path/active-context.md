# Active Context

## Current Slice

- Issue: `#688`
- Branch: `codex/issue-688-operation-identity`
- Baseline at branch creation:
  `b4af30a58c22f79bafad241c6e4fab7a4a76063b`
- Current rebased base:
  `1031ffec0c2c7cfb0525d97790a66ecabfd8fe17`
- Current branch commit after the `#689` rebase:
  `c92eb1e47a32563f91578de98258f23668693144`
- Intended result: a focused Proposed ADR and checked specification for one
  manager batch operation root, one per-token operation ID for each batch
  element, ledger-owned manager-scoped root replay, exact event/ABI ownership,
  single-step identity, rollback requirements, and the atomic implementation
  cutover that permits later Core lifetime replay-state removal. The slice does
  not accept the ADR, close #688, or claim settlement/readiness completion.

## Integration Gate

The fixed shared integration train is
`#692 -> #688 -> #690 -> #669 -> #694 -> #691 -> #693 -> #670 -> #656 -> #677 -> #658`.
PR `#692` for issue `#689` merged at
`1031ffec0c2c7cfb0525d97790a66ecabfd8fe17`.
The isolated #688 branch is rebased on that exact main commit without importing
another worktree. The remaining publication work is to:

1. keep the #689 canonical risk-tracker provenance correction intact;
2. bind ADR 0018 into the release-manifest and checksum source inventories;
3. repair every independent normative NO-GO finding and pass focused
   source/checker review before any further regeneration;
4. after independent GO, regenerate the canonical dependent tail in documented
   order and run the authoritative Windows gate; and
5. declare the exact shared paths and head before draft publication.

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

- Focused operation-identity checker and twenty-four negative/positive unit tests
  pass.
- Domain hashes, function selectors, return/read ABI semantics, event topic
  hashes, indexed masks, and all target event field names are checker-pinned.
- Markdown link tests/check, changelog gate, Python compilation, and Windows
  CRLF-aware whitespace validation pass.
- Independent checker review found two false-negative gaps; both were fixed and
  covered by new tests.
- Independent protocol review found single-step comparison observability,
  stale one-ID language, path-event mirroring, legacy ADR lineage, and call
  surface drift; all findings were fixed and checker-pinned where appropriate.
- Independent release review found the required risk-register and bytecode-proof
  release linkage plus ADR 0018 manifest/checksum inventory coverage. The
  release-impact text, generator inventories, and focused tests are corrected;
  independent repair review returned GO, and the canonical release tail was
  regenerated exactly once on explicit coordinator authorization.
- Meta-manager ordering requires merged `#688` upstream of `#658` final
  release-chain regeneration. The coordinator handoff must carry every
  release-input and shared-doc path.
- After rebasing merged `#687`, the focused operation checker, all 32 governed
  parameter inventory tests/check, Markdown/changelog/whitespace checks, every
  six-step release-tail test/check, and the offline release verifier pass.
  Intermediate artifacts were regenerated in canonical order against the
  governed inventory.
- After rebasing merged `#689`, focused source-inventory tests confirm ADR 0018
  is included in both the release-manifest governance-document inventory and
  checksum coverage policy.
- After the nine-item NO-GO repair, the operation checker and all 24 focused
  tests, both one-test ADR-inventory checks, all 25 release-manifest unit tests,
  all 16 Markdown-link tests, the Markdown checker, changelog gate, Python
  compilation, and CRLF-aware whitespace check pass.
- After the authorized regeneration, all six release-tail test/check stages
  pass, including all 28 release-checksum tests. Offline release verification
  passes with 379 checksum entries, 379 checksum-manifest records, 184 release-
  manifest file records, 123 bytecode-proof file records, and 16 lockfile file
  records.
- The fresh authoritative Windows gate completed with exit `0` in 2,137.8
  seconds. This validation result is evidence for the draft review slice only;
  it is not an acceptance, deployment, release, or readiness claim.

## Open Decisions

- ADR 0018 remains Proposed only. Its manager operation boundary has completed
  the nine-item NO-GO repair. Independent checker, protocol, and release
  re-reviews are clean; the canonical release tail and full Windows gate are
  green. The ADR cannot be described as accepted.
- Exact typed primary settlement, hostile callback handling, and
  execution-ID-bound repeated-sale replay remain ADR 0019 / #694 production
  blockers; operation-root uniqueness does not close them.
- PR publication remains gated on the final durable-context readback, exact
  shared-path/head/gate-result handoff, and explicit coordinator publication
  authorization.

## Current Shared-Path Inventory

This exact list is refreshed against the post-`#692` base after canonical
regeneration and the full Windows gate:

- `CHANGELOG.md`
- `docs/adr/0008-revenue-splits-and-royalty-resolver.md`
- `docs/adr/0018-batch-operation-root-and-token-identity.md`
- `docs/adr/README.md`
- `docs/known-blockers.md`
- `docs/launch-conformance-matrix.md`
- `docs/launch-v1-target-architecture.md`
- `docs/mint-policy-and-accounting.md`
- `docs/revenue-splits-and-royalties.md`
- `docs/status.md`
- `docs/stream-sales-and-auctions.md`
- `docs/tooling.md`
- `ops/EXECUTION_BACKLOG.md`
- `ops/ROADMAP.md`
- `ops/workstreams/core-mint-critical-path/README.md`
- `ops/workstreams/core-mint-critical-path/active-context.md`
- `ops/workstreams/core-mint-critical-path/run-log.md`
- `scripts/check_mint_manager_domain_constants.py`
- `scripts/generate_release_checksums.py`
- `scripts/generate_release_manifest.py`
- `scripts/test_mint_manager_domain_constants.py`
- `scripts/test_release_checksums.py`
- `scripts/test_release_manifest.py`
- `release-artifacts/latest/risk-register.json`
- `release-artifacts/latest/release-notes.json`
- `release-artifacts/latest/release-notes.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/bytecode-release-proof.json`
- `release-artifacts/latest/release-candidate-lockfile.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

## Next Actions

1. Prove the durable-context-only correction does not change the regenerated
   release tail, then report the exact final diff/head/full-gate result.
2. Wait for explicit coordinator publication authorization.
3. After authorization, commit, push, open a draft PR, request CodeRabbit, and
   iterate CI/review to a review-ready handoff.

The later `#672` and `#654` implementation PRs form a separate release train;
do not stack them on or fold them into this ADR/spec/checker PR.

A quiet ten-minute task heartbeat named
`Resume 6529Stream #688 after upstream merges` monitored the serialized
upstream gate and became obsolete when the coordinator confirmed merged
`#689`.

Historical blocker state: three consecutive audits previously found
`origin/main` at `b4af30a5`, PR `#687` open, and no `#689` PR. Coordinator
confirmation of the `#687` and `#689` merges resumed the workstream.
