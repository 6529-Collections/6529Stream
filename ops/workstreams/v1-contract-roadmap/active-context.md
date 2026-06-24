# Active Context

## Current Goal

Finish the v1 contract roadmap autonomously, one topic at a time. For each
topic: plan, implement, use parallel OpenRouter reviews, iterate locally, open a
regular PR, request CodeRabbit when available, resolve or document review-bot
feedback, merge when clean, then continue.

## Current Topic

Core mint-manager boundary and prepared-mint hooks.

The current branch should implement the Core hook slice needed by the v1 mint
manager and primary settlement roadmap:

- a Core `mintManager` trust pointer with explicit manager-only authorization;
- `mintFromManager` so future manager/sale modules can ask Core to allocate the
  next token for a collection internally;
- same-flow prepared-mint hooks and read surface for token-level policy and
  settlement flows;
- token collection identity reads that expose mapping existence, collection ID,
  collection serial, and burned state;
- focused tests for authorization, allocation, supply/freeze/data guards,
  prepared mismatch handling, callback safety, and no counter drift on reverts;
- measured Core runtime-size proof for the final hook shapes.

Full mint manager phase policy, mint ledger accounting, routing Drops through
the manager, token-level revenue snapshots, ERC-20 auction bidding, and royalty
resolver integration remain follow-up topics.

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
- Current topic branch: `codex/mint-manager-core-hooks`.
- Current topic issue: https://github.com/6529-Collections/6529Stream/issues/631.
- Current topic PR: TBD.
- Local draft status: implemented locally, subagent blocker fixes applied, Core
  size proof updated to 24,172 runtime bytes with 404 bytes of EIP-170 margin,
  full local validation passed, and fresh OpenRouter review is in flight for
  Opus 4.8, GPT-5.5 Pro at max reasoning, and GLM 5.2.

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
- Current local validation target includes focused Core mint-manager hook tests,
  current StreamMinter/Drops regression tests, `forge build`, `forge test -vvv`,
  production `via-ir` size build, `python scripts/check_contract_size_budget.py`,
  release artifact checks when ABI surfaces change, `codex-diff-check`, and the
  full Windows `scripts\check.ps1` wrapper.
