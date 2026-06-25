# Active Context

## Current Goal

Finish the v1 contract roadmap autonomously, one topic at a time. For each
topic: plan, implement, use parallel OpenRouter reviews, iterate locally, open a
regular PR, request CodeRabbit when available, resolve or document review-bot
feedback, merge when clean, then continue.

## Current Topic

`StreamMintManager` phase policy and execution integration.

The current branch should implement the manager-side policy and execution layer
that builds on the merged Core hook and ledger foundations:

- phase policy/configuration surfaces in `StreamMintManager`;
- manager-side binding to `StreamMintLedger` policy registration and
  consumption;
- launch-safe static counter execution only;
- canonical counter value-key derivation;
- replay, cap, rollback, and prepared-mint interaction coverage;
- focused tests that prove failed manager execution does not consume
  authorizations or mutate ledger counters.

Token-level revenue snapshots, ERC-20 auction bidding, custom gates, resolver
modes, callable nullifiers, and royalty resolver integration remain follow-up
topics unless a smaller reviewed boundary is needed for this manager slice.

## Branch State

- Manager skill PR #621 merged.
- Manager skill follow-up PR #622 merged.
- V1 outside-Core scope reconciliation PR #623 merged and closed issue #624.
- Split factory/wallet skeleton PR #626 merged and issue #625 is closed
  completed.
- Asset policy and ERC-20 split-wallet PR #628 merged and issue #627 is closed
  completed.
- Revenue resolver and primary-sale settlement adapters PR #630 merged and
  issue #629 is closed completed.
- Core mint-manager hooks PR #633 merged and issue #631 is closed completed.
- Ledger foundation PR #635 merged and issue #634 is closed completed.
- Current topic branch: `codex/mint-manager-phase-execution`.
- Current topic issue: https://github.com/6529-Collections/6529Stream/issues/636.
- Current topic PR: TBD.
- Current draft status: starting from merged `main`; implementation not yet
  drafted.

## Subagent Findings To Carry

- ADR 0008 had stale native-ETH-only primary settlement language.
- Launch conformance gate wording needed approved-standard ERC-20 settlement at
  the gate level.
- Auction wording needed to clarify that the ERC-20 primary settlement launch
  requirement does not automatically launch ERC-20 auction bidding.
- Metadata docs used `StreamPreservationRegistry` while the roadmap standardized
  on `StreamPreservationRecords`.
- The Core prepared-mint hook slice should avoid routing existing Drops through
  the manager until the later policy/ledger PR owns that migration.
- Local Solidity review for the CON-012 draft found two blockers: durable
  prepared state needed an abort/recovery path, and inherited ERC-721
  approval/transfer surfaces needed to reject while a prepared mint is pending.
  The branch now includes manager-only abort, stale-callback rejection after
  abort, and approval/transfer guards.
- Local docs/release review for the CON-012 draft required an explicit
  size-budget exception note and current run-state wording before PR; the
  branch now carries both, with full local validation passing afterward.

## Validation Bar

- Local docs/link/changelog/release artifact checks pass.
- Generated release artifacts are current.
- OpenRouter reviewers return no blocking issues, or all blockers are patched
  and the review loop is repeated.
- PR review bots have no unresolved blocking findings, or deferrals are
  documented with rationale.
- Current local validation target includes focused `StreamMintManager` and
  ledger integration tests, `forge build`, `forge test -vvv`, production
  `via-ir` size build, deployment rehearsal, release/deployment artifact
  checks, `python scripts/check_contract_size_budget.py`, `codex-diff-check`,
  and the full Windows `scripts\check.ps1` wrapper before PR/merge.
