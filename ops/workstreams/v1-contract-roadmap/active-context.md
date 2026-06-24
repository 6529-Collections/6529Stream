# Active Context

## Current Goal

Finish the v1 contract roadmap autonomously, one topic at a time. For each
topic: plan, implement, use parallel OpenRouter reviews, iterate locally, open a
regular PR, request CodeRabbit when available, resolve or document review-bot
feedback, merge when clean, then continue.

## Current Topic

Asset policy registry and ERC-20 split-wallet release/sync.

The current branch implements the next outside-Core revenue split slice:

- a deployment-wide asset policy registry for approved standard ERC-20 assets;
- split factory/wallet wiring that pins the policy registry without spending
  `StreamCore` bytecode;
- explicit ERC-20 `syncAsset`, `releasable`, `roundingDust`, and `release`
  support for policy-approved standard tokens;
- fail-closed policy reads, default-deny assets, and exact balance-delta
  checks that reject fee-on-transfer, no-op, rebasing-down, and other
  unsupported ERC-20 behavior;
- native ETH regression coverage from the first split wallet slice.

Resolver assignments, primary-sale adapters, escrow, and Core-native
resolver-backed ERC-2981 remain later roadmap topics unless a tiny compile
interface is unavoidable.

Local implementation status: complete and validated. OpenRouter review feedback
from Opus 4.8, GLM 5.2, and GPT-5.5 Pro highest-reasoning attempts has been
incorporated; GPT-5.5 Pro's substantive bounded-return findings are patched.
The full Windows validation wrapper passed on 2026-06-24.

## Branch State

- Manager skill PR #621 merged.
- Manager skill follow-up PR #622 merged.
- V1 outside-Core scope reconciliation PR #623 merged and closed issue #624.
- Split factory/wallet skeleton PR #626 merged and issue #625 is closed
  completed.
- Current topic branch: `codex/asset-policy-erc20-splits`.
- Current topic issue: https://github.com/6529-Collections/6529Stream/issues/627.
- Current topic PR: https://github.com/6529-Collections/6529Stream/pull/628.

## Subagent Findings To Carry

- ADR 0008 had stale native-ETH-only primary settlement language.
- Launch conformance gate wording needed approved-standard ERC-20 settlement at
  the gate level.
- Auction wording needed to clarify that the ERC-20 primary settlement launch
  requirement does not automatically launch ERC-20 auction bidding.
- Metadata docs used `StreamPreservationRegistry` while the roadmap standardized
  on `StreamPreservationRecords`.
- After the asset policy and ERC-20 split-wallet slice, the likely sequence is
  revenue resolver, primary-sale adapters, mint manager, collection metadata,
  preservation satellites, entropy fallback decision, and only then minimal
  Core hooks.

## Validation Bar

- Local docs/link/changelog/release artifact checks pass.
- Generated release artifacts are current.
- OpenRouter reviewers return no blocking issues, or all blockers are patched
  and the review loop is repeated.
- PR review bots have no unresolved blocking findings, or deferrals are
  documented with rationale.
