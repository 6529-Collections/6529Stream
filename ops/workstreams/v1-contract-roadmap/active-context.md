# Active Context

## Current Goal

Finish the v1 contract roadmap autonomously, one topic at a time. For each
topic: plan, implement, use parallel OpenRouter reviews, iterate locally, open a
regular PR, request CodeRabbit when available, resolve or document review-bot
feedback, merge when clean, then continue.

## Current Topic

V1 outside-Core launch scope reconciliation.

The current draft makes these launch requirements explicit:

- ERC-20 primary settlement for approved standard assets through payment
  adapters or primary-sale settlement modules outside `StreamCore`.
- C2PA, IIIF, PREMIS-style, fixity, archive, and museum-grade metadata records
  as real v1 metadata/preservation surfaces.
- Richer preservation satellites such as `StreamPreservationRecords`,
  `StreamCollectionAttestations`, and `StreamCollectionViews`.
- A v1 entropy fallback decision: ship a reviewed ARRNG/Pyth fallback provider
  or explicitly accept a reviewed VRF-only launch exception.

## Branch State

- Manager skill PR #621 merged.
- Manager skill follow-up PR #622 merged.
- Current topic branch: `codex/v1-outside-core-launch-scope`.
- Current topic branch can now be rebased onto `origin/main`.

## Subagent Findings To Carry

- ADR 0008 had stale native-ETH-only primary settlement language.
- Launch conformance gate wording needed approved-standard ERC-20 settlement at
  the gate level.
- Auction wording needed to clarify that the ERC-20 primary settlement launch
  requirement does not automatically launch ERC-20 auction bidding.
- Metadata docs used `StreamPreservationRegistry` while the roadmap standardized
  on `StreamPreservationRecords`.
- Next substantive implementation should likely be the split factory and split
  wallet skeleton, followed by asset policy, revenue resolver, mint manager,
  collection metadata, preservation satellites, entropy fallback decision, and
  only then minimal Core hooks.

## Validation Bar

- Local docs/link/changelog/release artifact checks pass.
- Generated release artifacts are current.
- OpenRouter reviewers return no blocking issues, or all blockers are patched
  and the review loop is repeated.
- PR review bots have no unresolved blocking findings, or deferrals are
  documented with rationale.
