# Run Log

## 2026-06-23

- Started the v1 contract roadmap autonomous workstream at user request.
- Loaded and followed `ops/skills/6529-autonomous-manager`.
- Confirmed manager skill PR #621 merged and merged follow-up PR #622 after CI
  passed, so the roadmap branch can use the cleaned manager skill from `main`.
- Loaded the OpenRouter skill and confirmed model targets from local guidance.
- Spawned parallel subagents for:
  - current v1 outside-Core scope consistency audit;
  - next-topic roadmap sequencing;
  - safe OpenRouter model-slug and credential-use guidance.
- OpenRouter guidance subagent confirmed:
  - GPT-5.5 Pro slug: `openai/gpt-5.5-pro`;
  - GLM 5.2 slug: `z-ai/glm-5.2`;
  - Opus 4.8 catalog candidates include `anthropic/claude-opus-4.8` and
    `anthropic/claude-opus-4.8-fast`;
  - the safest slug-discovery path is the public OpenRouter models catalog, with
    the API key retrieved only inside the request process for actual reviews.
- Current-scope audit subagent found stale wording:
  - ADR 0008 still said the v1 primary adapter was native ETH only;
  - launch conformance still named only primary native ETH settlement;
  - auction wording needed to avoid implying ERC-20 auction bidding was included
    by the ERC-20 primary-sale adapter requirement;
  - metadata docs used `StreamPreservationRegistry` instead of
    `StreamPreservationRecords`.
- Patched those stale v1-scope contradictions before external model review.
- Roadmap sequencing subagent recommended the next substantive implementation
  PR as split factory plus split wallet skeleton, staying outside `StreamCore`.
- Ran OpenRouter review round 1 against GPT-5.5 Pro, Opus 4.8, and GLM 5.2.
  - The catalog verified `openai/gpt-5.5-pro`,
    `anthropic/claude-opus-4.8`, and `z-ai/glm-5.2`.
  - GPT-5.5 Pro and GLM 5.2 returned hidden reasoning only on the large packet,
    so they need a compact final-only retry.
  - Opus 4.8 returned `REQUEST_CHANGES`.
- Patched the Opus round 1 blockers:
  - primary ERC-20 adapters and revenue escrow both enforce the deployment-wide
    `ACTIVE` asset policy before recording new non-native primary revenue;
  - ERC-20 primary adapters must measure exact adapter balance deltas, while
    passive wallet ERC-20 receipts remain releasable but are not primary-sale
    settlement evidence;
  - entropy fallback choice is retained in a checksum-covered
    `StreamEntropyLaunchDecision` manifest with coordinator failure behavior;
  - `StreamPreservationRecords`, `StreamCollectionAttestations`, and
    `StreamCollectionViews` now have launch conformance rows with tests and
    release artifacts;
  - metadata function-count, bytecode, and audit ceilings now apply across the
    aggregate metadata launch surface, not only `StreamCollectionMetadata`.
- Ran compact OpenRouter review round 2 after those fixes.
  - GPT-5.5 Pro: `APPROVE`, no blocking findings.
  - Opus 4.8: `APPROVE`, no blocking findings.
  - GLM 5.2: `APPROVE`, no blocking findings.
- Folded in non-blocking hardening from round 2:
  - named the future entropy decision artifact as
    `release-artifacts/latest/entropy-launch-decision.json` or an equivalent
    release-manifest record;
  - required release checks for the aggregate metadata ABI/bytecode ceiling;
  - clarified that escrow registry failures and inactive/deprecated assets
    revert before owed-credit mutation for new non-native primary revenue.
- Opened PR #623 at
  https://github.com/6529-Collections/6529Stream/pull/623 and requested
  CodeRabbit review.
- Created tracker issue #624 at
  https://github.com/6529-Collections/6529Stream/issues/624 and linked PR #623
  with `Closes #624` so autonomous-state and backlog checks have an issue-backed
  active PR row.
- CI caught that `ops/AUTONOMOUS_RUN.md` still recorded the active PR as
  pending prose after the PR had been opened. Patched the active PR field to the
  concrete PR URL before rerunning autonomous-state and release evidence checks.
- Local autonomous-state validation also required an issue-backed active backlog
  row for the open PR, so `MAP-002` now records PR #623 / issue #624 on the
  current branch.
- The same validation pass found stale backlog status for already-merged PR
  #608. Updated `EXT-038` from active to merged so PR #623 is the only active
  PR marker.
- Addressed CodeRabbit's sole nitpick on PR #623 by rewording the entropy
  coordinator open-decision list to avoid repeated sentence openings.
- PR #623 passed CI and CodeRabbit on head
  `c4b4278ddfd5b71b3aa740f1d6f814525f6292a1`, then merged as
  `6217346e60c17af6d3738aed2dd284f91b9c6507`, closing issue #624.
- Created issue #625 for the split factory and split wallet skeleton, created
  branch `codex/split-factory-wallet-skeleton` from merged `main`, and spawned
  parallel explorers for contract architecture, security/test edge cases, and
  release-state requirements.
- Implemented the local split skeleton draft with `StreamSplitFactory`,
  `StreamSplitWallet`, selector-stable interfaces, focused native ETH split
  tests, release-surface registration, changelog coverage, revenue spec status,
  event/indexer docs, and cleanup for the stale PR #608 active marker.
