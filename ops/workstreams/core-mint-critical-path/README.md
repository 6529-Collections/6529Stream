# Core/Mint Critical-Path Workstream

## Charter

Own the sequential `#688 -> #672 -> #654` Core/mint launch-conformance lane.
Each issue remains one review-ready draft PR, based on the then-current
`origin/main`, with no dependent implementation stacked on an unmerged PR.
The current shared release-input train is
`#692 -> #688 -> #690 -> #669 -> #694 -> #691 -> #693 -> #670 -> #656 -> #677 -> #658`;
the implementation lane remains separately serialized as `#688 -> #672 -> #654`.

## Reload Order

1. Read this charter.
2. Read `active-context.md` for the current branch, gate, evidence, decisions,
   and next actions.
3. Read `run-log.md` for durable milestones, reviews, and handoffs.
4. Re-read the current issue, `ops/ROADMAP.md`,
   `ops/EXECUTION_BACKLOG.md`, `docs/tooling.md`, and the relevant ADR/spec
   homes before editing.
5. Fetch `origin`, inspect branch/status, and verify the recorded baseline and
   integration gate before generating artifacts or publishing a PR.

## Scope

- `#688`: pin batch operation-root and per-token operation-ID semantics before
  Core lifetime replay storage can be removed.
- `#672`: prove and enforce post-entropy mint-completion gas after the required
  predecessor state merges.
- `#654`: recover measured `StreamCore` launch-conformance headroom while
  preserving the exact 2,000-byte production margin gate, including the real
  restricted single/batch metadata-refresh emitters required by `#667`.

## Owned Paths

The active issue determines the smallest exact set. This lane may own the
focused Core/mint contracts, interfaces, tests, ADR/spec/planning text,
checkers, canonical release generators, and generated evidence required by
`#688`, `#672`, or `#654`. Shared surfaces are changed only when the active
issue requires them and are reported to the coordinator.

## Boundaries

- Do not merge, deploy, release, perform live-chain actions, or claim readiness.
- Do not take ownership of governance/gas issues `#684`, `#685`, `#669`,
  `#671`, or `#673`.
- Do not absorb the finality-registry or artist/royalty satellite
  implementations owned by `#667` and `#670`; this lane owns only their
  required Core seams.
- Do not import changes from another worktree.
- Report Core ABI, release-artifact, and shared-surface overlap to the
  integration coordinator before handoff.

## Evidence Standard

- Tie every target semantic claim to an accepted ADR/spec and a checked
  normative surface; distinguish target behavior from current as-built
  artifacts.
- Run focused tests first, then the proportional repository validation ladder.
- Regenerate release evidence only through canonical generators in documented
  order from the final rebased source state.
- Preserve Solidity `0.8.19`, pre-audit/not-production-ready language, release
  reproducibility, and the exact 2,000-byte Core production-margin gate.
- Handoff must identify validation, dependencies, changed shared surfaces,
  Core ABI/bytecode implications, generated artifacts, and residual risks.

## Escalation Triggers

Escalate to the integration coordinator instead of improvising when a required
change enters the forbidden governance/gas lane, a predecessor PR is unmerged,
ADR numbering collides on `origin/main`, a target ABI or safety decision cannot
be resolved from accepted issue/spec evidence, canonical generation is
non-deterministic, or the measured complete Core target cannot preserve the
2,000-byte production margin. Merge, deployment, release, live-chain action,
and readiness claims always require authority outside this workstream.

## Integration Coordinator

Codex task `019f86dc-11c7-7ad2-8f6a-5125e1fb8de1` owns merge ordering and
confirms when a predecessor has landed.
