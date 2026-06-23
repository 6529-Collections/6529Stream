# Active Context

## Current Goal

Finish the v1 contract roadmap autonomously, one topic at a time. For each
topic: plan, implement, use parallel OpenRouter reviews, iterate locally, open a
regular PR, request CodeRabbit when available, resolve or document review-bot
feedback, merge when clean, then continue.

## Current Topic

Split factory and split wallet skeleton.

The current branch should implement the first outside-Core revenue split slice:

- `StreamSplitFactory` deterministic deployment/discovery for immutable fixed
  split profiles.
- `StreamSplitWallet` one-shot factory-bound initialization, immutable profile
  storage, native ETH receipt/release, and pull-accounting reads.
- Profile hashing, entry validation, canonicalization, duplicate handling,
  aggregate account shares, and reconstructable events.
- No `StreamCore` bytecode spend in this PR.
- Resolver assignments, primary-sale adapters, escrow, and Core-native
  resolver-backed ERC-2981 remain later roadmap topics unless a tiny compile
  interface is unavoidable.

## Branch State

- Manager skill PR #621 merged.
- Manager skill follow-up PR #622 merged.
- V1 outside-Core scope reconciliation PR #623 merged and closed issue #624.
- Current topic branch: `codex/split-factory-wallet-skeleton`.
- Current topic issue: https://github.com/6529-Collections/6529Stream/issues/625.
- Current topic PR: TBD.

## Subagent Findings To Carry

- ADR 0008 had stale native-ETH-only primary settlement language.
- Launch conformance gate wording needed approved-standard ERC-20 settlement at
  the gate level.
- Auction wording needed to clarify that the ERC-20 primary settlement launch
  requirement does not automatically launch ERC-20 auction bidding.
- Metadata docs used `StreamPreservationRegistry` while the roadmap standardized
  on `StreamPreservationRecords`.
- After the split factory/wallet skeleton, the likely sequence is asset policy
  registry plus ERC-20 release/sync, revenue resolver, mint manager, collection
  metadata, preservation satellites, entropy fallback decision, and only then
  minimal Core hooks.

## Validation Bar

- Local docs/link/changelog/release artifact checks pass.
- Generated release artifacts are current.
- OpenRouter reviewers return no blocking issues, or all blockers are patched
  and the review loop is repeated.
- PR review bots have no unresolved blocking findings, or deferrals are
  documented with rationale.
