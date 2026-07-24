# Active Context

## Current Slice

- Issue: `#688`
- Branch: `codex/issue-688-operation-identity`
- Baseline at branch creation:
  `b4af30a58c22f79bafad241c6e4fab7a4a76063b`
- Current rebased base:
  `06f36150c4b5be05851f8081c520e98a6703a0c3`
- Current branch commit after the first upstream rebase:
  `d6eefe1f4d3a0dc2be586cea42d8a7fb594fb327`
- Intended result: a focused ADR and checked specification that pin one
  manager batch operation root, one per-token operation ID for each batch
  element, ledger-owned manager-scoped root replay, exact event/ABI ownership,
  single-step identity, rollback requirements, and the atomic implementation
  cutover that permits later Core lifetime replay-state removal.

## Integration Gate

The fixed shared release-input train is
`#687 -> #689 -> #688 -> #690 -> #658`. PR `#687` merged to `origin/main`
at `06f36150c4b5be05851f8081c520e98a6703a0c3`. The immediate actions are:

1. preserve the current #688 draft in an issue-scoped commit;
2. rebase onto `06f36150` and reconcile the governed inventory without
   importing another worktree;
3. regenerate the governed-inventory-dependent surfaces required at this
   intermediate state;
4. do not publish while `#689` remains unmerged;
5. after `#689` merges, rebase again, add ADR 0018 to the canonical
   manifest/checksum source inventories with tests, declare exact shared paths,
   regenerate the canonical dependent tail, and run the full gate.

Issue `#690` follows this first `#688` ADR/spec/checker slice with its own
fail-closed/schema work. Issue `#658` is downstream of both slices for final
generated-release evidence.
The coordinator must not let `#658` finalize its release chain from a base that
omits merged `#688`. Report the complete changed-path inventory, especially
`CHANGELOG.md`, maturity/spec/tooling inputs, roadmap/backlog inputs, canonical
generator/test inventory changes, and every regenerated release artifact.

## Sequencing Guard

Do not begin `#672` until the coordinator confirms the `#688` spec slice has
merged. Do not begin `#654` until the required `#672` predecessor state has
merged.

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

- Focused operation-identity checker and nine negative/positive unit tests pass.
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
  release-impact text is corrected; generator/test changes and artifact
  regeneration wait for the `#687` rebase because those files overlap.
- Meta-manager ordering requires merged `#688` upstream of `#658` final
  release-chain regeneration. The coordinator handoff must carry every
  release-input and shared-doc path.
- After rebasing merged `#687`, the focused operation checker, all 32 governed
  parameter inventory tests/check, Markdown/changelog/whitespace checks, every
  six-step release-tail test/check, and the offline release verifier pass.
  Intermediate artifacts were regenerated in canonical order against the
  governed inventory; ADR 0018 inventory wiring remains intentionally deferred
  until the post-`#689` rebase.

## Open Decisions

- No protocol decision is open for the spec slice.
- PR publication remains gated on coordinator-confirmed merge of `#687` and
  `#689`, a fresh `origin/main` rebase, exact shared-path declaration,
  canonical artifact regeneration as required by the repository gates, and
  final validation.

## Current Shared-Path Inventory

Refresh this list after the mandatory `#687` / `#689` rebase and again before
publication:

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
- `scripts/test_mint_manager_domain_constants.py`
- `release-artifacts/latest/risk-register.json`
- `release-artifacts/latest/release-notes.json`
- `release-artifacts/latest/release-notes.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/bytecode-release-proof.json`
- `release-artifacts/latest/release-candidate-lockfile.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

## Next Actions

1. Monitor the `#687 -> #689` integration gate without changing either branch.
2. After both merge confirmations, fetch/rebase, reconcile shared surfaces, add ADR
   0018 to manifest/checksum inventories with tests, regenerate the canonical
   dependent artifact tail, and rerun the full gate.
3. Refresh and declare the exact shared-path inventory.
4. Commit, push, open a draft PR, request CodeRabbit, and iterate CI/review to a
   review-ready handoff.

The later `#672` and `#654` implementation PRs form a separate release train;
do not stack them on or fold them into this ADR/spec/checker PR.

A quiet ten-minute task heartbeat named
`Resume 6529Stream #688 after upstream merges` monitors the train. After the
coordinator resumed the workstream on merged `#687`, it may monitor the
remaining `#689` gate but must not create unrelated edits or claim progress
while that dependency remains open.

Historical blocker state: three consecutive audits previously found
`origin/main` at `b4af30a5`, PR `#687` open, and no `#689` PR. Coordinator
confirmation of the `#687` merge resumes the workstream. The next external gate
is now `#689`.
