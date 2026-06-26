# Active Context

## Current Goal

Finish the v1 contract roadmap autonomously, one topic at a time. For each
topic: plan, implement, use parallel OpenRouter reviews, iterate locally, open a
regular PR, request CodeRabbit when available, resolve or document review-bot
feedback, merge when clean, then continue.

## Current Topic

Collection metadata and preservation record satellites.

The current branch should implement the first outside-Core museum metadata and
preservation slice on top of the merged payment, ledger, and manager
foundations:

- compact schema-bound records in `StreamCollectionMetadata` for typed launch
  metadata groups;
- immutable collection snapshot publication and latest-hash reads;
- PREMIS/C2PA/IIIF/fixity-ready append-only records in
  `StreamPreservationRecords`;
- admin/pause, missing-collection, freeze, revision, lock, URI/hash, and event
  reconstruction coverage;
- deployment, address-book, release-artifact, changelog, and run-state wiring
  without adding Core bytecode.

Collection attestations, collection view/reference satellites, typed
PREMIS/C2PA/IIIF companion ABIs, custom gates, ERC-20 auction bidding, callable
nullifiers, and royalty resolver integration remain follow-up topics unless a
smaller reviewed boundary is needed for this metadata/preservation slice.

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
- Mint manager phase/execution PR #637 merged and issue #636 is closed
  completed.
- Current topic branch: `codex/collection-metadata-preservation`.
- Current topic issue: #638.
- Current topic PR: #639.
- Current draft status: local `StreamCollectionMetadata` and
  `StreamPreservationRecords` implementation, focused tests, rehearsal
  deployment wiring, release/deployment artifact refreshes, changelog, backlog,
  and run-state updates are in progress. Focused metadata, preservation, and
  deployment manifest tests pass. Production via-IR size output records
  `StreamCore` at 24,150 bytes with 426 bytes of EIP-170 margin,
  `StreamCollectionMetadata` at 10,166 bytes, and
  `StreamPreservationRecords` at 7,734 bytes. Opus 4.8 and GLM 5.2 returned
  no P0/P1 issues. GPT-5.5 Pro ran at high/max reasoning, found one P2 in the
  deployment manifest identity binding, and closed that finding after the
  follow-up fix bound satellite dependency-pointer state. PR #639 is open and
  CodeRabbit has been requested. Next transition: wait for CI and review-bot
  feedback, resolve actionable findings, then merge if clean.

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
- Current local validation target includes focused metadata/preservation tests,
  `forge build`, `forge test -vvv`, production `via-ir` size build, deployment
  rehearsal, release/deployment artifact checks,
  `python scripts/check_contract_size_budget.py`, `codex-diff-check`, and the
  full Windows `scripts\check.ps1` wrapper before PR/merge.
