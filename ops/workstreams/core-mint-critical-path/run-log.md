# Run Log

## 2026-07-24

- Created the unbudgeted long-running goal for `#688 -> #672 -> #654`.
- Confirmed this isolated worktree was clean and detached at current
  `origin/main`, then created `codex/issue-688-operation-identity`.
- Read the repository operating guide, autonomous-manager and PR contracts,
  issues `#688`, `#672`, and `#654`, roadmap/backlog/maturity/tooling
  surfaces, and the applicable mint, revenue, architecture, conformance, and
  ADR material.
- Confirmed coordinator ownership boundaries: this workstream is the sole
  implementation owner for the lane and must not edit governance/gas issues
  `#684`, `#685`, `#669`, `#671`, or `#673`.
- Confirmed PR `#687` is still open and overlaps shared planning, maturity,
  tooling, mint/revenue/entropy specs, and canonical release artifacts.
- Recorded the `#688` contradiction: one ledger call consumes a batch; the
  current manager derives the root only after ledger consumption; the ledger
  stores neither root nor token operation ID; and Core currently compensates
  with unbounded lifetime token-operation replay state.
- Selected the spec direction for review: one root per manager batch, one
  unique operation ID per token, manager-scoped durable root replay in the
  ledger, token-scoped Core prepare locks only, and explicit identity ownership
  for single-step, prepared, resolver, settlement, and entropy boundaries.
- Coordinator dependency update: `#667` and `#670` remain forbidden from
  modifying Core. This lane owns only their required Core seams. The real
  restricted ERC-4906 single/batch refresh emitters are therefore reserved for
  the `#654` complete-target sizing stage, where their already-pinned selectors,
  events, caller/range checks, runtime-bytecode delta, and generated-artifact
  overlap must be reported before the 2,000-byte margin can be finalized.
- Drafted ADR 0018 and the owning mint/revenue/architecture/conformance
  specification updates with exact root/token cardinality, ledger ABI/replay,
  single-step identity, production event signatures/topics, rollback
  requirements, atomic cutover order, and target-versus-as-built boundaries.
- Extended the mint-manager domain checker and its focused tests. Independent
  checker review identified missing return/read ABI and unindexed event-field
  guards; both were added. Nine focused tests, the committed checker, Python
  compilation, Markdown tests/check, changelog gate, and CRLF-aware whitespace
  validation pass.
- Independent release review confirmed that this slice must regenerate the
  risk register, release notes, manifest, bytecode proof for release linkage,
  lockfile, and checksums after rebasing merged PR `#687`. It also identified
  required ADR 0018 coverage in the manifest/checksum source inventories.
  Those overlapping generator/test changes remain deliberately deferred until
  the integration gate lands.
- Meta-manager dependency update: `#688` is upstream of `#658`'s final
  generated-release chain because both touch shared changelog, maturity,
  tooling, roadmap, backlog, and release inputs. The coordinator handoff must
  enumerate the full changed-path set and prevent `#658` final regeneration
  from using a base that omits merged `#688`.
- Coordinator fixed the exact shared release-input train as
  `#687 -> #689 -> #688 -> #690 -> #658`. Publication now waits for both
  `#687` and `#689`, followed by a fresh `origin/main` rebase and exact
  shared-path declaration. This first `#688` PR remains the focused
  operation-identity ADR/spec/checker slice; `#672` and `#654` use a separate
  later implementation train.
- Resolved every independent protocol-review finding: the single-step adapter
  now compares manager-returned identities with its pre-deposit preview;
  obsolete shared-operation-ID language and stale step references are removed;
  prepared and single-step completion events are path-specific; target
  entrypoint mirrors are exact; and ADR 0008 explicitly delegates to ADR 0018.
- Sent the integration coordinator an interim exact-path inventory, validation
  evidence, fixed train/dependency report, no-Solidity/as-built-impact note, and
  the deferred `#667` Core emitter seam. The inventory must be refreshed after
  rebasing both upstream merges.
- With `#687` still running its long rehearsal and no `#689` PR published,
  attached the quiet ten-minute task heartbeat
  `Resume 6529Stream #688 after upstream merges`. It resumes only after both
  merges and makes no speculative or cross-worktree edits while waiting.
- Three consecutive authoritative gate audits found the same external state:
  `origin/main` at `b4af30a5`, PR `#687` open with Foundry smoke/rehearsal
  running, and no PR for `#689`. The long-running goal therefore reached its
  strict formal-blocker threshold. The #688 branch and uncommitted source draft
  remain intact for coordinator-confirmed resumption.
- Coordinator confirmed PR `#687` merged to `origin/main` at
  `06f36150c4b5be05851f8081c520e98a6703a0c3`, resuming the blocked workstream.
  Rebase and governed-inventory reconciliation are authorized now; publication
  remains gated on `#689`, followed by a second rebase and final inventory,
  artifact, and full-gate pass.
