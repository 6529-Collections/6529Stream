# Active Context

## Current Goal

Finish the v1 contract roadmap autonomously, one topic at a time. For each
topic: plan, implement, use parallel OpenRouter reviews, iterate locally, open a
regular PR, request CodeRabbit when available, resolve or document review-bot
feedback, merge when clean, then continue.

## Current Topic

`StreamMintLedger` static counter accounting foundation.

The current branch should implement the first outside-Core durable mint
accounting slice needed by the v1 mint manager roadmap:

- `IStreamMintLedger` and `StreamMintLedger`;
- owner-managed authorized deployed-contract ledger writers;
- one active registered `policyHash` per `(manager, collectionId, phaseId)`;
- launch-safe static counter policies only;
- cap-checked monotonic counter consumption;
- authorization replay protection;
- reconstructable writer, policy, counter, context, and authorization events;
- focused tests for writer auth, policy registration, unsupported future modes,
  duplicate-key cap safety, replay, and rollback-before-mutation behavior.

Full mint manager phase policy, Core mint integration, routing Drops through the
manager, token-level revenue snapshots, ERC-20 auction bidding, custom gates,
resolver modes, callable nullifiers, and royalty resolver integration remain
follow-up topics.

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
- Current topic branch: `codex/mint-manager-ledger-foundation`.
- Current topic issue: https://github.com/6529-Collections/6529Stream/issues/634.
- Current topic PR: https://github.com/6529-Collections/6529Stream/pull/635.
- Current PR status: PR #635 is open for the ledger contract, interface,
  focused tests, deployment rehearsal wiring, release artifacts, and
  review-driven fixes. Opus, GPT-5.5 Pro, and GLM all returned visible review
  content with no P0/P1 blockers for the ledger-only static phase-counter
  scope. Final local validation passed with focused `StreamMintLedger` tests,
  `forge build`, full `forge test -vvv`, production via-IR size build, full
  Windows `scripts\check.ps1`, and `codex-diff-check`. CI and CodeRabbit review
  are in progress.

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
- Current local validation target includes focused `StreamMintLedger` tests,
  `forge build`, `forge test -vvv`, production `via-ir` size build,
  deployment rehearsal, release/deployment artifact checks,
  `python scripts/check_contract_size_budget.py`, `codex-diff-check`, and the
  full Windows `scripts\check.ps1` wrapper before PR/merge.
