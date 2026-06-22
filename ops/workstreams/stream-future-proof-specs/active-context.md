# Active Context

## Current Goal

Enhance the Stream specs into a world-class, future-proof design package for
payments, royalties, metadata/rendering, and entropy over a 50+ year contract
life. Send the specs plus relevant contract context to GPT 5.5 Pro, Opus 4.8,
and GLM 5.2 through OpenRouter, incorporate feedback, iterate until all three
external reviewers and Codex are comfortable, then open a PR and resolve review
feedback before merge.

## Current Baseline

- Current PR branch: `codex/future-proof-metadata-delta`.
- Branch was created from current `origin/main` to keep the PR diff focused on
  the post-merge metadata and review-evidence delta.
- Revenue/royalty feedback from the earlier loop is summarized in this
  workstream's run log and incorporated into the proposed specs.
- Entropy specs were recently expanded with NextGen/ADR 0005 lessons, provider
  epochs, stale request handling, and adapter reentrancy requirements.

## Owned Paths

- `docs/*.md`
- `docs/adr/*.md`
- `ops/workstreams/stream-future-proof-specs/*.md`

## Forbidden Paths

- Unrelated dirty smart-contract, tooling, CI, README, and skill files unless
  the user explicitly expands scope.
- Credential files or secret-bearing local config.

## Validation Bar

- External review record from all three requested models is present.
- All blocking external-review feedback has been addressed.
- Final external-review state:
  - GPT-5.5 Pro: `APPROVE` in iteration 8 final tiny metadata-delta audit.
  - Opus 4.8: `APPROVE` in iteration 8 final tiny metadata-delta audit.
  - GLM 5.2: `APPROVE` in iteration 8 final tiny metadata-delta audit.
- Local markdown/sanity checks and `codex-diff-check` clean for touched files.
- PR diff contains only intended spec/review files.

## Next Actions

1. Run final local whitespace/sanity checks for touched docs and workstream
   files.
2. Stage only intended spec/workstream files and leave unrelated dirty files
   untouched.
3. Commit, push, open PR, address reviewbot feedback, and merge when clean.
