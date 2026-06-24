# Active Context

## Current Goal

Finish the v1 contract roadmap autonomously, one topic at a time. For each
topic: plan, implement, use parallel OpenRouter reviews, iterate locally, open a
regular PR, request CodeRabbit when available, resolve or document review-bot
feedback, merge when clean, then continue.

## Current Topic

Revenue resolver and primary-sale settlement adapters.

The current branch should implement the next outside-Core primary settlement
slice:

- a deployment-tracked revenue resolver surface for primary revenue
  assignments;
- native ETH and approved-standard ERC-20 primary-sale settlement adapters or
  modules outside `StreamCore`;
- assignment/policy hashes that bind revenue class, profile, wallet/factory,
  asset, and mutability/freeze state;
- exact native/token value accounting, fail-closed ERC-20 policy reads, and
  official-settlement events that indexers can distinguish from passive wallet
  receipts;
- focused tests for strict policy-hash matching, replay controls, profile and
  wallet verification, native settlement, ERC-20 exact-delta settlement, and
  passive receipt separation.

Mint-manager/Core prepared-mint hooks, token-level snapshots, ERC-20 auction
bidding, and royalty resolver integration remain later roadmap topics unless a
minimal compile/test interface is unavoidable.

## Branch State

- Manager skill PR #621 merged.
- Manager skill follow-up PR #622 merged.
- V1 outside-Core scope reconciliation PR #623 merged and closed issue #624.
- Split factory/wallet skeleton PR #626 merged and issue #625 is closed
  completed.
- Asset policy and ERC-20 split-wallet PR #628 merged and issue #627 is closed
  completed.
- Current topic branch: `codex/revenue-resolver-primary-adapters`.
- Current topic issue: https://github.com/6529-Collections/6529Stream/issues/629.
- Current topic PR: TBD.
- Local draft status: implemented, max-reasoning GPT-5.5 Pro visible feedback
  addressed, and locally validated; PR not opened yet.

## Subagent Findings To Carry

- ADR 0008 had stale native-ETH-only primary settlement language.
- Launch conformance gate wording needed approved-standard ERC-20 settlement at
  the gate level.
- Auction wording needed to clarify that the ERC-20 primary settlement launch
  requirement does not automatically launch ERC-20 auction bidding.
- Metadata docs used `StreamPreservationRegistry` while the roadmap standardized
  on `StreamPreservationRecords`.
- After the revenue resolver and primary-sale adapter slice, the likely
  sequence is mint manager, collection metadata,
  preservation satellites, entropy fallback decision, and only then minimal
  Core hooks.

## Validation Bar

- Local docs/link/changelog/release artifact checks pass.
- Generated release artifacts are current.
- OpenRouter reviewers return no blocking issues, or all blockers are patched
  and the review loop is repeated.
- PR review bots have no unresolved blocking findings, or deferrals are
  documented with rationale.
- Current local validation includes 19 focused primary-settlement tests,
  `forge build`, `forge test -vvv`, production `via-ir` release artifact
  regeneration/checks, `codex-diff-check`, and the full Windows
  `scripts\check.ps1` wrapper. Full Slither was attempted and exited nonzero on
  the repo's broad baseline warning set plus the reviewed arbitrary native-send
  warning for the settlement adapter's verified split-wallet transfer.
