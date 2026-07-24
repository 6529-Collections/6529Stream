# Active Context

## Current Slice

- Issue: `#688`
- Branch: `codex/issue-688-operation-identity`
- Baseline at branch creation:
  `b4af30a58c22f79bafad241c6e4fab7a4a76063b`
- Current rebased base:
  `1031ffec0c2c7cfb0525d97790a66ecabfd8fe17`
- Current committed draft-PR head:
  `c39b178b9fb7d4ed92816c4ff11f08eac589d43c`
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
