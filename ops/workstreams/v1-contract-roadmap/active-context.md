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
- Current draft status: local `StreamMintManager` implementation,
  deployment/release artifact wiring, docs, evidence hash refreshes, checked
  hash-domain coverage, focused validation, full Windows `scripts\check.ps1`,
  and `codex-diff-check` are complete. The changed fork deployment, fork
  ceremony, and fork randomizer evidence rows are marked `pending` with issue
  links #216/#219/#220 restored until this PR's updated artifact set is
  reviewed. Opus/GLM round-4 findings have been addressed: phase configuration
  is initial-only, executor removal/uncapped/unlimited batch/beneficiary-keyed
  counter tests were added, bytecode evidence prose was reconciled, and
  authorization/policy-hash trust boundaries were documented. The read-only
  local verifier returned no blockers and its optional hardening suggestions are
  now covered in the focused manager suite, which passes 36 tests. The latest
  full Windows wrapper pass is
  `C:\Users\Administrator\AppData\Local\Temp\6529stream-check-20260625-200854.log`
  and it reached the deployment-suite, standalone deployment, auction ceremony,
  and emergency redeployment rehearsal scripts successfully. Current production
  `via-ir` size output records `StreamCore` at 24,150 bytes with 426 bytes of
  EIP-170 margin and `StreamMintManager` at 16,812 bytes. Final post-fix
  OpenRouter review passed with Opus 4.8, GLM 5.2, and GPT-5.5 Pro at high
  reasoning; all three approve after the stale size-prose blocker was fixed.
  Next transition: rerun the final full Windows wrapper after this state update,
  then publish the PR if clean.

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
- Local docs/release review for the CON-014 draft found stale completed
  public-beta evidence claims after deployment artifacts changed and missing
  checked coverage for the new manager hash domains. The branch now marks the
  changed fork deployment and fork randomizer rows pending, restores issue-link
  tracking for #216/#220, adds the checked `StreamMintManager` domain constants
  table and checker, and has full local validation passing afterward.
- Final local verifier review for the CON-014 draft found stale human-facing
  #216/#220 readiness wording after the pending-row fix. The docs now state that
  the changed fork deployment and fork randomizer evidence rows are pending
  re-review for this PR's artifact set, and focused docs/evidence checks pass
  after regenerating the dependent risk register, release notes, manifest, and
  checksum bundle.
- OpenRouter round 4 found release-evidence and manager-policy issues. The
  branch now also marks `fork_testnet_ceremony_evidence` pending with #219
  restored, guards `configurePhase` with `MintPhaseAlreadyConfigured`, adds the
  requested tests for executor removal, uncapped counters, unlimited batch
  quantity, and beneficiary-keyed recipient counters, and documents
  authorization IDs as replay keys supplied by allowlisted executors.

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
