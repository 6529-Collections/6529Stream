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
- Completed PR #626 after local validation, external OpenRouter review
  approvals from Opus 4.8, GPT-5.5 Pro at high reasoning, and GLM 5.2,
  CodeRabbit review iteration, green CI, and resolved review threads. Merged
  the PR as `1fe76b2126875819c579893a7786b4f6668ba832` and closed issue #625
  completed.
- Created issue #627 and branch `codex/asset-policy-erc20-splits` for the next
  outside-Core slice: deployment-wide asset policy registry plus approved
  standard ERC-20 split-wallet sync/release support.
- Implemented the local issue #627 draft with a deployment-wide
  `StreamAssetPolicyRegistry`, split factory registry pinning, approved
  standard ERC-20 split-wallet sync/release/accounting, docs, deployment
  config/broadcast manifest updates, tests, and regenerated release artifacts.
- Ran OpenRouter review for the asset-policy/ERC-20 split-wallet draft. Opus
  4.8 and GLM 5.2 returned visible non-blocking or test-hardening feedback that
  was addressed. GPT-5.5 Pro was kept at high/xhigh reasoning per user
  instruction; the substantive visible response identified bounded-return
  issues for registry and ERC-20 calls, which were patched with exact 32-byte
  return handling and focused malformed-return tests. Follow-up GPT-5.5 Pro
  attempts at high reasoning hit provider/hidden-reasoning transport limits
  rather than a downgraded-reasoning shortcut.
- Finished local validation for the issue #627 draft: focused split-wallet
  tests, production size build, targeted release-artifact checks,
  `codex-diff-check`, and the full Windows wrapper
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed on 2026-06-24.
- Opened PR #628 at
  https://github.com/6529-Collections/6529Stream/pull/628 and requested
  CodeRabbit review.
- PR #628 passed CI and CodeRabbit on head
  `97b59f9a00af4aa527c1d2aba6f8e581fff762f0`, then merged as
  `afd3a350474f0b876573d260bd71afe1781470b2`, closing issue #627 completed.
- Created issue #629 and branch `codex/revenue-resolver-primary-adapters` for
  the next outside-Core slice: revenue resolver plus native ETH and
  approved-standard ERC-20 primary-sale settlement adapter foundation.
- Implemented the local issue #629 draft with `StreamRevenueResolver`,
  `StreamPrimarySaleSettlement`, resolver and settlement interfaces, split-wallet
  verification in `StreamSplitFactory`, focused primary settlement tests,
  deployment rehearsal wiring, docs/indexer notes, and regenerated release
  artifacts.
- Addressed OpenRouter and local reviewer feedback before PR publication:
  assignment hashes now bind resolver/factory/asset-policy/runtime context;
  non-default scope IDs reject zero; settlement replay keys exclude caller,
  asset, and policy-mode variants; context/policy companion events support
  reconstruction; unsupported template account sources fail closed; deprecated
  ERC-20 assets and non-standard token behavior have focused coverage; and the
  fork non-broadcast deployment manifest is checked in Windows, Bash, Make, and
  CI gates.
- Local validation for the draft passed focused settlement tests, release
  profile build and generator check-mode gates, `codex-diff-check`, and the full
  Windows wrapper `powershell -NoProfile -ExecutionPolicy Bypass -File
  scripts\check.ps1`. Full `slither . --foundry-compile-all` was attempted and
  exited nonzero on the repo's broad existing finding set plus the reviewed
  arbitrary-send warning for the native settlement transfer to a verified split
  wallet.
- GPT-5.5 Pro was kept at max reasoning per user instruction. Two max-reasoning
  OpenRouter attempts returned hidden reasoning only with empty visible review
  content after roughly 4 minutes and 10.6 minutes respectively; a third max
  retry with hidden reasoning excluded returned visible feedback.
- Addressed the visible GPT-5.5 Pro feedback by keeping the new source/test
  files in the intended PR staging set and adding focused coverage for
  incorrect native value rollback, frozen assignment overwrite rejection,
  ERC-20-to-ERC-20 replay, second-leg ERC-20 rollback, and template ERC-20
  event reconstruction.
- Final local validation for the issue #629 draft passed: focused
  `StreamPrimarySaleSettlement` suite with 19 tests, `forge build`, full
  `forge test -vvv` with 516 tests, production `via-ir` build, deployment and
  release artifact/checksum checks, autonomous-state/docs/changelog gates,
  `codex-diff-check`, and full Windows `scripts\check.ps1`.
- Opened PR #630 at
  https://github.com/6529-Collections/6529Stream/pull/630 to close issue #629,
  then requested CodeRabbit review in comment `4786805627`. Next action is to
  wait for CI and review-bot feedback, resolve anything actionable, and merge
  only when clean.
- Addressed PR #630 review feedback by moving settlement replay checks before
  resolver/template side effects, verifying materialized split-wallet
  identities against the split factory, adding rollback/replay coverage, and
  refreshing release artifacts and readiness evidence.
- PR #630 passed CI and CodeRabbit, then merged as
  `68af8a885eda4cd74ec885a49beaf6ca6be388b8`, closing issue #629 completed.
- Created issue #631 and branch `codex/mint-manager-core-hooks` for `CON-012`:
  the Core mint-manager boundary, prepared-mint hooks, token collection identity
  reads, focused tests, and measured Core size proof required before the full
  mint manager policy/ledger migration.
- Implemented the local CON-012 Core hook draft on
  `codex/mint-manager-core-hooks`: validated `mintManager` pointer,
  manager-only immediate and prepared mint hooks, `tokenCollectionIdentity`,
  retained burn identity, and focused authorization/revert/callback coverage.
- Addressed subagent review blockers by adding manager-only prepared-mint abort
  recovery, rejecting stale randomizer callbacks after abort, guarding inherited
  ERC-721 approval/transfer paths while prepared state is pending, and slimming
  Core's prepared record so beneficiary/payment/mint-commitment evidence stays
  in manager and settlement satellites. Final measured `StreamCore` runtime is
  24,157 bytes with 419 bytes of EIP-170 margin under
  `CORE-SPEND-2026-06-24-001`.
- Completed local validation for the CON-012 draft. Focused Foundry suites,
  full `forge test -vvv` with 530 passing tests, full Windows
  `scripts\check.ps1`, `codex-diff-check`, and size/spend-policy checks passed.
  During validation, refreshed NatSpec summary counts and retained evidence
  hashes for local/fork deployment and randomizer artifacts, then regenerated
  downstream release manifests, evidence packet indexes, lockfile, bytecode
  proof, and checksum bundles.
- Launched fresh parallel OpenRouter reviews from the current validated packet:
  Opus 4.8 with max reasoning, GPT-5.5 Pro with max reasoning and a 90-minute
  client timeout, and GLM 5.2 with xhigh reasoning. The packet includes the
  current Solidity/interface/test contents, focused and full diffs, validation
  evidence, Core size risk, and the explicit abort-sentinel design question.
- PR #633 passed CI and CodeRabbit, then merged as
  `901df0180d1a50c29454e72b399365ba6305b4f1`, closing issue #631 completed.
- Fast-forwarded local `main` to `origin/main` and deleted the merged local
  `codex/mint-manager-core-hooks` branch.
- Created issue #634 and branch `codex/mint-manager-ledger-foundation` for
  `CON-013`: the `StreamMintLedger` static counter accounting foundation.
- Narrowed #634 from a manager-plus-ledger slice to a ledger-only slice after
  subagent review flagged Core headroom risk and PR-scope risk. The follow-up
  manager phase/execution PR should build on the reviewed ledger.
- Implemented the local ledger draft with `IStreamMintLedger`,
  `StreamMintLedger`, release contract catalog wiring, and focused ledger tests
  covering writer authorization, phase policy registration, unsupported future
  modes, counter consumption, event reconstruction, cap safety, authorization
  replay, and nullifier rejection.
- Applied OpenRouter review feedback to enforce canonical manager-scoped
  counter value keys, reject empty phase-policy registrations, document durable
  counter values, scope authorization replay per manager, and add focused
  coverage for registration events, same-hash re-registration, multi-counter
  batches, mid-batch rollback, writer revocation, cross-manager auth IDs, and
  counter drop/re-add durability. Focused ledger suite now passes 25 tests.
- Final high-reasoning GPT-5.5 Pro and GLM second-pass reviews returned visible
  content with no P0/P1 blockers for the ledger-only static phase-counter
  slice. Follow-up local fixes tightened `setLedgerWriter` so enabled writers
  must be deployed contracts, aligned `docs/mint-policy-and-accounting.md` with
  the implemented two-event consumption ABI and `CounterCapMode.NONE` requiring
  zero supplied cap, added focused rollback/exact-cap/zero-key tests, and
  updated the Sepolia deployment-manifest self-test to include
  `StreamMintLedger`.
- Final local validation for the CON-013 draft passed: focused
  `StreamMintLedger` suite, `forge build`, full `forge test -vvv` with 574
  tests, production via-IR size build, generated deployment/release artifacts
  and evidence gates, full Windows `scripts\check.ps1`, and
  `codex-diff-check`. During validation, refreshed retained evidence hashes for
  fork deployment rehearsal and fork randomizer operations, then regenerated
  public-beta evidence, evidence packet/backlog/body-sync artifacts, release
  manifest, lockfile, bytecode proof, and checksums.
- Opened PR #635 at
  https://github.com/6529-Collections/6529Stream/pull/635 to close issue #634
  and package the ledger foundation. Requested CodeRabbit in comment
  `4797239196`; CI run `28156747763` is in progress. Next action is to push
  this PR-number state update, keep CodeRabbit enabled, wait for CI/bot
  feedback, resolve anything actionable, then merge only when clean.
- PR #635 merged as `a2c6a6c1bb15fa59fc72ef2ac2519bdc0d94b27d`, closing issue
  #634 completed after latest-head CI and CodeRabbit were clean. Local `main`
  fast-forwarded to the merge commit. Created issue #636 and branch
  `codex/mint-manager-phase-execution` for `CON-014`: full
  `StreamMintManager` phase policy and ledger execution integration on top of
  the merged Core hook and static ledger foundations.
- Implemented the local CON-014 manager draft on
  `codex/mint-manager-phase-execution`: `StreamMintManager` now validates Core
  and ledger dependencies, configures launch-static phase policies, registers
  active policy hashes with `StreamMintLedger`, maintains per-phase executor
  sets and pause/window guards, preflights duplicate batch counter keys,
  consumes ledger counters and authorization IDs, and atomically executes Core
  prepare/complete minting with rollback and reentrancy coverage.
- Refreshed the first deployment/release surfaces for the CON-014 draft:
  `RehearseDeployment` now deploys and wires `StreamMintManager`, grants it
  ledger-writer authority, and transfers ownership; release contract catalog,
  placeholder deployment configs, Sepolia expected contract tests, changelog,
  warning dispositions, and mint-policy docs now include the manager.
- Completed local validation for the CON-014 manager draft. Focused
  `StreamMintManager` tests pass, `forge build --sizes --via-ir --skip test
  --skip script --force` reports `StreamCore` at 24,157 bytes with 419 bytes of
  EIP-170 margin and `StreamMintManager` at 15,155 bytes, full Windows
  `scripts\check.ps1` passed, and `codex-diff-check` passed. During validation,
  refreshed NatSpec baseline debt after documenting manager public getters,
  updated retained local/fork evidence hashes affected by the new manager
  deployment, and regenerated release notes, release manifest, lockfile,
  bytecode proof, risk register, public-beta evidence indexes, and checksum
  bundles.
- Addressed the local CON-014 release-review blockers. The changed
  `fork_deployment_rehearsal` and
  `fork_testnet_randomizer_operations_evidence` rows now stay `pending` until
  this PR's updated retained artifact set is reviewed, and
  `release-evidence-issue-links.json` again tracks #216 and #220 while the rows
  are incomplete. Added a checked `StreamMintManager` domain constants table to
  `docs/launch-v1-target-architecture.md`, plus
  `scripts/check_mint_manager_domain_constants.py`, focused tests, wrapper
  wiring, release manifest coverage, and checksum coverage. Regenerated the
  public-beta blocker report, evidence packet, backlog, body sync, risk
  register, release notes, release manifest, bytecode proof, lockfile, and
  checksums. Focused artifact/domain checks, focused manager tests, `forge
  build --skip test`, production via-IR size build, `python
  scripts/check_contract_size_budget.py`, full Windows `scripts\check.ps1`, and
  `codex-diff-check` all passed.
- Addressed the final local verifier finding for the CON-014 draft. Updated the
  human-facing readiness/runbook docs so #216 and #220 no longer read as
  reviewed complete after this branch's retained artifact set changed; the fork
  deployment and fork randomizer rows now consistently read as pending
  re-review until this PR's artifacts are accepted. Regenerated the dependent
  risk register, release notes, release manifest, and checksum bundle. Focused
  checks now pass: markdown links, release notes check, release manifest check,
  release checksums check, public-beta evidence check, release-readiness check,
  and `codex-diff-check`.
- Addressed OpenRouter round-4 CON-014 feedback. The branch now marks
  `fork_testnet_ceremony_evidence` pending with issue #219 restored, documents
  the Core/settlement bytecode-hash evidence reconciliation, guards
  `configurePhase` with `MintPhaseAlreadyConfigured`, adds focused tests for
  phase reconfiguration rejection, executor removal, uncapped counters,
  unlimited batch size, and beneficiary-keyed recipient counters, and documents
  `authorizationId` as a replay key supplied by an allowlisted executor rather
  than manager-side signature verification.
- Regenerated release artifacts after the OpenRouter fixes. Current production
  `via-ir` size output reports `StreamCore` at 24,157 bytes with 419 bytes of
  EIP-170 margin and `StreamMintManager` at 15,155 bytes. Refreshed local
  ceremony and randomizer evidence hashes, NatSpec baseline counts, release
  notes, risk register, manifest, bytecode proof, release-candidate lockfile,
  and checksum bundle. Targeted checks pass, including focused manager tests,
  domain constants checks, size/spend policy, release/deployment artifact
  checks, evidence checks, release readiness, changelog, and `codex-diff-check`.
- Launched OpenRouter round 7 from the refreshed packet: Opus 4.8, GPT-5.5 Pro,
  and GLM 5.2 at high reasoning, with GPT-5.5 Pro kept off low/minimal
  reasoning per user instruction. A read-only local verifier also reviewed the
  refreshed working tree.
- Addressed the read-only local verifier's optional CON-014 coverage
  suggestions by adding focused manager tests for exact max launch batch
  minting with a repeated recipient, manager-level Core collection-supply
  exhaustion rollback after ledger consumption, and executor-cap overflow
  immutability of policy state. Focused
  `forge test --match-path test\StreamMintManager.t.sol -vvv` now passes 33
  tests, and `codex-diff-check` remains clean aside from expected Windows
  line-ending warnings.
- Reran the full Windows wrapper after the optional test hardening and state
  updates. `powershell -NoProfile -ExecutionPolicy Bypass -File
  scripts\check.ps1` passed through the full validation ladder, ending with the
  deployment-suite, standalone deployment, auction ceremony, and emergency
  redeployment rehearsal scripts all running successfully. The OpenRouter
  round-7 reviews remain in-flight at high reasoning.
- Reconciled the final local CON-014 validation state after additional event,
  context-counter, rollback, and reentrancy hardening. Focused
  `StreamMintManager` tests now pass 36 cases, including context counters
  consuming once per batch, second-token receiver rollback, receiver/admin
  reentrancy protection, policy-hash event payloads, exact max launch batch,
  Core supply-exhaustion rollback after ledger consumption, and executor-cap
  overflow immutability. Regenerated dependent release evidence, release notes,
  manifest, bytecode proof, lockfile, and checksum artifacts after evidence and
  size-doc hash drift. Current production `via-ir` size output records
  `StreamCore` at 24,150 bytes with 426 bytes of EIP-170 margin and
  `StreamMintManager` at 16,812 bytes. `codex-diff-check` passes with expected
  Windows line-ending warnings, and the full Windows wrapper passed at
  `C:\Users\Administrator\AppData\Local\Temp\6529stream-check-20260625-200854.log`.
  Next action is the final high/max-reasoning OpenRouter review pass with Opus
  4.8, GPT-5.5 Pro, and GLM 5.2 before PR publication.
- Ran the final post-fix OpenRouter review pass at high reasoning. Opus 4.8
  and GLM 5.2 first found one P1 release-evidence blocker: stale
  `StreamCore` size prose in `docs/tooling.md` and
  `docs/launch-v1-target-architecture.md` still said 24,157 bytes / 419-byte
  margin while the regenerated bytecode proof and other guarded docs said
  24,150 bytes / 426-byte margin. Fixed those docs, regenerated dependent
  release artifacts, and reran targeted architecture, domain-constant,
  release-manifest, bytecode-proof, checksum, release-verifier, and
  `codex-diff-check` gates successfully. The post-fix reviewer pass returned
  `APPROVE` from Opus 4.8, `APPROVE` from GLM 5.2, and visible `APPROVE` from
  GPT-5.5 Pro at high reasoning after disabling reasoning echo without reducing
  reasoning effort. Remaining reviewer notes are non-blocking follow-ups.
  Next action is a final full Windows wrapper rerun after this state update,
  then PR publication if clean.
