# 6529Stream Autonomous Run State

This file is the durable state for the autonomous roadmap execution run. It
exists so long-running PR cycles can resume from repository state instead of
transient conversation memory.

## Operating Rules

- Work from `ops/ROADMAP.md` as the canonical roadmap.
- Keep this file updated before and after each meaningful transition.
- Open one PR at a time.
- Wait for CI and bot/reviewer comments on each PR.
- Request CodeRabbit review explicitly with `@coderabbitai review` on each PR
  after opening. Claude review is optional while the user-approved
  CodeRabbit-only path remains in effect, and should be requested only when the
  PR risk or a future user instruction calls for it.
- Iterate until checks and review comments are clean.
- Merge only after the PR is review-clean and CI-clean, or after a documented
  autonomous maintainer decision.
- Proceed from documented assumptions while the autonomous run is active.
- Make conservative decisions that preserve protocol safety and open-source
  maintainability.
- Never revert unrelated local changes.

## Current Objective

Deliver the roadmap at a world-class open-source level for 6529 NFT drops:
reproducible setup, honest maturity docs, issue-ready planning, CI/tooling,
tests, security hardening, deployment discipline, and release/audit readiness.

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `https://github.com/6529-Collections/6529Stream.git` |
| Active PR branch | `codex/metadata-erc4906-events` |
| Last merged PR | `https://github.com/6529-Collections/6529Stream/pull/81` |
| Roadmap file | `ops/ROADMAP.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-06-10 23:02 UTC` |

## Packaging Notes

- PR 1 is intentionally scoped to `ops/ROADMAP.md` and
  `ops/AUTONOMOUS_RUN.md`.
- The initial manager checkout contained unrelated docs, tooling, and contract
  edits. Those should be handled in later PRs or ignored unless they match the
  active queue item.
- Use clean branches from `origin/main` for each PR unless an active PR branch is
  already recorded here.

## PR Queue

The queue will evolve as PRs merge and bot feedback arrives.

| Order | Candidate PR | Gate | Scope | Status |
| --- | --- | --- | --- | --- |
| 1 | Roadmap and autonomous run control plane | Gate A / planning | `ops/ROADMAP.md`, `ops/AUTONOMOUS_RUN.md` only unless PR packaging requires small docs metadata | Merged in PR #3 |
| 2 | Reproducible baseline tooling | Gate A | Foundry config, make/check command, bootstrap scripts, CI smoke workflow | Merged in PR #4 |
| 3 | Repo maturity and contributor docs | Gate A / Gate G foundation | README status, SECURITY, CONTRIBUTING, issue/PR templates, CODEOWNERS | Merged in PR #5 |
| 4 | Characterization test skeleton | Gate A | Test helpers, fixtures, mocks, and executable characterization coverage | Merged in PR #6 |
| 5 | Slither baseline appendix/config | Gate A / Gate C foundation | Static analysis command/config and tracked baseline issue rows | Merged in PR #7 |
| 6 | Slither baseline issue links | Gate C / Gate F foundation | Create canonical GitHub issues for open high/medium Slither groups and link them from roadmap/baseline docs | Merged in PR #16 |
| 7 | Drop authorization ADR | Gate B1 | Accept `docs/adr/0001-drop-authorization.md` before P0 auth rewrites | Merged in PR #20 |
| 8 | Auction custody ADR | Gate B1 | Accept `docs/adr/0002-auction-custody.md` before P0 auction rewrites | Merged in PR #23 |
| 9 | Payment accounting ADR | Gate B1 | Accept `docs/adr/0003-payment-accounting.md` before pull-payment rewrites | Merged in PR #32 |
| 10 | Admin/governance ADR | Gate B1 | Accept `docs/adr/0004-admin-governance.md` before permission/pause rewrites | Merged in PR #36 |
| 11 | Randomness ADR | Gate B1 | Accept `docs/adr/0005-randomness.md` before callback/randomness rewrites | Merged in PR #44 |
| 12 | Metadata/freeze ADR | Gate B2 | Accept `docs/adr/0006-metadata-freeze.md` before metadata, dependency, freeze, burn, and ERC-4906 work | Merged in PR #52 |
| 13 | Upgrade/redeployment ADR | Gate B2 | Accept `docs/adr/0007-upgrade-redeployment.md` before deployment, release, manifest, deprecation, and emergency redeployment work | Merged in PR #54 |
| 14 | Remove `tx.origin` from drop execution | Gate C | Add explicit drop recipient/execution storage and target-state tests before EIP-712 authorization work | Merged in PR #55 |
| 15 | Replace drop authorization with EIP-712 | Gate C | Add typed drop authorizations, consumed/cancelled drop IDs, signer epoch controls, EOA/EIP-2098 validation, and target-state tests | Merged in PR #56 |
| 16 | Implement ERC-1271 contract signer support | Gate C | Allow contract signers to validate the same EIP-712 digest via `isValidSignature`, with target-state success and failure tests | Merged in PR #57 |
| 17 | Fix auction bidding reentrancy and outbid refunds | Gate C | Convert outbid refunds to pull credits, keep bid state consistent, add withdrawal/reentrancy tests, and update Slither/test traceability | Merged in PR #58 |
| 18 | Formalize auction custody and settlement | Gate C | Implement the accepted ADR 0002 custody/state-machine semantics, settlement guards, tests, docs, and roadmap traceability | Merged in PR #59 |
| 19 | Convert fixed-price payouts to pull credits | Gate C | Implement P0-PAY-003 for `StreamDrops` fixed-price poster/protocol credits and curator-reserve accounting, with tests/docs/state traceability | Merged in PR #60 |
| 20 | Convert curator reward claims to credits | Gate C | Implement P0-PAY-005 for `StreamCuratorsPool` curator reward claim credits, withdrawal safety, Merkle/delegation tests, docs, and state traceability | Merged in PR #61 |
| 21 | Bound remaining emergency withdrawals | Gate C | Finish the remaining P0-PAY-007/P0-PAY-008 emergency-withdrawal surface for `StreamMinter` and `NextGenRandomizerRNG`, with tests, Slither traceability, and docs updates | Merged in PR #62 |
| 22 | Fix admin selector and permission model | Gate C | Implement P0-ADMIN-001 target-scoped admin permission semantics, explicit selector tests, docs, and roadmap traceability | Merged in PR #63 |
| 23 | Define pause and emergency controls | Gate C | Implement P0-ADMIN-002 domain-scoped pause controls, withdrawal-pause policy, emergency-control traceability, tests, docs, and roadmap state updates | Merged in PR #64 |
| 24 | Harden randomizer requests and callbacks | Gate C | Implement P0-RAND-001 request lifecycle, provider/epoch validation, duplicate/stale callback rejection, events, tests, docs, and roadmap state updates | Merged in PR #65 |
| 25 | Complete randomizer lifecycle views | Gate C | Finish P0-RAND-002 by exposing token-level request/state views, tests, docs, and roadmap state updates | Merged in PR #66 |
| 26 | Block randomizer migration while requests are pending | Gate C | Implement P0-RAND-005 default ADR policy: lifecycle-aware pending counts, provider-migration guard, stale/fulfilled unblocking, tests, docs, and roadmap state updates | Merged in PR #67 |
| 27 | Add failed randomness post-processing state | Gate C | Implement P0-RAND-004 failed-state path for deterministic post-processing reverts, with VRF/arRNG tests, docs, and roadmap state updates | Merged in PR #68 |
| 28 | Add bounded randomness post-processing retry | Gate C | Implement P0-RAND-006 stored-seed manual retry for deterministic failed post-processing, with VRF/arRNG tests, docs, and roadmap state updates | Merged in PR #69 |
| 29 | Store raw random output hashes | Gate C | Implement P0-RAND-007 raw-output hash storage policy, domain-separated seed derivation, event/view exposure, tests, docs, and roadmap state updates | Merged in PR #70 |
| 30 | Fix dependency script packed encoding | Gate C/Gate D | Implement P0-META-001 typed dependency chunk/content hashes, preserve rendered-script compatibility, add metadata encoding tests, and update Slither/roadmap traceability | Merged in PR #71 |
| 31 | Remove dead mint-accounting state | Gate C | Implement P0-CORE-001 by removing never-written public/allowlist mint counters, keeping retained airdrop-counter tests, and updating Slither/roadmap traceability | Merged in PR #72 |
| 32 | Remove weak helper randomness | Gate C | Implement P0-RAND-008 by removing the concrete `XRandoms` helper from production source, preserving the `RandomizerNXT` legacy-only regression, and updating Slither/roadmap traceability | Merged in PR #74 |
| 33 | Resolve first-party uninitialized locals | Gate C | Implement P0-INIT-001 by explicitly initializing remaining production locals, adding targeted regression tests, and updating Slither/roadmap traceability | Merged in PR #75 |
| 34 | Prove vendored library provenance | Gate F | Complete P0-LIB-001 by documenting retained OpenZeppelin utility provenance, marking vendored Slither rows as false positives with proof, and adding focused Base64/Math regressions | Merged in PR #76 |
| 35 | Add payment invariant baseline | Gate D | Add bounded sequence fuzz coverage proving current local payment ledgers, owed totals, reserves, and emergency-withdrawable surplus remain coherent across mixed mint, bid, settlement, withdrawal, randomizer, and forced-balance operations | Merged in PR #77 |
| 36 | Add payment ledger view aliases | Gate C/Gate D | Expose missing ADR 0003 local-ledger view names such as `totalReserved()` and `surplus()`, add category aliases where useful, assert them in payment invariants, and reconcile P0-PAY-002 roadmap state | Merged in PR #78 |
| 37 | Add signer lifecycle manager | Gate B1/Gate C | Implement P0-ADMIN-003 by separating drop-signing identity from signer-management authority, adding signer-manager role tests, proving rotation invalidates stale payloads, and updating ADR/roadmap state | Merged in PR #80 |
| 38 | Add metadata schema and golden-file tests | Gate D | Implement the first P1-META-001 test/docs slice: lock current off-chain pending/final tokenURI behavior, add on-chain JSON golden fixtures where feasible, document schema fields, and update roadmap/test traceability | Merged in PR #81 |
| 39 | Add ERC-4906 metadata update signaling | Gate D | Implement P1-META-004 for `StreamCore`: interface support, token-level and collection-range metadata update events, no misleading mint/burn-only events, docs, and roadmap/test traceability | PR #82 open on `codex/metadata-erc4906-events` |

## Current PR Worklog

### PR #4: Reproducible baseline tooling (Queue Item 2)

Status: Merge-ready; CI is green, CodeRabbit is green, and all visible review threads are
resolved.
Branch: `codex/gate-a-reproducible-baseline`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/4`.

Goal:

- Make a fresh checkout compile real Solidity sources instead of compiling
  nothing.
- Add a canonical `make check` smoke gate.
- Add Linux and Windows bootstrap/check scripts.
- Add CI build/test smoke with uploaded logs.
- Add minimal setup/status docs and repository skeleton directories.

Candidate files:

- `ops/AUTONOMOUS_RUN.md`
- `.editorconfig`
- `.gitattributes`
- `.gitignore`
- `.github/workflows/ci.yml`
- `foundry.toml`
- `Makefile`
- `requirements-tools.txt`
- `scripts/`
- `docs/`
- `test/README.md`
- `script/README.md`
- `README.md`
- Compile-surface interface import fixes if required for honest `forge build`

Validation:

- `forge build` passed.
- `forge test -vvv` passed command execution and reported no tests found.
- `make check` passed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `git check-ignore -v out/ cache/ broadcast/ .venv-tools/ .env.local` confirmed generated/local artifacts are ignored.
- Claude fix pass validation: `bash -n scripts/bootstrap-ec2.sh`, `bash -n scripts/check.sh`, PowerShell parser check for `scripts\bootstrap-windows.ps1`, `make -n slither`, and env-template ignore checks passed.
- CodeRabbit CI hardening validation: GitHub Actions references are pinned to 40-character SHAs, `actions/checkout` uses `persist-credentials: false`, `git diff --check` passed, `make check` passed, and `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- Remote validation: GitHub Actions CI passed on `8944025167a65e120f8e46899d65e3f9cfbbd150`, CodeRabbit reported no actionable comments on the latest pass, and all visible review threads were resolved.

Outcome:

- Merged as PR #4 on `2026-06-09 23:33 UTC`.
- Merge commit: `0d9438444fc860df98532ba0ecd3d9c77b2c4655`.
- Latest head before merge: `a4faac0916a4a165ace5a623d1a4a6647ee1493c`.

### PR #5: Repo maturity and contributor docs (Queue Item 3)

Status: Merged.
Branch: `codex/ci-review-hardening`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/5`.

Goal:

- Add security reporting policy with honest pre-audit warnings.
- Add contributor workflow and PR expectations.
- Add GitHub issue forms for bugs and roadmap items.
- Add PR template with validation, maturity, and review-clean checkboxes.
- Add CODEOWNERS so GitHub can route reviews once branch protection is enabled.
- Link the new docs from the README and status docs.

Candidate files:

- `SECURITY.md`
- `CONTRIBUTING.md`
- `.gitattributes`
- `.github/CODEOWNERS`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/roadmap_item.yml`
- `.github/workflows/ci.yml`
- `README.md`
- `docs/status.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- `git diff --check` passed.
- GitHub issue forms and CI workflow parse as YAML.
- Touched docs/templates/workflow files contain no tabs or non-ASCII
  characters.
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh` passed.
- PowerShell parser check passed for `scripts\check.ps1` and
  `scripts\bootstrap-windows.ps1`.
- `make check` passed with the known existing compiler/NatSpec warnings and
  empty-test baseline.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with the
  known existing warnings and empty-test baseline.
- Claude review fix validation: workflow YAML parsed, all workflow actions
  remained pinned to commit SHAs, `git diff --check origin/main...HEAD` passed,
  each Bash script was checked individually with `bash -n`, PowerShell scripts
  were checked with `System.Management.Automation.Language.Parser`, `make check`
  passed, and `scripts\check.ps1` passed.
- GitHub CI run `27243804024` passed on head
  `5b23c633e8aaef3a894a4e8b1ada3595f39c039a`.
- CodeRabbit completed successfully with no actionable comments on head
  `5b23c633e8aaef3a894a4e8b1ada3595f39c039a`.
- Claude review threads were resolved after the CI hygiene fixes landed.
- GitHub CI run `27243970322` passed on final head
  `20b147e8e0b25bf444bc94e6b926d8ea8035cbd3`.

Outcome:

- Merged as PR #5 on `2026-06-10 00:10 UTC`.
- Merge commit: `f244687711bac5becf2ab4ce90d58b6f00a8a5d1`.
- Latest head before merge: `20b147e8e0b25bf444bc94e6b926d8ea8035cbd3`.

### PR #6: Characterization test skeleton (Queue Item 4)

Status: Merged.
Branch: `codex/characterization-test-skeleton`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/6`.

Goal:

- Turn the empty Foundry test baseline into real executable characterization
  tests.
- Add self-contained test helpers and mocks without introducing a new external
  dependency.
- Lock current admin and drop behavior before P0 authorization, auction, and
  payment rewrites.
- Document that some passing behavior is known-unsafe and exists as a
  regression tripwire, not as an endorsement.

Candidate files:

- `test/helpers/Assertions.sol`
- `test/helpers/CharacterizationTestBase.sol`
- `test/helpers/StreamFixture.sol`
- `test/mocks/MockRandomizer.sol`
- `test/mocks/MockStreamMinter.sol`
- `test/StreamAdmins.t.sol`
- `test/StreamCoreAdminCharacterization.t.sol`
- `test/StreamDropsCharacterization.t.sol`
- `test/StreamDropsIntegrationCharacterization.t.sol`
- `test/README.md`
- `docs/status.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- `make check` passed with 17 tests passing and the known existing
  compiler/NatSpec/lint warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 17
  tests passing and the known existing warnings.
- `forge fmt --check test` passed.
- `git diff --check` passed.
- CodeRabbit follow-up validation: focused
  `forge test --match-contract StreamDropsIntegrationCharacterizationTest -vvv`
  passed with 7 integration characterization tests, and full `make check` plus
  `scripts\check.ps1` passed with 17 tests.
- Direct `forge` is still not available on the raw PowerShell `PATH`; the
  documented `make` and PowerShell wrapper paths resolve the installed Foundry
  binary.
- GitHub CI run `27246119762` passed on final head
  `0e037b3b33d144cce9d381a57a5a423fc1f3d8c0`.
- CodeRabbit completed successfully after the token-hash authorization fix.
- Claude was explicitly pinged on the final head; no new actionable Claude
  response arrived before merge, and prior Claude review threads were resolved
  or outdated.

Outcome:

- Merged as PR #6 on `2026-06-10 01:12 UTC`.
- Squash merge commit: `a2f0de7f70f748b81b04d7b4e6a35b20b6c2b720`.
- Latest head before merge: `0e037b3b33d144cce9d381a57a5a423fc1f3d8c0`.

### PR #7: Slither baseline appendix/config (Queue Item 5)

Status: Merged.
Branch: `codex/slither-baseline`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/7`.

Goal:

- Make Slither invocation reproducible through the pinned toolchain.
- Track the current high/medium Slither baseline in reviewable Markdown.
- Keep Slither non-gating until high/medium findings are fixed, accepted, or
  documented as false positives.
- Link the baseline from the roadmap, README, and tooling docs.

Candidate files:

- `slither.config.json`
- `.gitattributes`
- `.gitignore`
- `Makefile`
- `docs/slither.md`
- `docs/tooling.md`
- `docs/known-blockers.md`
- `README.md`
- `ops/SLITHER_BASELINE.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- Config-backed Slither run with pinned Slither `0.11.5` and Solidity `0.8.19`
  produced 530 total findings: 13 High, 26 Medium, 51 Low, 434 Informational,
  and 6 Optimization.
- Slither returned detector JSON successfully with `success: true` and exited
  `-1` because findings exist; this is expected before baseline acceptance.
- `python -m json.tool slither.config.json` passed.
- `make -n slither` prints
  `slither . --config-file slither.config.json --foundry-compile-all`.
- `git check-ignore` confirms Slither JSON/SARIF/triage report outputs are
  ignored.
- `.gitattributes` pins JSON files to LF line endings for the new Slither
  config.
- Markdown heading scan passed for `docs/slither.md`,
  `ops/SLITHER_BASELINE.md`, and `ops/ROADMAP.md`.
- `make check` passed with 17 tests and the known existing warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 17
  tests and the known existing warnings.
- `git diff --cached --check` passed.
- CodeRabbit review follow-up added explicit `solc-select use 0.8.19`
  instructions, marked vendored library rows as `Needs Issue` with
  likely-false-positive/provenance wording, and assigned
  `P0-META-001` to the dependency-script packed-encoding row.
- Review follow-up validation passed: `python -m json.tool
  slither.config.json`, targeted `rg` checks, Markdown heading scan,
  `git diff --check`, and `make check`.
- GitHub CI run `27247319104` passed on final head
  `a0fa95b76c11b792ab941deeb0f8e947af46840a`.
- CodeRabbit completed successfully on the final head with no actionable
  comments.
- Claude was explicitly pinged twice on the PR; no actionable Claude response
  arrived before merge.

Outcome:

- Merged as PR #7 on `2026-06-10 01:41 UTC`.
- Squash merge commit: `3201bd1758232554e47aecc95ad20a236aed10df`.
- Latest head before merge: `a0fa95b76c11b792ab941deeb0f8e947af46840a`.

### PR #8: Slither baseline issue links (Queue Item 6)

Status: Merged.
Branch: `codex/slither-issue-links`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/16`.

Goal:

- Replace Slither baseline `TBD` issue placeholders with canonical GitHub
  issues.
- Keep the baseline grouped by remediation stream so future PRs can link to a
  stable work item.
- Update the roadmap appendix and test matrix so issue traceability is visible
  from both roadmap and Slither baseline entry points.

Created GitHub issues:

- [#8](https://github.com/6529-Collections/6529Stream/issues/8)
  `P0-PAY-008`: bound emergency withdrawals and prove owed-balance invariants.
- [#9](https://github.com/6529-Collections/6529Stream/issues/9)
  `P0-META-001`: replace dependency-script packed concatenation.
- [#10](https://github.com/6529-Collections/6529Stream/issues/10)
  `P0-AUTH-002`: replace drop authorization with replay-safe EIP-712 typed
  data.
- [#11](https://github.com/6529-Collections/6529Stream/issues/11)
  `P0-LIB-001`: prove vendored library provenance or replace libraries.
- [#12](https://github.com/6529-Collections/6529Stream/issues/12)
  `P0-AUCT-002`: fix auction bidding reentrancy and outbid refunds.
- [#13](https://github.com/6529-Collections/6529Stream/issues/13)
  `P0-CORE-001`: resolve uninitialized mint-accounting state variables.
- [#14](https://github.com/6529-Collections/6529Stream/issues/14)
  `P0-RAND-ADR`: decide randomness provider model and weak-helper scope.
- [#15](https://github.com/6529-Collections/6529Stream/issues/15)
  `P0-INIT-001`: triage and resolve first-party uninitialized-local findings.

Candidate files:

- `ops/SLITHER_BASELINE.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- Slither baseline table check passed: every `Open` or `Needs Issue` row has a
  `github.com/6529-Collections/6529Stream/issues/` link in the Issue column.
- Markdown heading scan passed for `ops/SLITHER_BASELINE.md`,
  `ops/ROADMAP.md`, and `ops/AUTONOMOUS_RUN.md`.
- `git diff --check` passed.
- `make check` passed with 17 tests and the known existing warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 17
  tests and the known existing warnings.
- Opened PR #16 and explicitly pinged Claude for roadmap/ops-only review in
  comment `4665744494`.

Outcome:

- Merged as PR #16 on `2026-06-10 01:59 UTC`.
- Squash merge commit: `60635f26d13e37c976baf99dc00f6ad973ade591`.
- Latest head before merge: `7612152f64248934a9fca991d75a94d89fa9dcd2`.
- GitHub CI run `27247908498` passed on the final head.
- CodeRabbit completed successfully with no actionable comments.
- Claude was explicitly pinged twice; no actionable Claude response arrived
  before merge.

### PR #20: Drop authorization ADR (Queue Item 7)

Status: Merged.
Branch: `codex/drop-authorization-adr`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/20`.
Claude review request: issue comment `4665813753`.

Goal:

- Accept `docs/adr/0001-drop-authorization.md` before any P0 auth rewrite.
- Decide EIP-712 schema, recipient/payer semantics, replay protection, signer
  epoch, cancellation, signature malleability policy, ERC-1271 support, and
  `tx.origin` removal.
- Link the ADR from the roadmap and ADR index.

Created GitHub issues:

- [#17](https://github.com/6529-Collections/6529Stream/issues/17)
  `P0-AUTH-ADR`: accept drop authorization design.
- [#18](https://github.com/6529-Collections/6529Stream/issues/18)
  `P0-AUTH-001`: remove `tx.origin` from drop execution.
- [#19](https://github.com/6529-Collections/6529Stream/issues/19)
  `P0-AUTH-003`: implement ERC-1271 contract signer support.

Candidate files:

- `docs/adr/0001-drop-authorization.md`
- `docs/adr/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- `rg -n "^#|^##|^###" docs\adr\0001-drop-authorization.md docs\adr\README.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
  passed.
- `rg -n "P0-AUTH-ADR|P0-AUTH-001|P0-AUTH-002|P0-AUTH-003|0001-drop-authorization" docs\adr\0001-drop-authorization.md docs\adr\README.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
  passed.
- `git diff --check` passed.
- `make check` passed with 17 tests and known compiler warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with
  17 tests and known compiler warnings.
- Quantity review validation: `rg` traceability for `quantity` and EIP-712
  version-bump text passed, Markdown heading scan passed, `git diff --check`
  passed, `make check` passed with 17 tests and known warnings, and
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 17
  tests and known warnings.

Review feedback:

- CodeRabbit review `4463940875` / thread `PRRT_kwDOM7REis6IVwJC`
  requested clarification of `nonce` versus `dropId`; the ADR now defines
  `nonce` as the signer-allocated opaque input within `signerEpoch`, `salt` as
  drop-ID entropy, and `dropId` as the derived replay/cancellation key.
- Claude threads `PRRT_kwDOM7REis6IVySB`, `PRRT_kwDOM7REis6IVySE`, and
  `PRRT_kwDOM7REis6IVySG` requested explicit `salt`/`nonce` semantics, raw
  `tokenData` hash enforcement, and sale-mode-specific `recipient` semantics;
  the ADR now defines all three and adds corresponding required tests.
- CodeRabbit follow-up requested that this file's `Last updated` field keep
  pace with the latest PR #20 decision-log entries; the timestamp is now
  updated to `2026-06-10 02:31 UTC`.
- Claude thread `PRRT_kwDOM7REis6IV4bb` requested explicit `quantity`
  semantics; the ADR now constrains P0 authorizations to `quantity == 1`, makes
  `quantity != 1` a rejection case, and requires a later ADR plus EIP-712
  version bump before batch semantics are introduced.

Outcome:

- Merged as PR #20 on `2026-06-10 02:40 UTC`.
- Squash merge commit: `314cba14ffe970d95642544aac24c9c67d7d9a2d`.
- Latest head before merge: `a92b6c4f7c1d8b16817cd311b2bd22c5e061f4f5`.
- GitHub CI run `27249243361` passed on the final head.
- CodeRabbit completed successfully with no actionable comments on the final
  head.
- Claude review threads were addressed and resolved before merge.

### PR #23: Auction custody ADR (Queue Item 8)

Status: Merged.
Branch: `codex/auction-custody-adr`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/23`.
Claude review request: issue comment `4666002050`.

Goal:

- Accept `docs/adr/0002-auction-custody.md` before any P0 auction rewrite.
- Decide escrow custody, canonical auction state, settlement actor, no-bid
  recipient, cancellation, payment-accounting dependency, and event/indexer
  requirements.
- Link the ADR from the roadmap and ADR index.

Created GitHub issues:

- [#21](https://github.com/6529-Collections/6529Stream/issues/21)
  `P0-AUCT-ADR`: accept auction custody design.
- [#22](https://github.com/6529-Collections/6529Stream/issues/22)
  `P0-AUCT-001`: formalize auction custody, settlement, and lifecycle state
  machine.

Related existing issues:

- [#12](https://github.com/6529-Collections/6529Stream/issues/12)
  `P0-AUCT-002`: fix auction bidding reentrancy and outbid refunds.
- [#8](https://github.com/6529-Collections/6529Stream/issues/8)
  `P0-PAY-008`: bound emergency withdrawals and prove owed-balance invariants.

Candidate files:

- `docs/adr/0001-drop-authorization.md`
- `docs/adr/0002-auction-custody.md`
- `docs/adr/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- Markdown heading scan passed for `docs\adr\0002-auction-custody.md`,
  `docs\adr\README.md`, `ops\ROADMAP.md`, and `ops\AUTONOMOUS_RUN.md`.
- Auction traceability scan passed for `P0-AUCT-ADR`, `P0-AUCT-001`,
  `P0-AUCT-002`, `0002-auction-custody`, issue links, and canonical auction
  states.
- `git diff --check` passed.
- `make check` passed with 17 tests and known compiler/NatSpec warnings after
  payment issue-link traceability updates.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with
  17 tests and known compiler/NatSpec warnings after payment issue-link
  traceability updates.
- Late Claude PR #20 cleanup validation passed for canonical
  `DROP_ID_TYPEHASH`, sale-mode-specific payer/price/auction fields, zero
  poster, and poster/signature semantics.
- After the ADR 0001 cleanup, `git diff --check`, `make check`, and
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed again
  with 17 tests and known compiler/NatSpec warnings.
- Claude state-machine cleanup validation passed for explicit
  `Created -> Active` trigger semantics, `custodyConfirmed` storage shape,
  derived status inputs, and bid-before-custody rejection coverage.
- After the ADR 0002 state-machine cleanup, `git diff --check`, `make check`,
  and `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed
  again with 17 tests and known compiler/NatSpec warnings.
- Claude follow-up cleanup validation passed for no-bid NFT claim fallback
  semantics, the auction `recipient == address(0)` cross-ADR rule, the
  first-bid cancellation guard in the state table, and event/test traceability.
- After the final ADR 0002 cleanup, focused traceability scans, `git diff
  --check`, `make check`, and
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed again
  with 17 tests and known compiler/NatSpec warnings.

Review feedback:

- CodeRabbit completed successfully on head `16d7296` with no actionable
  comments before the late ADR 0001 cleanup commit.
- Late Claude threads on merged PR #20 requested a canonical
  `DROP_ID_TYPEHASH` preimage plus explicit `payer`, sale-mode price, and
  `poster` semantics. Those still-valid comments are addressed in this PR so
  the accepted drop-authorization ADR remains implementation-ready.
- Claude thread `PRRT_kwDOM7REis6IWKpg` requested an explicit
  `Created -> Active` trigger and a storage/view shape that can distinguish
  created auctions from custody-confirmed active auctions. ADR 0002 now makes
  custody confirmation observable through `custody != address(0)` or explicit
  `custodyConfirmed`, adds those fields to derived status inputs, and requires
  tests for activation plus bid rejection before custody is confirmed.
- Claude thread `PRRT_kwDOM7REis6IWRh5` requested explicit no-bid outbound
  transfer mechanics for contract posters. ADR 0002 now requires a pull-style
  NFT claim fallback, records `pendingNoBidNftClaimant`, and requires events
  plus tests for pending and completed no-bid NFT claims.
- Claude thread `PRRT_kwDOM7REis6IWRh7` requested the first-bid cancellation
  guard inside the canonical state table. The `Active` row now permits
  `Cancelled` only before the first valid bid.
- Claude thread `PRRT_kwDOM7REis6IWRh-` requested closure of ADR 0001's
  deferred auction `recipient` rule. ADR 0002 now keeps auction
  `recipient == address(0)`, rejects non-zero signed auction recipients, and
  derives settlement recipients from `poster` and `highestBidder`.
- Final CI passed on run `27250789199`.
- CodeRabbit completed successfully on the final head.
- Claude review threads were addressed and resolved before merge.
- Late Claude PR #20 review threads were also addressed and resolved after PR
  #23 merged, because PR #23 had already updated ADR 0001 with the requested
  field semantics and canonical `DROP_ID_TYPEHASH`.

Outcome:

- Merged as PR #23 on `2026-06-10 03:22 UTC`.
- Squash merge commit:
  `e65a6814e55c7638f55c6de0714fd56296480e51`.
- Latest head before merge:
  `6bfa7c79e3565adf47dd8f7d9dbb0578594c067c`.
- GitHub CI run `27250789199` passed on the final head.
- CodeRabbit completed successfully with no actionable comments on the final
  head.
- Claude review threads were addressed and resolved before merge.

### PR #32: Payment accounting ADR (Queue Item 9)

Status: Merged.
Branch: `codex/payment-accounting-adr`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/32`.
Claude review request: issue comment `4666247442`.

Goal:

- Accept `docs/adr/0003-payment-accounting.md` before any P0 pull-payment,
  emergency-withdrawal, or auction payment rewrite.
- Decide credit categories, owed-balance totals, surplus, withdrawal semantics,
  failed-withdrawal behavior, forced/direct ETH handling, emergency withdrawal
  limits, events, invariants, and test requirements.
- Link the ADR from the roadmap and ADR index.

Created GitHub issues:

- [#24](https://github.com/6529-Collections/6529Stream/issues/24)
  `P0-PAY-ADR`: accept payment accounting design.
- [#25](https://github.com/6529-Collections/6529Stream/issues/25)
  `P0-PAY-001`: add pull-payment accounting.
- [#26](https://github.com/6529-Collections/6529Stream/issues/26)
  `P0-PAY-002`: add credit ledger storage and total-owed views.
- [#27](https://github.com/6529-Collections/6529Stream/issues/27)
  `P0-PAY-003`: convert fixed-price payouts to credits.
- [#28](https://github.com/6529-Collections/6529Stream/issues/28)
  `P0-PAY-004`: convert auction outbid refunds to credits.
- [#29](https://github.com/6529-Collections/6529Stream/issues/29)
  `P0-PAY-005`: convert curator reward claims to credits.
- [#30](https://github.com/6529-Collections/6529Stream/issues/30)
  `P0-PAY-006`: add withdrawal functions and failed-withdrawal behavior.
- [#31](https://github.com/6529-Collections/6529Stream/issues/31)
  `P0-PAY-007`: bound emergency withdrawals by surplus.

Related existing issues:

- [#8](https://github.com/6529-Collections/6529Stream/issues/8)
  `P0-PAY-008`: bound emergency withdrawals and prove owed-balance invariants.
- [#12](https://github.com/6529-Collections/6529Stream/issues/12)
  `P0-AUCT-002`: fix auction bidding reentrancy and outbid refunds.
- [#22](https://github.com/6529-Collections/6529Stream/issues/22)
  `P0-AUCT-001`: formalize auction custody, settlement, and lifecycle state
  machine.

Candidate files:

- `docs/adr/0003-payment-accounting.md`
- `docs/adr/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- Markdown heading scan passed for `docs/adr/0003-payment-accounting.md`,
  `docs/adr/README.md`, `ops/ROADMAP.md`, and `ops/AUTONOMOUS_RUN.md`.
- Payment traceability scan passed for issue #24, `P0-PAY-ADR`,
  `0003-payment-accounting`, `totalAuctionBidEscrow`,
  `totalRandomnessReserved`, `emergencyWithdrawable`, failed withdrawals,
  forced ETH, and the intended payment test files.
- `git diff --check` passed.
- `make check` passed with 17 tests and known compiler/NatSpec warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with
  17 tests and known compiler/NatSpec warnings.
- GitHub CI run `27251741547` passed on head
  `e160bda2fb0c9898ff05b6f35f90333f86a2f479`.

Review feedback:

- CodeRabbit completed successfully on head
  `e160bda2fb0c9898ff05b6f35f90333f86a2f479` with no actionable comments and
  all five pre-merge checks passing.
- Claude review was explicitly requested in issue comment `4666247442`, but
  Claude returned `Code review skipped` because the organization's Claude Code
  overage spend limit was reached. This is an external billing/admin condition,
  so PR #32 proceeds under autonomous maintainer decision after local,
  sidecar, CI, and CodeRabbit review.
- No inline review threads are open.

Outcome:

- Merged as PR #32 on `2026-06-10 03:59 UTC`.
- Squash merge commit:
  `a22b1d9c966f8e20420a62f9bae63279f2daf5b3`.
- Latest head before merge:
  `4ee5d8d503e47fe482d1fad175b031eaba2ebad4`.
- GitHub CI run `27252081065` passed on the final head.
- CodeRabbit completed successfully with no actionable comments on the final
  head.
- Claude review was unavailable because the organization's Claude Code overage
  spend limit was reached; the explicit request is recorded above.

### PR #36: Admin/governance ADR (Queue Item 10)

Status: Merged.
Branch: `codex/admin-governance-adr`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/36`.
Claude review request: issue comment `4666434728`.

Goal:

- Accept `docs/adr/0004-admin-governance.md` before any P0 permission,
  selector, signer-lifecycle, pause, or emergency-control rewrite.
- Decide the production root authority, role model, function-admin target
  scoping, collection-admin stance, signer manager, pause domains, withdrawal
  pause policy, surplus-only emergency controls, event requirements, and tests.
- Link the ADR from the roadmap and ADR index.

Created GitHub issues:

- [#33](https://github.com/6529-Collections/6529Stream/issues/33)
  `P0-ADMIN-ADR`: accept admin and governance design.
- [#34](https://github.com/6529-Collections/6529Stream/issues/34)
  `P0-ADMIN-001`: fix admin selector mismatch and permission model.
- [#35](https://github.com/6529-Collections/6529Stream/issues/35)
  `P0-ADMIN-002`: define and implement pause and emergency controls.

Candidate files:

- `docs/adr/0004-admin-governance.md`
- `docs/adr/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- Markdown heading scan passed for `docs/adr/0004-admin-governance.md`,
  `docs/adr/README.md`, `ops/ROADMAP.md`, and `ops/AUTONOMOUS_RUN.md`.
- Admin/governance traceability scan passed for issues #33 through #35,
  `P0-ADMIN-ADR`, `0004-admin-governance`, target-scoped function admins,
  signer lifecycle, pause controls, `emergencyWithdrawable`, and the intended
  admin test files.
- Sidecar read-only governance review completed; findings about
  `updateCollectionInfo`, `setMultipleMerkleRoots`, missing target-contract
  selector scope, stale collection-admin interface, non-rotatable
  `StreamAdmins.tdhSigner`, and `owner()` emergency-recipient ambiguity were
  folded into the ADR and roadmap.
- `git diff --check` passed.
- `make check` passed with 17 tests and known compiler/NatSpec warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with
  17 tests and known compiler/NatSpec warnings.

Review feedback:

- GitHub CI run `27252679337` passed on head
  `6e4455654c46027cfe0046478e8df5d715e13099`.
- CodeRabbit completed successfully on head
  `6e4455654c46027cfe0046478e8df5d715e13099` with no actionable comments
  and all five pre-merge checks passing.
- Claude review was explicitly requested in issue comment `4666434728`, but
  Claude returned `Code review skipped` because the organization's Claude Code
  overage spend limit was reached. This is an external billing/admin condition,
  so PR #36 proceeds under autonomous maintainer decision after local,
  sidecar, CI, and CodeRabbit review.
- No inline review threads are open.

Outcome:

- Merged as PR #36 on `2026-06-10 04:24 UTC`.
- Squash merge commit:
  `8ee2dca0af2ffa989aec073fbec764a81eb868aa`.
- Latest head before merge:
  `d29569fee2d445b47888839278c54d32a5ba3e29`.
- GitHub CI run `27253041315` passed on the final head.
- CodeRabbit completed successfully with no actionable comments on the final
  head.
- Claude review was unavailable because the organization's Claude Code overage
  spend limit was reached; the explicit request is recorded above.

### PR #44: Randomness ADR (Queue Item 11)

Status: Merged.
Branch: `codex/randomness-adr`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/44`.
Claude review request: issue comment `4666596095`.

Goal:

- Accept `docs/adr/0005-randomness.md` before any P0 randomizer callback,
  provider, request-lifecycle, or weak-helper randomness rewrite.
- Decide the production provider model, request lifecycle, callback validation,
  randomizer epoch, stale callback handling, migration policy, retry limits,
  seed storage, provider accounting, and weak-helper scope.
- Link the ADR from the roadmap, ADR index, Slither baseline, and test matrix.

Created GitHub issues:

- [#37](https://github.com/6529-Collections/6529Stream/issues/37)
  `P0-RAND-001`: harden randomizer requests and callbacks.
- [#38](https://github.com/6529-Collections/6529Stream/issues/38)
  `P0-RAND-002`: add randomness request lifecycle storage and views.
- [#39](https://github.com/6529-Collections/6529Stream/issues/39)
  `P0-RAND-003`: validate randomness callbacks by request, token, collection,
  provider, and epoch.
- [#40](https://github.com/6529-Collections/6529Stream/issues/40)
  `P0-RAND-004`: add pending, fulfilled, stale, and failed randomness states.
- [#41](https://github.com/6529-Collections/6529Stream/issues/41)
  `P0-RAND-005`: define and test randomizer migration with pending requests.
- [#42](https://github.com/6529-Collections/6529Stream/issues/42)
  `P0-RAND-006`: add bounded manual retry for deterministic randomness
  post-processing failures.
- [#43](https://github.com/6529-Collections/6529Stream/issues/43)
  `P0-RAND-007`: decide and implement raw random words versus derived hash
  storage policy.

Candidate files:

- `docs/adr/0005-randomness.md`
- `docs/adr/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- Markdown heading scan passed for `docs/adr/0005-randomness.md`,
  `docs/adr/README.md`, `ops/ROADMAP.md`, `ops/SLITHER_BASELINE.md`, and
  `ops/AUTONOMOUS_RUN.md`.
- Randomness traceability scan passed for issue #14, issues #37 through #43,
  `P0-RAND-ADR`, `0005-randomness`, `randomizerEpoch`,
  `RandomizerNXT`, `XRandoms`, `weak-prng`, `RandomnessRequested`,
  `RandomnessFulfilled`, and `FailedPostProcessing`.
- ASCII scan passed for touched docs and ops files.
- `git diff --check` passed.
- Sidecar read-only randomness review completed; findings about mint-before-
  randomness zero-hash observability, on-chain zero-hash metadata, nonzero hash
  validation, provider-origin versus semantic callback validation, weak helper
  scope, reserve accounting, and ADR 0004 pause compatibility were folded into
  the ADR and roadmap.
- `make check` passed with 17 tests and known compiler/NatSpec warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with
  17 tests and known compiler/NatSpec warnings.

Review feedback:

- GitHub CI run `27253743069` passed on final head
  `5a95055e4c3c2538fb1b4957b6150630f8e19932`.
- CodeRabbit completed successfully on final head
  `5a95055e4c3c2538fb1b4957b6150630f8e19932` with no actionable comments
  and all five pre-merge checks passing.
- Claude review was explicitly requested in issue comment `4666596095`, but
  Claude returned `Code review skipped` because the organization's Claude Code
  overage spend limit was reached.
- No inline review threads are open.

Outcome:

- Merged as PR #44 on `2026-06-10 04:50 UTC`.
- Squash merge commit:
  `dd98e914e20a4f3849ad1ae41a4e9698023a1e7d`.
- Latest head before merge:
  `5a95055e4c3c2538fb1b4957b6150630f8e19932`.
- GitHub CI run `27253743069` passed on the final head.
- CodeRabbit completed successfully with no actionable comments on the final
  head.
- Claude review was unavailable because the organization's Claude Code overage
  spend limit was reached; the explicit request is recorded above.

### PR #52: Metadata/freeze ADR (Queue Item 12)

Status: Merged.
Branch: `codex/metadata-freeze-adr`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/52`.
Claude review request: issue comment `4666753358`.

Goal:

- Accept `docs/adr/0006-metadata-freeze.md` before any P1 metadata schema,
  freeze, dependency immutability, burn metadata, ERC-4906, or dependency
  packed-encoding implementation work.
- Decide pending/final metadata behavior, freeze boundaries, dependency
  registry versioning and immutability, mutable token data policy, burn
  metadata, ERC-4906 event semantics, metadata update authorization, JSON/HTML
  escaping, and golden-file test requirements.
- Link the ADR from the roadmap, ADR index, Slither baseline, and test matrix.

Created GitHub issues:

- Existing [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9):
  dependency-script packed/dynamic composition.
- [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45):
  accept metadata, dependency, freeze, and burn design.
- [`P1-META-001`](https://github.com/6529-Collections/6529Stream/issues/46):
  metadata schema and golden-file tests.
- [`P1-META-002`](https://github.com/6529-Collections/6529Stream/issues/47):
  collection freeze boundaries and immutable metadata state.
- [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48):
  dependency registry versioning, immutability, and provenance.
- [`P1-META-004`](https://github.com/6529-Collections/6529Stream/issues/49):
  ERC-4906 metadata update signaling.
- [`P1-META-005`](https://github.com/6529-Collections/6529Stream/issues/50):
  burn metadata and supply semantics.
- [`P1-META-006`](https://github.com/6529-Collections/6529Stream/issues/51):
  metadata escaping, size limits, and render-sandbox tests.

Candidate files:

- `docs/adr/0006-metadata-freeze.md`
- `docs/adr/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- `rg -n "^#|^##|^###" docs\adr\0006-metadata-freeze.md docs\adr\README.md ops\ROADMAP.md ops\SLITHER_BASELINE.md ops\AUTONOMOUS_RUN.md`
  passed and confirmed heading structure.
- Traceability grep for `P1-META-ADR`, issues #45 through #51, issue #9,
  `ERC-4906`, `0x49064906`, `MetadataUpdate`, `BatchMetadataUpdate`,
  dependency version events, freeze events, and burned-token callback events
  passed.
- ASCII scan passed for the touched docs.
- `git diff --check` passed.
- `make check` passed with 17 tests passing and the existing Solidity warning
  baseline still present.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 17
  tests passing and the existing Solidity warning baseline still present.
- After CodeRabbit's style nitpick, targeted grep confirmed the repeated
  migration wording and `very careful` phrasing were removed; `git diff
  --check`, `make check`, and the Windows wrapper passed again.
- After CodeRabbit's pre-implementation clarity review, targeted grep confirmed
  freeze eligibility, manifest hash encoding, burn/ERC-4906 semantics,
  post-burn callback behavior, size-limit ownership, generated HTML proofing,
  and Gate B2 status; `git diff --check`, `make check`, and the Windows wrapper
  passed again on head `8058c20258c064356c3b7c3f102608f17c501978`.

Review feedback:

- GitHub CI passed on final head
  `8058c20258c064356c3b7c3f102608f17c501978`.
- CodeRabbit requested one optional prose nitpick in review `4464741958`; the
  nitpick was addressed in commit
  `be29ccfe006204bdafccc38b96250c4ddc52cf05`.
- CodeRabbit then identified seven pre-implementation clarity gaps in comment
  `4666800683`; the gaps were addressed in commit
  `8058c20258c064356c3b7c3f102608f17c501978`.
- CodeRabbit completed successfully with no actionable comments on the final
  head.
- Claude review was explicitly requested in issue comment `4666753358` and was
  unavailable because the organization's Claude Code overage spend limit was
  reached.

Outcome:

- Merged as PR #52 on `2026-06-10 05:32 UTC`.
- Squash merge commit:
  `623e447baa9df90f3add1ddf4f2ec1c4ef09a869`.
- Latest head before merge:
  `4e8cab6d488b0602f6d497090d8106b5eb3e8dfb`.
- GitHub CI passed on the final head.
- CodeRabbit completed successfully with no actionable comments on the final
  head.
- Claude review was unavailable because the organization's Claude Code overage
  spend limit was reached; the explicit request is recorded above.

### PR #54: Upgrade/redeployment ADR (Queue Item 13)

Status: Merged.
Branch: `codex/upgrade-redeployment-adr`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/54`.
Claude review request: issue comment `4666936783`.

Goal:

- Accept `docs/adr/0007-upgrade-redeployment.md` before deployment, manifest,
  release, deprecation, emergency redeployment, proxy, storage-layout, or
  migration work.
- Decide public-beta immutable redeployment policy, proxy out-of-scope status,
  deployment lifecycle states, manifest requirements, state handoff boundaries,
  breaking-change rules, emergency redeployment requirements, and release
  artifact evidence.
- Link the ADR from the roadmap, ADR index, and test matrix.

Created GitHub issues:

- [`P2-UPGRADE-ADR`](https://github.com/6529-Collections/6529Stream/issues/53):
  accept upgrade and redeployment strategy.

Candidate files:

- `docs/adr/0007-upgrade-redeployment.md`
- `docs/adr/0006-metadata-freeze.md`
- `docs/adr/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- Markdown heading scan passed for `docs/adr/0006-metadata-freeze.md`,
  `docs/adr/0007-upgrade-redeployment.md`, `docs/adr/README.md`,
  `ops/ROADMAP.md`, and `ops/AUTONOMOUS_RUN.md`.
- Traceability grep passed for `P2-UPGRADE-ADR`, issue #53,
  `0007-upgrade-redeployment`, immutable redeployments, proxy policy,
  `verifyingContract`, deployment manifests, emergency redeployment, Gate B2,
  and the deployment rehearsal test-matrix row.
- ASCII scan passed for touched docs and ops files.
- `git diff --check` passed.
- Sidecar read-only upgrade/redeployment review completed; findings about
  immutable redeployment posture, no proxy public-beta policy, manifest
  contents, versioning, breaking-change definitions, ADR 0001-0006
  consistency, Gate E/F/G evidence, and tests were folded into ADR 0007.
- Sidecar read-only roadmap/state review completed; stale PR #52 state was
  updated, issue #53 was linked, and ADR 0006 now links ADR 0007.
- `make check` passed with 17 tests passing and the existing Solidity warning
  baseline still present.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 17
  tests passing and the existing Solidity warning baseline still present.

Review feedback:

- GitHub CI run `27255914626` passed on head
  `8b0c8809c5bfeccb04d8e788da4622f4a6b3dd14`.
- CodeRabbit completed successfully according to GitHub PR checks with no
  review threads open.
- Claude review was requested in issue comment `4666936783`, but Claude was
  unavailable because the organization's Claude Code overage spend limit was
  reached.

Outcome:

- Merged as PR #54 on `2026-06-10 05:52 UTC`.
- Squash merge commit `d06b48f1b581871a0e25dd9ac19fb068365bfeee`.
- Latest head before merge `8b0c8809c5bfeccb04d8e788da4622f4a6b3dd14`.
- GitHub CI and CodeRabbit passed.
- Claude unavailable due to organization overage.

### PR `#55`: Remove `tx.origin` from drop execution (Queue Item 14)

Status: Merged.
Branch: `codex/remove-tx-origin-drop-execution`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/55`.
Claude review request: issue comment `4667155915`.

Goal:

- Remove executable `tx.origin` usage from `StreamDrops`.
- Add explicit fixed-price recipient and execution-address storage.
- Keep auction recipient reserved as `address(0)` according to ADR 0001/0002
  until settlement-specific authorization lands.
- Store the current poster-based auction execution fallback so no-bid
  settlement does not target `address(0)`.
- Update target-state characterization tests for explicit recipient,
  zero-recipient rejection, non-zero auction-recipient rejection, no-bid
  settlement, and contract-based execution.
- Preserve broader EIP-712 signature, replay, and field-substitution work for
  `P0-AUTH-002`.

Candidate files:

- `smart-contracts/StreamDrops.sol`
- `smart-contracts/IArrngController.sol`
- `test/StreamDropsCharacterization.t.sol`
- `test/StreamDropsIntegrationCharacterization.t.sol`
- `test/helpers/CharacterizationTestBase.sol`
- `test/helpers/StreamFixture.sol`
- `test/StreamAdmins.t.sol`
- `test/README.md`
- `docs/known-blockers.md`
- `docs/adr/0001-drop-authorization.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- `forge test --match-contract StreamDropsCharacterizationTest -vvv` passed
  with 9 tests.
- `forge test --match-contract StreamDropsIntegrationCharacterizationTest -vvv`
  passed with 10 tests.
- `make check` passed with 24 tests.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 24
  tests.
- `forge fmt --check` passed for the formatted touched Solidity files; the
  provider interface comment diff preserves its existing style to avoid
  unrelated formatting churn.
- `git diff --check` passed.
- `rg -n "tx\.origin" smart-contracts` returned no matches.
- Stale signature grep passed for legacy drop function signatures and old
  fixed-price test names.
- Heading and traceability greps passed for the touched roadmap, ADR, state, and
  Slither baseline files.
- Sidecar read-only review completed; auction no-bid settlement and non-zero
  auction-recipient findings were folded into code and tests.

Review feedback:

- GitHub CI run `27257368139` passed on initial head
  `9dbcc5e09651eb130a3e64a8330d2a0d6dc931fd`.
- Claude review was requested in issue comment `4667155915`, but Claude was
  unavailable because the organization's Claude Code overage spend limit was
  reached.
- CodeRabbit review `4465140842` requested a concrete PR number in this run
  log and a zero-poster rejection in `StreamDrops.mintDrop`.
- Follow-up fix added the concrete PR heading and rejects zero-poster fixed-price
  and auction drops, with characterization tests for both paths.
- GitHub CI run `27257963206` passed on final head
  `1e09d7ab6a67e7c8b8cffbf338ca85cd9ebb08de`.
- CodeRabbit reported no further actionable comments on the final head.

Outcome:

- Merged as PR #55 on `2026-06-10 06:46 UTC`.
- Squash merge commit `f7e34ee264f5a8caf6693c83a167dbf4cc028340`.
- Latest head before merge `1e09d7ab6a67e7c8b8cffbf338ca85cd9ebb08de`.
- Issue #18 closed as completed.
- GitHub CI and CodeRabbit passed.
- Claude unavailable due to organization overage.

### PR #56: Replace drop authorization with EIP-712 (Queue Item 15)

Status: Merged.
Branch: `codex/eip712-drop-authorization`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/56`.
Related issue: `https://github.com/6529-Collections/6529Stream/issues/10`.
Claude review request: issue comment `4667572552`.

Goal:

- Replace legacy packed drop IDs and signer-only execution with EIP-712
  `DropAuthorization` typed data.
- Bind drop execution to `name`, `version`, `chainId`, and `verifyingContract`.
- Add storage-backed consumed and cancelled drop IDs.
- Add signer epoch rotation and per-drop cancellation controls.
- Support EOA signatures and EIP-2098 compact signatures with low-`s`, valid
  `v`, and zero-recovered-signer checks.
- Explicitly reject contract signers until `P0-AUTH-003` adds ERC-1271 support.
- Remove `retrieveMessageAndDropID` and the old
  `mintDrop(address,address,string,uint256,uint256,uint256,uint256)` execution
  surface.
- Update roadmap, ADR, Slither baseline, blockers, and tests.

Candidate files:

- `smart-contracts/StreamDrops.sol`
- `test/StreamDropsCharacterization.t.sol`
- `test/StreamDropsIntegrationCharacterization.t.sol`
- `test/StreamDropsEIP712.t.sol`
- `test/StreamAdmins.t.sol`
- `test/helpers/CharacterizationTestBase.sol`
- `test/helpers/DropAuthTestHelper.sol`
- `test/README.md`
- `docs/known-blockers.md`
- `docs/adr/0001-drop-authorization.md`
- `README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- `forge test --match-contract StreamDropsEIP712Test -vvv` passed with 23
  tests.
- `forge test --match-contract StreamAdminsTest -vvv` passed with 4 tests.
- `make check` passed with 47 tests and the known Solidity warning baseline.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 47
  tests and the known Solidity warning baseline.
- `forge fmt --check` passed for all touched Solidity files.
- `git diff --check` passed.
- Markdown heading scan passed for touched README, docs, roadmap, Slither
  baseline, and autonomous state files.
- Executable legacy-surface grep over `smart-contracts` and `test` found no
  `retrieveMessageAndDropID`, old `mintDrop(address,address,string,...)`,
  `dropExecuted`, `MintsToTxOrigin`, or `tx.origin` matches.
- `make slither` returned non-zero as expected because baseline findings remain;
  targeted log check confirmed the `StreamDrops` packed-hash findings are gone,
  only `StreamCore.retrieveDependencyScript` remains under
  `encode-packed-collision`, and `StreamDrops.mintDrop` no longer appears under
  `uninitialized-local`.

Review feedback:

- GitHub CI run `27259664728` passed on head
  `175c24929ac76e5cc5cece64786201dd47063745`.
- Claude review was requested in issue comment `4667572552`, but Claude was
  unavailable because the organization's Claude Code overage spend limit was
  reached.
- CodeRabbit initially remained pending on the review-processing note; follow-up
  command comment `4667699009` requested completion for the latest head.
- CodeRabbit status passed and reported no actionable comments on head
  `175c24929ac76e5cc5cece64786201dd47063745`.
- Follow-up CodeRabbit command review comment `4667722117` found duplicate
  cancellation events, five missing sale-mode negative tests, and missing event
  assertions.
- Follow-up fix added an `Already cancelled` guard, `DropAuthorizationConsumed`,
  `DropAuthorizationCancelled`, and `SignerEpochChanged` event assertions, and
  negative tests for free fixed-price payer, auction payer, fixed-price auction
  reserve, fixed-price auction end, and auction price field misuse.
- Focused EIP-712 suite now passes with 23 tests; `make check` and the Windows
  wrapper both pass with 47 tests.
- Final GitHub CI run `27260907183` passed on head
  `89af0599f2e14e3ea408170727daf75cdda93b24`.
- CodeRabbit reported no actionable comments on the final head.

Outcome:

- Merged as PR #56 on `2026-06-10 07:45 UTC`.
- Squash merge commit `a6ae314375532095f239ec90aa8a703408cf601e`.
- Latest head before merge `89af0599f2e14e3ea408170727daf75cdda93b24`.
- Issue #10 closed as completed.
- GitHub CI and CodeRabbit passed.
- Claude unavailable due to organization overage.

### PR #57: Implement ERC-1271 contract signer support (Queue Item 16)

Status: Merged.
Branch: `codex/erc1271-drop-authorization`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/57`.
Related issue: `https://github.com/6529-Collections/6529Stream/issues/19`.
Claude review request: issue comment `4667907301`.

Goal:

- Extend the EIP-712 drop authorization path so contract signers can approve the
  exact same digest through ERC-1271 `isValidSignature(bytes32,bytes)`.
- Preserve the existing EOA and EIP-2098 validation behavior.
- Require the ERC-1271 magic value and fail closed on invalid magic, malformed
  returns, and reverted signature checks.
- Add contract-signer target-state tests and update docs/roadmap state.

Candidate files:

- `smart-contracts/StreamDrops.sol`
- `test/StreamDropsERC1271.t.sol`
- `test/StreamDropsEIP712.t.sol`
- `test/README.md`
- `docs/known-blockers.md`
- `docs/adr/0001-drop-authorization.md`
- `README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation:

- `forge test --match-contract StreamDropsERC1271Test -vvv` passed with 12
  tests.
- `forge test --match-contract StreamDropsEIP712Test -vvv` passed with 23
  tests.
- `make check` passed with 59 tests and the known Solidity warning baseline.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 59
  tests and the known Solidity warning baseline.
- `forge fmt --check` passed for `smart-contracts\StreamDrops.sol`,
  `test\StreamDropsERC1271.t.sol`, and `test\StreamDropsEIP712.t.sol`.
- `git diff --check` passed.
- Markdown heading scan passed for touched README, docs, roadmap, and autonomous
  state files.
- Stale ERC-1271 pending-policy grep returned no active documentation or source
  matches outside historical run-log entries.

Review feedback:

- PR opened on head `73a2edf983772625f23ed92aefa1b7c542101696`.
- Claude review was explicitly requested in issue comment `4667907301`.
- Claude skipped review because the organization's overage spend limit had been
  reached.
- CodeRabbit reported 5 pre-merge checks passed and no actionable review
  threads.
- CodeRabbit's commit status remained pending after two explicit refresh
  requests; autonomous merge evidence was recorded in issue comment
  `4668031956` before merge.

Outcome:

- Merged as PR #57 on `2026-06-10 08:13 UTC`.
- Squash merge commit `cc66438b72ad8f7ec7a047cab9c7b8daaef406dc`.
- Latest head before merge `10f1c880b0572665b19cb1efeace0a697b1adda2`.
- Issue #19 closed as completed.
- GitHub CI passed; CodeRabbit review evidence was clean despite stale pending
  commit status.
- Claude unavailable due to organization overage.

### PR #58: Fix auction bidding reentrancy and outbid refunds (Queue Item 17)

Status: Merged.
Branch: `codex/auction-pull-credits`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/58`.
Related issue: `https://github.com/6529-Collections/6529Stream/issues/12`.
Claude review request: issue comment `4668219408`.

Goal:

- Remove the bid-path push refund from `StreamAuctions.participateToAuction`.
- Convert previous highest bids into withdrawable bidder credits.
- Keep highest-bid state and active bid escrow observable at all times.
- Add guarded bidder-credit withdrawals that preserve credit on failed transfer
  and cannot be overdrawn through reentrancy.
- Keep the PR scoped to issue #12; broader custody, final settlement credits,
  fixed-price pull payments, curator reward credits, and full emergency surplus
  boundaries remain separate P0 work.

Candidate files:

- `smart-contracts/AuctionContract.sol`
- `test/StreamAuctionPayments.t.sol`
- `test/README.md`
- `docs/known-blockers.md`
- `docs/adr/0002-auction-custody.md`
- `docs/adr/0003-payment-accounting.md`
- `ops/SLITHER_BASELINE.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- `participateToAuction` is now `nonReentrant` and no longer calls the previous
  bidder during outbid.
- Outbid bidders accrue `auctionBidderCredits`; `totalBidderOwed`,
  `totalAuctionBidEscrow`, `totalOwed`, and `emergencyWithdrawable` expose the
  auction-local accounting.
- `withdrawBidderCredit` and `withdrawBidderCreditTo` are guarded withdrawal
  paths; failed transfers revert and preserve credit.
- Auction emergency withdrawal can withdraw only `emergencyWithdrawable` surplus
  and skips external calls when there is no surplus.

Validation:

- `forge test --match-contract StreamAuctionPaymentsTest -vvv` passed with 10
  tests.
- `forge test --match-contract StreamDropsIntegrationCharacterizationTest -vvv`
  passed with 10 tests before the final doc correction pass.
- `make check` passed with 69 tests.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed with 69 tests.
- `forge fmt --check smart-contracts\AuctionContract.sol test\StreamAuctionPayments.t.sol`
  passed.
- `git diff --check` passed.
- Markdown heading scan passed for touched docs/state files.
- `slither . --config-file slither.config.json --foundry-compile-all --json <temp-file>`
  returned expected non-zero exit because unrelated baseline findings remain;
  JSON showed `REENTRANCY_ETH_TOTAL=0`,
  `TARGET_PARTICIPATE_TO_AUCTION=0`, and
  `AUCTION_ARBITRARY_SEND_ETH=0`.

Review feedback:

- Sidecar review confirmed the narrow issue #12 scope: bid/outbid credits only,
  not full custody or protocol-wide payment ledger work.
- PR opened on head `ca5ca09f3090b742798fd8bffc06d47090e73125`.
- Claude review was explicitly requested in issue comment `4668219408`.
- Claude skipped review because the organization's overage spend limit had been
  reached.
- CodeRabbit initially failed because the head moved during the state-file push;
  a latest-head review was requested in issue comment `4668232366`.
- CodeRabbit reviewed latest head `91a92f6461355ea108252c49dbd5f7db5ffc4a34`,
  confirmed the P0-AUCT-002 accounting and reentrancy fix, and found no material
  issues within scope.
- CodeRabbit's commit status remained pending despite the clean review comment
  and release-note update; autonomous merge evidence was recorded in issue
  comment `4668268937` before merge.

Outcome:

- Merged as PR #58 on `2026-06-10 08:45 UTC`.
- Squash merge commit `256cb2019c4c7c057147ee0e5f51d892b52e4f58`.
- Latest head before merge `91a92f6461355ea108252c49dbd5f7db5ffc4a34`.
- Issue #12 closed as completed.
- GitHub CI passed; CodeRabbit review evidence was clean despite stale pending
  commit status.
- Claude unavailable due to organization overage.

### PR #59: Formalize auction custody and settlement (Queue Item 18)

Status: Merged.
Branch: `codex/auction-custody-state-machine`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/59`.
Related issue: `https://github.com/6529-Collections/6529Stream/issues/22`.
Claude review request: issue comment `4668570581`.

Goal:

- Implement the accepted ADR 0002 auction custody and state-machine semantics
  without reopening the outbid refund issue fixed in PR #58.
- Make token custody and settlement authority explicit and testable for bid and
  no-bid auctions.
- Preserve bidder credit accounting and active bid escrow invariants.
- Add events/views/tests/docs so auction state is observable by contributors,
  indexers, and auditors.

Candidate files:

- `smart-contracts/AuctionContract.sol`
- `smart-contracts/StreamDrops.sol`
- `smart-contracts/IStreamAuctions.sol`
- `docs/auction-custody.md`
- `test/StreamAuctionCustody.t.sol`
- `test/StreamAuctionPayments.t.sol`
- `test/mocks/MockStreamAuctions.sol`
- existing auction/drop characterization tests as migration tripwires
- `docs/adr/0002-auction-custody.md`
- `docs/adr/0003-payment-accounting.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- `StreamDrops` now requires an admin-configured auction contract before
  auction drops mint, mints auction custody to that contract, and registers the
  auction with drop ID, token ID, collection, poster, reserve, and end time.
- `StreamAuctions` now implements `IERC721Receiver`, registers explicit auction
  records, exposes ADR 0002 status views, derives active/ended states, stores
  terminal states, and rejects bids outside `Active`.
- No-bid settlement transfers from auction escrow to an EOA signed poster. If
  the poster is a contract, settlement records a pending poster-controlled NFT
  claim and leaves the NFT in escrow until the poster claims to a receiver.
- With-bid settlement atomically records terminal state, moves active bid
  escrow into poster, protocol, and curator pull credits, and transfers the NFT
  from auction escrow to the highest bidder; a failed NFT transfer reverts the
  full settlement so credits are not released without custody transfer.
- Pre-bid cancellation is available to the signed poster or authorized auction
  admin, and cancellation after a valid bid is rejected.
- PR #58 bidder-credit accounting remains intact; final auction proceeds now
  have a separate auction-local pull-credit withdrawal path.
- Broader ADR 0003 payment accounting remains open for fixed-price payments,
  curator rewards, randomizer reserves, and cross-contract invariants.

Validation:

- `forge test --match-contract
  'StreamAuction(Custody|Payments)Test|StreamDropsCharacterizationTest' -vvv`
  passed: 35 tests, 0 failed, after CodeRabbit review fixes.
- `forge fmt --check` passed for the changed Solidity contracts and tests.
- `git diff --check` passed.
- Markdown heading and traceability scans passed for touched docs/state files.
- `make check` passed with 85 tests and the known compiler/NatSpec/lint
  warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 85
  tests and the known compiler/NatSpec/lint warnings.
- Repo-local Slither ran through `.venv-tools\Scripts\slither.exe` with Foundry
  on `PATH`; it returned the expected non-zero baseline-finding exit with 10
  High, 25 Medium, 53 Low, 511 Informational, and 6 Optimization findings. The
  current delta has no `reentrancy-no-eth` findings and no production auction
  emergency `arbitrary-send-eth` finding. The extra High finding is the
  intentional test-only `ForceEth.force` `selfdestruct` helper used to prove
  forced-ETH accounting.

Review feedback:

- Contract-risk, test-strategy, and docs/state sidecars completed. Their
  recommendations were folded into escrow-by-auction-contract custody, explicit
  status views, no-bid pending claim tests, final proceeds credits, and
  docs/roadmap scope wording.
- PR opened on head `dea2f05ea6d133483e9bb8765f95f02d04e32a8e`.
- Claude review was explicitly requested in issue comment `4668570581`.
- Claude review was skipped by `claude[bot]` because the organization overage
  spend limit has been reached.
- CodeRabbit review `4466455619` and inline thread `PRRT_kwDOM7REis6Ibep6`
  requested one docs casing fix and flagged additional review nits around
  no-bid failed-claim rollback, proceeds rounding, `Created` state docs,
  receiver-hook forward compatibility, auction-contract interface validation,
  `AuctionRecord.tokenId`, forced-ETH accounting, legacy minter end-time
  divergence, and zero-address proceeds recipients.
- Local review fixes add no-bid pending-claim rollback coverage, non-divisible
  proceeds rounding coverage, forced-ETH surplus coverage, zero-address
  proceeds-recipient constructor/setter guards, auction interface validation,
  `AuctionRecord.tokenId`, and matching docs/test-matrix wording.

Outcome:

- Merged as PR #59 on `2026-06-10`.
- Squash merge commit `48e7031f53a5d4fe3c5b32203c97b39a6ab4cc9f`.
- Latest head before merge `1e52d6dfaf8a61bc7066ee3fade144bf4a397488`.
- Issue #22 closed as completed.
- Issue #28 was closed as completed after PR #58 and PR #59 covered auction
  outbid refunds and preserved bidder-credit behavior.
- GitHub CI passed. CodeRabbit review evidence was clean despite stale pending
  commit status. Claude was unavailable due to organization overage.

### PR candidate: Fixed-price pull payments (Queue Item 19)

Status: Merged.
Branch: `codex/fixed-price-pull-payments`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/60`.
Related issue: `https://github.com/6529-Collections/6529Stream/issues/27`.
Claude review request: issue comment `4669058148`.

Goal:

- Convert fixed-price minting in `StreamDrops` from synchronous poster,
  payout, and curators-pool ETH pushes into ADR 0003 pull-payment accounting.
- Keep the scope to fixed-price `StreamDrops` payments so broader P0-PAY-001,
  curator reward credits, randomizer reserves, and cross-contract emergency
  invariants remain separate roadmap work.
- Preserve auction payment behavior from PR #58 and PR #59.

Candidate files:

- `smart-contracts/StreamDrops.sol`
- `test/StreamFixedPricePayments.t.sol`
- `test/StreamDropsIntegrationCharacterization.t.sol`
- `docs/adr/0003-payment-accounting.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- `StreamDrops` records fixed-price poster, protocol, and curator-reserve
  credits before minting and relies on transaction atomicity to roll back
  credits if minting fails.
- Poster and protocol credits are withdrawable through a `nonReentrant`
  fixed-price withdrawal path. Failed withdrawals revert the state update, so
  credits and totals are preserved.
- Curator reserve is accounted and protected in total owed/surplus views but is
  not ordinary withdrawable credit in this PR; later curator-claim work owns
  reserve movement into individual curator credits.
- Fixed-price minting no longer calls poster, payout, or curators-pool
  recipients during the mint path, so rejecting recipients cannot block minting.
- `StreamDrops.emergencyWithdrawable()` exposes forced/direct surplus without
  subtracting owed fixed-price poster, protocol, or curator-reserve balances.

Validation:

- `forge test --match-contract StreamFixedPricePaymentsTest -vvv` passed with
  12 tests and the known compiler/NatSpec/selfdestruct warnings.
- `forge test --match-contract
  "Stream(FixedPricePayments|DropsIntegrationCharacterization|DropsCharacterization)Test" -vvv`
  passed with 33 tests, 0 failed.
- `forge fmt --check` passed for changed Solidity contracts and tests.
- `git diff --check` passed.
- `make check` passed with 97 tests, 0 failed, and known compiler/NatSpec/lint
  warnings.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with 97
  tests, 0 failed, and known compiler/NatSpec/lint warnings.
- Repo-local Slither ran through `.venv-tools\Scripts\slither.exe` with Foundry
  on `PATH`; it returned the expected non-zero baseline-finding exit with 11
  High, 27 Medium, 54 Low, 519 Informational, and 6 Optimization findings. The
  current high-impact `arbitrary-send-eth` set is down to the three remaining
  non-`StreamDrops` emergency-withdrawal rows; new high findings are
  intentional test-only `selfdestruct` helpers for forced-ETH accounting.

Review feedback:

- Contract-risk, test-strategy, and docs/state sidecars completed. Their main
  recommendations were folded into the implementation: curator reserve is not
  ordinary withdrawable credit, failed mint rollback is tested, fixed-price
  rejection characterization tests are converted, and docs avoid claiming full
  payment-accounting completion.
- PR #60 opened from head `e7b4efea5e0ac7a234cf0ec98448a3509e1c0d9b`.
- Claude review was explicitly requested because Claude may not run
  automatically.
- GitHub CI passed on head `507a47cac7e5c1fc258972ad731e1760210b4366`.
  Claude skipped review due to organization overage. CodeRabbit was nudged in
  issue comment `4669093106`, acknowledged the full-review request in comment
  `4669095051`, and left one low-value nitpick to document intentional
  `selfdestruct` usage in the forced-ETH test helper.
- Review fix added the forced-ETH helper comment and
  `forge test --match-contract StreamFixedPricePaymentsTest -vvv`,
  `forge fmt --check test\StreamFixedPricePayments.t.sol`, and
  `git diff --check` passed locally.
- Review-fix commit `b2d0a7481bc8392b1504b3a8687a12f274d4226e` passed CI
  run `27269901786`. No inline review threads are open. CodeRabbit status
  remains pending, but PR comment `4669162764` documents the stale-status
  exception and clean review evidence.

Outcome:

- PR #60 was squash-merged as
  `f7390f28c48f833a75e28a87995f24df27e152c3`.
- Final head `5f2770b0d82c04ecb49fc19c20c12665766389b1` passed GitHub CI
  run `27270187899`.
- Issue #27 was closed as completed by the merge.

### PR #61: Curator reward claim credits (Queue Item 20)

Status: Merged.
Branch: `codex/curator-claim-credits`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/61`.
Related issue: `https://github.com/6529-Collections/6529Stream/issues/29`.
Claude review request: issue comment `4669369055`; requested explicitly because
Claude may not run automatically.

Goal:

- Convert `StreamCuratorsPool.claimRewards` from synchronous ETH push payout to
  ADR 0003 curator pull-credit accounting.
- Preserve Merkle proof validation, duplicate-claim rejection, and delegation
  semantics while making reverting reward addresses unable to block claim
  consumption or credit creation.
- Add curator-credit withdrawal behavior with failed-withdrawal preservation,
  reentrancy coverage, owed/surplus views, and docs/test traceability.
- Keep scope limited to curator reward claims. Broader protocol-wide #25/#26
  ledger unification, randomizer reserves, and full emergency-withdrawal
  boundaries remain separate work.

Candidate files:

- `smart-contracts/StreamCuratorsPool.sol`
- `test/StreamCuratorsPool.t.sol`
- `docs/adr/0003-payment-accounting.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Sidecar contract-risk, test-strategy, and docs/state reviews were requested
  before implementation.
- `StreamCuratorsPool.claimRewards` now hashes reward leaves with
  `abi.encode(rewardAddress, collectionID, amount)`, validates the Merkle proof,
  checks local surplus before consuming the claim, records
  `curatorCredits[rewardAddress]`, increments `totalCuratorOwed`, and emits the
  existing `Reward` event plus a curator-credit event.
- The claim path no longer calls the reward address, so reverting reward
  recipients cannot block claim consumption or credit creation.
- `withdrawCuratorCredit` and `withdrawCuratorCreditTo` are `nonReentrant`
  pull-payment exits. Failed withdrawals revert atomically and preserve the
  curator credit and aggregate owed total.
- `totalOwed()` and `emergencyWithdrawable()` expose the local curator-pool
  owed/surplus boundary. `emergencyWithdraw()` now withdraws only surplus over
  local curator credits owed.
- This is intentionally local to `StreamCuratorsPool`. Cross-contract reserve
  movement from `StreamDrops` fixed-price curator reserves and auction curator
  credits to the curator pool remains future shared-ledger work, so this PR
  should close #29 only.

Validation:

- `forge test --match-contract "Stream(CuratorsPool|AuctionPayments|FixedPricePayments)Test" -vvv`
  passed with 38 tests.
- `make check` passed with 109 tests and the known compiler/NatSpec/lint
  warning baseline.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed with 109 tests.
- `forge fmt --check smart-contracts\StreamCuratorsPool.sol test\StreamCuratorsPool.t.sol`
  passed.
- `git diff --check` passed.
- Repo-local Slither ran through `.venv-tools\Scripts\slither.exe` with Foundry
  on `PATH`; it still exits `-1` for baseline findings and intentional test
  helpers, but the `arbitrary-send-eth` detector now lists only
  `NextGenRandomizerRNG.emergencyWithdraw()` and
  `StreamMinter.emergencyWithdraw()`, not `StreamCuratorsPool`.

Review feedback:

- Claude review was requested explicitly but skipped because the organization
  was over its Claude Code review quota.
- CodeRabbit was explicitly nudged after CI passed. It acknowledged the refresh
  request and had no visible unresolved review threads.
- CodeRabbit's commit status remained pending after the clean follow-up, so the
  PR was merged under the autonomous stale-status exception with the evidence
  documented in the PR conversation.

Outcome:

- PR #61 was squash-merged as
  `51db3fd936b1ed7077fe5a7d033037581b9b4997`.
- Final head `8353d5623fde59ad5e02bbc2e993cb552cc23387` passed GitHub CI
  run `27271375494`.
- Issue #29 was closed as completed by the merge.

### PR candidate: Bound remaining emergency withdrawals (Queue Item 21)

Status: Merged.
Branch: `codex/bound-emergency-withdrawals`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/62`.
Related issues:

- `https://github.com/6529-Collections/6529Stream/issues/31`
- `https://github.com/6529-Collections/6529Stream/issues/8`
Claude review request: issue comment `4669695551`; requested explicitly because
Claude may not run automatically.

Goal:

- Remove the remaining `arbitrary-send-eth` emergency-withdrawal findings from
  `StreamMinter` and `NextGenRandomizerRNG`.
- Treat `StreamMinter` balances as forced-ETH surplus by construction and
  expose explicit owed/surplus views.
- Treat `NextGenRandomizerRNG` balances as randomness reserve until the fuller
  randomizer payment model is implemented, so emergency withdrawal cannot drain
  funds needed for provider requests.
- Add direct regression tests and update roadmap, Slither baseline, status, and
  payment-accounting docs without claiming full protocol-wide ledger completion.

Candidate files:

- `smart-contracts/StreamMinter.sol`
- `smart-contracts/RandomizerRNG.sol`
- `smart-contracts/AuctionContract.sol`
- `test/StreamEmergencyWithdraw.t.sol`
- `docs/adr/0002-auction-custody.md`
- `docs/adr/0003-payment-accounting.md`
- `docs/auction-custody.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Sidecar contract-risk, test-strategy, and docs/state reviews were requested
  while implementation proceeded.
- `StreamMinter` now exposes `totalOwed() == 0` and a saturated
  `emergencyWithdrawable()` view. Its emergency withdrawal transfers only
  positive surplus to the admin owner. Because the minter has no payable
  business path or `receive`, the tests prove ordinary ETH transfers fail and
  forced ETH is the relevant surplus case.
- `NextGenRandomizerRNG` now exposes `totalRandomnessReserved()` and
  `totalOwed()` as the full adapter balance, and `emergencyWithdrawable()` as
  zero. Its emergency withdrawal emits the legacy `Withdraw` event but transfers
  no ETH, preserving provider reserve funds until fuller request-level reserve
  lifecycle accounting lands.
- `StreamAuctions.emergencyWithdraw()` was adjusted to use the positive-surplus
  branch pattern instead of a strict `balance == 0` equality, removing a medium
  Slither warning without changing the surplus-only transfer boundary.
- `test/StreamEmergencyWithdraw.t.sol` covers seven target-state paths:
  ordinary ETH rejection for `StreamMinter`, forced-surplus withdrawal for
  `StreamMinter`, unauthorized minter withdrawal rejection, direct reserve
  preservation for `NextGenRandomizerRNG`, unauthorized randomizer withdrawal
  rejection, forced-ETH reserve preservation for `NextGenRandomizerRNG`, and
  request-spend accounting that keeps remaining adapter reserve non-withdrawable.
- Docs and the Slither baseline now mark the four historical
  `arbitrary-send-eth` emergency-withdrawal rows fixed for current surfaces,
  while keeping broader shared-ledger invariants and full randomizer reserve
  lifecycle accounting open.

Validation:

- `forge test --match-contract "Stream(EmergencyWithdraw|AuctionPayments)Test" -vvv`
  passed with 21 tests.
- `make check` passed with 116 tests.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed with 116 tests.
- `forge fmt --check test\StreamEmergencyWithdraw.t.sol` passed.
- `git diff --check` passed.
- Repo-local Slither ran through `.venv-tools\Scripts\slither.exe` with Foundry
  on `PATH`. It still exits `-1` for the accepted/open baseline, but
  `arbitrary-send-eth` now reports zero current findings. The regenerated
  branch-local counts are 632 total findings: 9 High, 29 Medium, 58 Low, 530
  Informational, and 6 Optimization.
- The zero `arbitrary-send-eth` metric was extracted from the regenerated
  `$env:TEMP\6529stream-slither-emergency.json` output with:
  `@($json.results.detectors | Where-Object { $_.check -eq "arbitrary-send-eth" }).Count`,
  after `$json = Get-Content $out -Raw | ConvertFrom-Json`; result:
  `ARBITRARY_SEND_ETH_COUNT=0`.

Outcome:

- PR #62 was squash-merged as
  `44a3ebb5b298b437387c056a0c86b1d7ee9db03d`.
- Final head `77743912aac975fe13ac2d622237a9d5b7ecd0ba` passed GitHub CI
  run `27274061799`.
- CodeRabbit verified the follow-up review fixes and marked the PR good to
  merge in issue comment `4669840843`.
- Claude was explicitly requested but remained unavailable due to the
  organization overage skip already recorded in review `4467324335`.
- Issue #31 was closed as completed by the merge; issue #8 remains broader
  Slither/invariant work.

### PR candidate: Fix admin selector and permission model (Queue Item 22)

Status: Merged in PR #63.
Branch: `codex/fix-admin-permission-model`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/63`.
Related issues:

- `https://github.com/6529-Collections/6529Stream/issues/34`
- `https://github.com/6529-Collections/6529Stream/issues/33`

Goal:

- Replace selector-only or mismatched admin authorization with target-scoped,
  explicit permission semantics consistent with ADR 0004.
- Add direct regression tests proving that a grant for one function cannot
  authorize a different selector, and a grant for one contract cannot authorize
  another contract that happens to share a selector.
- Preserve intentional owner/global admin flows while documenting any grouped
  permissions explicitly.
- Update status, roadmap test traceability, and autonomous run state without
  bundling pause-control work from P0-ADMIN-002.

Candidate files:

- `smart-contracts/StreamAdmins.sol`
- `smart-contracts/StreamCore.sol`
- Admin-related callers using `FunctionAdminRequired`
- `smart-contracts/StreamMinter.sol`
- `test/StreamAdminSelectors.t.sol`
- `test/StreamMinterValidation.t.sol`
- Existing admin characterization tests
- `docs/adr/0004-admin-governance.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Initial validation targets:

- Characterize the current selector/target behavior before rewriting.
- Add P0 target-state tests for wrong selector, wrong target, explicit global
  admin, owner, and removal/revocation paths.
- Run focused admin tests, full `make check`, Windows `scripts/check.ps1`,
  formatting/whitespace checks, and Slither delta evidence if Solidity changes
  affect detector output.

Implementation notes:

- `StreamAdmins` now stores function-admin grants by
  `(account, target, selector)`, rejects zero admin/target/selector inputs, and
  emits `GlobalAdminUpdated` / `FunctionAdminUpdated` events for role changes.
- `StreamAdmins` keeps the current `tdhSigner` registration behavior for
  compatibility but adds owner/root recovery for role management and rejects a
  zero constructor signer.
- `retrieveCollectionAdmin(address,uint256)` is implemented as an explicit
  always-false deferred surface for P0-ADMIN-001, leaving collection-scoped
  delegation for a later ADR-backed implementation.
- All `FunctionAdminRequired` call sites now ask for authorization against
  `address(this)`, so selector grants do not leak across target contracts.
- `StreamCore.setCollectionData`, `StreamCore.updateCollectionInfo`, and
  `StreamCuratorsPool.setMultipleMerkleRoots` now check their own selectors
  instead of unrelated selectors.
- Added `test/StreamAdminSelectors.t.sol` and expanded
  `test/StreamAdmins.t.sol` to cover wrong selector, wrong target, revocation,
  global-admin bypass, owner/root role-management recovery, batch grants,
  zero-address rejection, zero-selector rejection, constructor signer
  validation, and the deferred collection-admin behavior.
- Added explicit `StreamMinter.mint` batch validation for array length, empty
  batch, and zero-quantity inputs after CodeRabbit identified panic-prone array
  indexing in the touched minter surface.
- Updated ADR 0004, roadmap traceability, status docs, blocker docs, and test
  README language to distinguish the implemented selector/target model from
  remaining signer-lifecycle and pause-control follow-ups.

Validation:

- Focused admin/minter suite passed:
  `forge test --match-contract "Stream(MinterValidation|Admins|AdminSelectors|CoreAdminCharacterization)Test" -vvv`
  with 22 passing tests after CodeRabbit review fixes.
- Full local gate passed: `make check` with 133 passing tests.
- Windows wrapper passed:
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1` with
  133 passing tests.
- Formatting and whitespace checks passed for touched Solidity/test files and
  `git diff --check`.
- Markdown heading scan passed for touched roadmap/ADR files.
- Slither ran through `.venv-tools\Scripts\slither.exe` with Foundry `1.7.1`
  and Slither `0.11.5`; it still exits non-zero for known baseline findings,
  but the final JSON has 648 total findings: 9 High, 29 Medium, 61 Low, 543
  Informational, and 6 Optimization. It reports zero `arbitrary-send-eth`
  findings, zero high/medium findings involving `StreamAdmins`, and zero
  `StreamAdmins` `missing-zero-check` findings.
- CodeRabbit comment `4670084627` requested documentation/test coverage for the
  independently revocable `tdhSigner` global-admin bypass, explicit low-impact
  Slither delta triage, and removal of a no-op `vm.prank(address(this))`; all
  three were addressed before the final validation rerun.
- CodeRabbit's second review pass requested a fresh run-state timestamp and
  explicit `StreamMinter.mint` batch validation. The follow-up adds exact revert
  tests for array length mismatch, empty batches, and zero quantity. The Slither
  rerun remains at 648 total findings and reports zero `unused-return` findings
  in `test/StreamMinterValidation.t.sol`.
- PR #63 was squash-merged as
  `12f5f461a3ff784287f650b69efbdc0bbe6e0429`.
- Final head `acac51aa7d1745ed7f677bd9f6a620ec68c4224a` passed GitHub CI
  run `27276683973`.
- CodeRabbit inline threads were resolved before merge. Its aggregate status
  stayed stale/pending after final CI and resolved threads, so the autonomous
  maintainer decision was documented in the PR before merging.
- Claude was explicitly requested on the latest head but remained unavailable
  due to the organization overage skip recorded in review
  `pullrequestreview-4467627435`.
- Issue #34 should be closed as completed by the merge; issue #33 remains the
  broader admin/governance tracking issue.

### PR candidate: Define pause and emergency controls (Queue Item 23)

Status: Merged in PR #64.
Branch: `codex/pause-emergency-controls`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/64`.
Related issues:

- `https://github.com/6529-Collections/6529Stream/issues/35`
- `https://github.com/6529-Collections/6529Stream/issues/33`

Goal:

- Implement the ADR 0004 pause model without changing unrelated protocol
  behavior.
- Add domain-specific pause state for accepted P0 domains:
  `DropExecution`, `Mint`, `AuctionBid`, `AuctionSettlement`,
  `MetadataMutation`, and `RandomnessRequest`.
- Keep user withdrawals available by default according to the ADR 0004
  withdrawal-pause policy.
- Emit stable pause events with domain, paused state, admin, and reason.
- Preserve surplus-only emergency-withdrawal bounds already implemented by
  payment PRs, while documenting emergency-control traceability.
- Add direct tests proving each pause domain blocks only its intended flow and
  unpause restores the flow.

Candidate files:

- `smart-contracts/StreamAdmins.sol`
- `smart-contracts/IStreamAdmins.sol`
- `smart-contracts/StreamDrops.sol`
- `smart-contracts/AuctionContract.sol`
- `smart-contracts/StreamMinter.sol`
- Randomizer request surface if locally reachable
- Metadata mutation surfaces if locally reachable
- `test/StreamPauseControls.t.sol`
- Existing admin/payment/randomness characterization tests as needed
- `docs/adr/0004-admin-governance.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Initial validation targets:

- Focused pause-control test suite.
- Existing admin tests to catch authorization regressions.
- Focused payment/emergency-withdrawal tests to prove withdrawals and surplus
  bounds are not accidentally paused or relaxed.
- Full `make check`, Windows `scripts/check.ps1`, formatting/whitespace checks,
  Markdown heading scan, and Slither delta evidence.

Implementation notes:

- Added `StreamPauseDomains` constants for `DropExecution`, `Mint`,
  `AuctionBid`, `AuctionSettlement`, `MetadataMutation`,
  `RandomnessRequest`, and emergency events.
- `StreamAdmins` now stores readable domain pause state, separates
  pause-guardian and unpause-admin authority, emits `PauseUpdated`, and exposes
  an explicit `emergencyRecipient()` with root-managed updates.
- `StreamDrops.mintDrop`, `StreamMinter.mint`, `StreamMinter.mintAndAuction`,
  `StreamAuctions.participateToAuction`, `StreamAuctions.claimAuction`,
  `StreamAuctions.claimNoBidAuctionToken`, mutable `StreamCore` metadata paths,
  and new randomizer request paths now check only their intended pause domain.
- User credit withdrawals are intentionally not pause-gated. The new tests
  pause every operational domain and still withdraw fixed-price poster credits.
- `StreamAuctions`, `StreamMinter`, and `StreamCuratorsPool` emergency
  withdrawals keep their existing surplus bounds but now route positive surplus
  to `StreamAdmins.emergencyRecipient()` and emit an `EmergencyWithdrawal`
  event in addition to the legacy `Withdraw` event.
- Updated ADR 0004, status/blocker docs, test README, roadmap current status,
  P0-ADMIN-002 notes, and test matrix traceability.

Validation so far:

- Focused pause/emergency suite passed:
  `forge test --match-contract "Stream(PauseControls|EmergencyWithdraw)Test" -vvv`
  with 16 passing tests after the signer-compromise pause/invalidation case was
  added.
- Expanded admin/drop/auction/payment/curator suite passed:
  `forge test --match-contract "Stream(Admins|AdminSelectors|PauseControls|EmergencyWithdraw|DropsCharacterization|DropsIntegrationCharacterization|DropsEIP712|DropsERC1271|MinterValidation|AuctionCustody|AuctionPayments|FixedPricePayments|CuratorsPool)Test" -vvv`
  with 140 passing tests.
- Targeted emergency/payment suite passed:
  `forge test --match-contract "Stream(EmergencyWithdraw|AuctionPayments|CuratorsPool)Test" -vvv`
  with 33 passing tests after the explicit emergency-recipient event routing
  cleanup.
- Canonical local gate passed: `make check` with 142 passing tests.
- Windows wrapper passed:
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1` with
  142 passing tests.
- Formatting, whitespace, and Markdown structure checks passed:
  `forge fmt --check ...`, `git diff --check`, and
  `rg -n "^#|^##|^###" ...`.
- Slither remains non-gating and exits non-zero because baseline findings
  remain, but the final JSON reports 676 total findings: 9 High, 29 Medium, 61
  Low, 571 Informational, and 6 Optimization. High/medium totals are unchanged,
  `arbitrary-send-eth` remains zero, and the only emergency-matching medium row
  is the accepted test-only `MockArrngController` `locked-ether` row.
- PR #64 was opened on head `ce55a2dc7585fd9d699241d692d23bb2f9f10e1c`.
- Claude review was explicitly requested in issue comment `4670568701`.
- CodeRabbit latest-head review was explicitly requested in issue comment
  `4670570080`.
- State-only follow-up commit moved the final head to
  `055ffb63962de8b33f250e8d86ea2d933bc0bfb9`; Claude and CodeRabbit were
  re-pinged in issue comments `4670582018` and `4670583894`.
- GitHub CI run `27278804614` passed on final head
  `055ffb63962de8b33f250e8d86ea2d933bc0bfb9`.
- Claude remained unavailable due to the organization overage skip recorded in
  review `pullrequestreview-4468100654`.
- CodeRabbit updated the PR with release notes but its aggregate status remained
  pending despite no visible actionable comments or review threads after
  repeated polls. The stale-status maintainer decision was documented in issue
  comment `4670664451`.
- Merged via squash as `4e73435d59dba9bcca05a10ad18a529c53489c75`.
- Issue #35 closed as completed by the merge.

### PR candidate: Harden randomizer requests and callbacks (Queue Item 24)

Status: Merged.
Branch: `codex/randomizer-callback-hardening`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/65`.
Related issues:

- `https://github.com/6529-Collections/6529Stream/issues/37`
- `https://github.com/6529-Collections/6529Stream/issues/14`

Goal:

- Implement the ADR 0005 request lifecycle and callback-hardening model for the
  current async randomizer adapters.
- Bind requests to request ID, token, collection, provider adapter, and
  collection randomizer epoch.
- Reject unknown, duplicate, stale, wrong-provider, wrong-epoch, and malformed
  callback outputs before final token hashes are written.
- Validate the core token-to-collection binding before fulfillment so an
  adapter cannot finalize a request against the wrong collection.
- Keep randomness fulfillment unpaused while pause controls only block new
  requests.
- Make the weak `RandomizerNXT` helper path impossible to configure as a
  production collection randomizer or explicitly document any narrower scope.
- Update docs, roadmap/test matrix, and Slither traceability after
  implementation.

Initial candidate files:

- `smart-contracts/StreamCore.sol`
- `smart-contracts/IStreamCore.sol`
- `smart-contracts/RandomizerRNG.sol`
- `smart-contracts/RandomizerVRF.sol`
- `smart-contracts/RandomizerNXT.sol`
- `smart-contracts/StreamRandomizerLifecycle.sol`
- `test/StreamRandomizerLifecycle.t.sol`
- `test/mocks/MockRandomizerCore.sol`
- `test/StreamEmergencyWithdraw.t.sol`
- `test/StreamPauseControls.t.sol`
- `docs/adr/0005-randomness.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Initial validation targets:

- Focused randomizer lifecycle test suite.
- Existing pause/emergency/randomizer characterization tests.
- Full `make check`, Windows `scripts/check.ps1`, formatting/whitespace checks,
  Markdown heading scan, and Slither delta evidence.

Local implementation notes:

- `StreamCore` now exposes `viewCollectionRandomizerContract` and
  `viewRandomizerEpoch`, increments the collection randomizer epoch on
  `addRandomizer`, and emits `CollectionRandomizerUpdated`.
- `StreamRandomizerLifecycle` records request state and rejects unknown,
  duplicate, empty-output, stale, wrong-provider/epoch, and wrong-collection
  fulfillment paths before the token hash is written.
- VRF and arRNG adapters use the shared lifecycle helper. New randomness
  requests remain pausable, but valid fulfillments are not blocked by the
  randomness-request pause.
- `RandomizerNXT.isRandomizerContract()` returns false so the weak synchronous
  helper cannot be configured as a production randomizer.
- Focused `StreamRandomizerLifecycleTest` currently passes with 10 tests.
- Final local validation passed: focused lifecycle suite, nearby
  pause/emergency/randomizer characterization suite, full `make check`, Windows
  `scripts/check.ps1`, touched-file `forge fmt --check`, `git diff --check`,
  Markdown heading scan, traceability grep, and Slither delta evidence.
- Final Slither JSON reports 686 total findings with unchanged 9 High / 29
  Medium counts, two existing `weak-prng` rows, no
  `NextGenRandomizerRNG.requestRandomWords` `reentrancy-eth` row, and no new
  lifecycle-mock `locked-ether` or `arbitrary-send-eth` rows.
- Pull request opened as #65 at head
  `6413d45366a6572b87c81155f764428a191eb554`.
- Claude review was explicitly requested in issue comment `4671046189`.
- CodeRabbit latest-head review was explicitly requested in issue comment
  `4671047964`.
- CI passed on head `02950ba1e5c5f5f109a669697cc93968749a0189` in run
  `27281733224`.
- CodeRabbit initially failed when the head moved, then was explicitly nudged in
  issue comments `4671059687` and `4671081645`. It acknowledged the latest-head
  review in comment `4671123708`.
- CodeRabbit comment `4671138033` reported no blocking issues and suggested
  low-priority clarity comments plus explicit coverage for arRNG provider
  request ID `0`. The follow-up patch adds the comments and zero-request-ID
  regression coverage before pushing a new head.
- Follow-up commit `d6b3788bbe820a1dcb4cd8b091110eb067d9ba24` passed CI run
  `27282886446`; CodeRabbit comment `4671241284` verified the follow-up and
  marked it LGTM.
- Merged via squash as `9bf44c1e292e891f01fa4a7bc27373032e9beaaf`.
- Issue #37 closed as completed by the merge. Issue #39 was closed as completed
  after evidence comment `4671273910`.

### PR candidate: Complete randomizer lifecycle views (Queue Item 25)

Status: Merged.
Branch: `codex/randomizer-lifecycle-views`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/66`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/38`

Goal:

- Make lifecycle lookup by token ID first-class for contributors, indexers, and
  runbooks.
- Preserve the current request-ID views while adding token-level request and
  state views.
- Prove unknown, pending, fulfilled, and stale token-level lookup behavior.
- Update roadmap, status docs, tests, and run state.

Candidate files:

- `smart-contracts/StreamRandomizerLifecycle.sol`
- `test/StreamRandomizerLifecycle.t.sol`
- `test/README.md`
- `docs/known-blockers.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation completed at `2026-06-10 14:34 UTC`:

- `forge test --match-contract StreamRandomizerLifecycleTest -vvv`
  passed: 11 tests, 0 failed.
- `make check` passed: 153 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts/check.ps1` passed:
  153 tests, 0 failed.
- `forge fmt --check smart-contracts/StreamRandomizerLifecycle.sol test/StreamRandomizerLifecycle.t.sol`
  passed.
- `git diff --check` passed.
- Heading and traceability greps passed for roadmap, run state, test README,
  blocker docs, lifecycle contract, and lifecycle tests.
- Slither baseline read passed for comparison purposes:
  `total=686`, `high=9`, `medium=29`, `weak-prng=2`; the token-level
  view helpers did not expand the accepted baseline after parameter naming was
  cleaned up. Slither still exits nonzero because known baseline findings are
  present.

Review requests:

- Claude requested in issue comment `4671390449`; expected to skip while the org
  overage limit remains in effect.
- CodeRabbit latest-head review requested in issue comment `4671390698`.
- Claude manual review was triggered in issue comment `4671415027` and skipped
  in review `4468903992` because the organization reached its monthly code
  review spending cap.
- CodeRabbit reported LGTM in issue comment `4671424817` and suggested
  low-priority token-level `Stale` coverage. The follow-up patch adds that
  coverage directly to `testMarkedStaleRequestIsObservableAndCannotFulfill`.
- CodeRabbit reviewed the latest follow-up in issue comment `4671513141`,
  reported "LGTM. No further concerns.", and the PR was squash-merged as
  `1b5c14c802f2c10870f8ee7c089164372d393b54`.
- Issue #38 closed as completed.

Follow-up validation completed at `2026-06-10 14:47 UTC`:

- `forge test --match-contract StreamRandomizerLifecycleTest -vvv`
  passed: 11 tests, 0 failed.
- `make check` passed: 153 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts/check.ps1` passed:
  153 tests, 0 failed.
- `forge fmt --check test/StreamRandomizerLifecycle.t.sol` passed.
- `git diff --check` passed.
- Traceability grep passed for token-level stale coverage.

Validation targets retained for PR review:

- Focused `StreamRandomizerLifecycleTest`.
- Full `make check` and Windows `scripts/check.ps1`.
- Touched-file `forge fmt --check`, `git diff --check`, heading/traceability
  greps, and Slither delta if code changes affect the analyzed surface.

### PR #67: Block randomizer migration while requests are pending (Queue Item 26)

Status: Merged.
Branch: `codex/randomizer-pending-migration`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/67`.
Merge commit: `428cbc8213c344b219e746b47f089b1b75730bfb`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/41`

Review requests:

- Claude requested in issue comment `4671747961`.
- CodeRabbit requested in issue comment `4671749578`.
- CodeRabbit latest-head nudge posted in issue comment `4671785250`.
- Claude skipped review due to the organization monthly spending cap.
- CodeRabbit status resolved to success with `Review skipped`; no inline review
  comments were present.

Goal:

- Implement ADR 0005's default provider-migration policy: ordinary migration is
  blocked while the current lifecycle-aware provider reports pending requests.
- Expose lifecycle-aware per-collection and total pending request counts from
  randomizer adapters.
- Allow migration after valid fulfillment or explicit admin stale marking.
- Prove old-provider callbacks cannot overwrite after stale/fulfilled terminal
  states, and prove a new provider can request and fulfill after migration.

Candidate files:

- `smart-contracts/IRandomizerLifecycle.sol`
- `smart-contracts/StreamCore.sol`
- `smart-contracts/StreamRandomizerLifecycle.sol`
- `test/StreamRandomizerLifecycle.t.sol`
- `test/helpers/CharacterizationTestBase.sol`
- `docs/adr/0005-randomness.md`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation completed so far:

- Ran `scripts/bootstrap-windows.ps1` because the app shell did not have
  `forge` on PATH; the script installed Foundry `v1.7.1` and confirmed
  `forge Version: 1.7.1`.
- `forge test --match-contract StreamRandomizerLifecycleTest -vvv` with
  `.foundry/bin` prefixed in `PATH` passed: 16 tests, 0 failed.
- `make check` passed: build plus 158 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed:
  158 tests, 0 failed.
- `forge fmt --check` passed for touched Solidity/test files.
- `git diff --check` passed.
- Roadmap/docs traceability grep passed for `P0-RAND-005`,
  `PendingRandomnessRequests`, `pendingRandomnessRequests`, branch name, and
  Queue Item 26.
- Markdown heading scan passed for changed docs and run-state files.
- Repo-local Slither ran through `.venv-tools\Scripts\slither.exe` with
  Foundry `1.7.1`; it returned the accepted non-zero baseline:
  `slither_exit=-1 total=686 high=9 medium=29 weak-prng=2
  arbitrary-send-eth=0 reentrancy-eth=0`.

### PR #68: Add failed randomness post-processing state (Queue Item 27)

Status: Merged.
Branch: `codex/randomizer-failed-state`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/68`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/40`

Review requests:

- Claude requested in issue comment `4671968774`.
- CodeRabbit requested in issue comment `4671968843`.
- Latest-head Claude requested in issue comment `4671977932`; Claude skipped
  review due to the organization monthly spending cap.
- Latest-head CodeRabbit requested in issue comment `4671978003`; CodeRabbit
  found that `RandomnessPostProcessingFailed` should include provider and epoch.

Goal:

- Complete the missing `FailedPostProcessing` lifecycle path from ADR 0005
  without implementing the later manual retry entry point.
- Catch deterministic core post-processing failures after provider output is
  accepted, mark the request as failed, store the derived seed and failure-data
  hash, and clear lifecycle-aware pending counts.
- Prove duplicate provider callbacks cannot overwrite a failed request.
- Cover both VRF and arRNG adapters, and keep retry/re-request behavior queued
  under `P0-RAND-006`.

Candidate files:

- `smart-contracts/StreamRandomizerLifecycle.sol`
- `smart-contracts/RandomizerVRF.sol`
- `smart-contracts/RandomizerRNG.sol`
- `test/StreamRandomizerLifecycle.t.sol`
- `test/mocks/MockRandomizerCore.sol`
- `docs/adr/0005-randomness.md`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation completed before PR:

- Focused `forge test --match-contract StreamRandomizerLifecycleTest -vvv`
  passed: 18 tests, 0 failed.
- Full `make check` passed: 160 tests, 0 failed.
- Windows `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed: 160 tests, 0 failed.
- Touched-file `forge fmt --check` passed for randomizer contracts and tests.
- `git diff --check` passed.
- Roadmap/docs traceability grep passed for `P0-RAND-004`,
  `FailedPostProcessing`, `failureDataHash`,
  `RandomnessPostProcessingFailed`, and the active branch/work item.
- Markdown heading scan passed for changed docs and run-state files.
- Repo-local Slither ran through `.venv-tools\Scripts\slither.exe` with
  Foundry `1.7.1`; it returned the accepted non-zero baseline:
  `slither_exit=-1 total=685 high=9 medium=29 weak-prng=2
  arbitrary-send-eth=0 reentrancy-eth=0 reentrancy-no-eth=0
  reentrancy-events=22`.
- Slither suppressions are scoped to the VRF/arRNG external core
  post-processing blocks. The request is made non-pending before the external
  core write, duplicate callbacks and stale marking fail during reentry, and
  the post-call writes only emit/record the deterministic fulfillment or
  post-processing failure outcome.

Review follow-up:

- CodeRabbit review comment `3389722778` requested provider and epoch context in
  `RandomnessPostProcessingFailed` so indexers can correlate failures without
  extra storage lookups.
- CodeRabbit review body also suggested aligning `MockRandomizerCore.setTokenHash`
  with `StreamCore` by requiring the registered randomizer caller and rejecting
  token-hash overwrites. This is valid test-harness hardening and has been
  applied.
- User instruction after Claude was requested: no need to use Claude for this
  PR; CodeRabbit is sufficient.
- Review-fix validation passed:
  `forge test --match-contract StreamRandomizerLifecycleTest -vvv` (18 tests),
  `make check` (160 tests), Windows
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` (160 tests),
  touched-file `forge fmt --check`, `git diff --check`, traceability grep,
  heading scan, and Slither
  `slither_exit=-1 total=685 high=9 medium=29 weak-prng=2
  arbitrary-send-eth=0 reentrancy-eth=0 reentrancy-no-eth=0
  reentrancy-events=22`.
- Final mock-guard validation passed after the CodeRabbit nitpick:
  `forge test --match-contract StreamRandomizerLifecycleTest -vvv` (18 tests),
  `make check` (160 tests), Windows
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` (160 tests),
  touched-file `forge fmt --check test\mocks\MockRandomizerCore.sol`, and
  `git diff --check`.
- Follow-up CodeRabbit review on head
  `06ed909f994b06578fe7bef520373834c8ce79ec` reported no actionable comments,
  Foundry smoke passed, and GitHub combined status was success before merge.

Outcome:

- Merged as PR #68 on `2026-06-10 16:20 UTC`.
- Merge commit: `0c463840cbc4f2e000a9df8b7ca6a7b7e3c717e1`.
- Issue #40 closed completed.

### Completed: Add bounded randomness post-processing retry (Queue Item 28)

Status: merged.
Branch: `codex/randomizer-post-processing-retry`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/69`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/42`

Goal:

- Complete `P0-RAND-006` by adding bounded manual retry for deterministic
  `FailedPostProcessing` requests without requesting new provider output.
- Reuse the stored derived seed; do not accept new random words, token IDs, or
  collection IDs during retry.
- Gate retry through the existing function-admin/global-admin pattern.
- Emit retry success/failure events and cap failed retry attempts.
- Cover both VRF and arRNG adapters.

Candidate files:

- `smart-contracts/StreamRandomizerLifecycle.sol`
- `smart-contracts/RandomizerVRF.sol`
- `smart-contracts/RandomizerRNG.sol`
- `test/StreamRandomizerRetry.t.sol`
- `test/helpers/CharacterizationTestBase.sol`
- `docs/adr/0005-randomness.md`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Local implementation notes:

- `StreamRandomizerLifecycle` now tracks `postProcessingRetryCount`, exposes
  `MAX_RANDOMNESS_POST_PROCESSING_RETRIES`, and adds custom errors for
  non-failed-state retry and retry-limit exhaustion.
- VRF and arRNG adapters expose `retryRandomnessPostProcessing(uint256)`.
- Retry validates the request is `FailedPostProcessing`, verifies token,
  collection, provider, and epoch still match, then temporarily returns the
  request to `Fulfilled` while it retries the deterministic core token-hash
  write with the stored seed.
- Success clears the failure hash, refreshes fulfillment block/timestamp, emits
  `RandomnessPostProcessingRetried`, and emits the canonical
  `RandomnessFulfilled` event. Failure records the new failure-data hash, keeps
  the request failed, emits only `RandomnessPostProcessingRetryFailed`, and does
  not duplicate the initial `RandomnessPostProcessingFailed` event.

Validation so far:

- `forge build` passed.
- Focused `forge test --match-contract StreamRandomizerRetryTest -vvv` passed:
  10 tests, 0 failed.
- Focused `forge test --match-contract StreamRandomizerLifecycleTest -vvv`
  passed: 18 tests, 0 failed.
- Full `make check` passed: 170 tests, 0 failed.
- Full Windows wrapper
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed: 170
  tests, 0 failed.
- `forge fmt --check smart-contracts\StreamRandomizerLifecycle.sol
  smart-contracts\RandomizerVRF.sol smart-contracts\RandomizerRNG.sol
  test\StreamRandomizerRetry.t.sol test\helpers\CharacterizationTestBase.sol`
  passed.
- `git diff --check` passed.
- Traceability grep for `P0-RAND-006`, retry events, retry limit,
  provider/epoch safeguards, and `retryRandomnessPostProcessing` passed across
  contracts, tests, docs, and ops state.
- Markdown heading scan passed for `ops/ROADMAP.md`, ADR 0005, known
  blockers, project status, and test README.
- CodeRabbit top-level roadmap blocker wording review was addressed by removing
  the stale deterministic randomness retry phrase from the remaining-blockers
  summary.
- Slither baseline comparison passed with no new high/medium or production
  reentrancy findings: `slither_exit=-1`, `total=687`, `high=9`,
  `medium=29`, `weak-prng=2`, `arbitrary-send-eth=0`, `reentrancy-eth=0`,
  `reentrancy-no-eth=0`, `reentrancy-events=22`. The total is +2 versus the
  prior count from informational `pragma` and `solc-version` entries caused by
  adding `test/StreamRandomizerRetry.t.sol`.

Outcome:

- Merged as PR #69 on `2026-06-10 17:15 UTC`.
- Merge commit: `c5623f69ef5a37be650014ced36bfeb2141bf363`.
- Issue #42 closed completed.
- Claude was not requested for this PR per user instruction; CodeRabbit was
  sufficient and reported success on the final head.

### PR #70: Store raw random output hashes (Queue Item 29)

Status: Merged.
Branch: `codex/randomizer-raw-output-hash`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/70`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/43`

Goal:

- Complete `P0-RAND-007` by deciding and implementing the final
  raw-randomness versus derived-seed storage policy from ADR 0005.
- Store a canonical hash of the provider output alongside the derived seed so
  state and events are deterministic and indexer-friendly without retaining
  full provider word arrays.
- Preserve the existing no-redraw safety model: fulfillment and retry must keep
  using the accepted derived seed and must not accept user-significant input
  after request.
- Cover both VRF and arRNG adapter fulfillments, token-level views, and failed
  post-processing/retry paths where stored randomness remains observable.

Candidate files:

- `smart-contracts/StreamRandomizerLifecycle.sol`
- `smart-contracts/IRandomizerLifecycle.sol`
- `smart-contracts/RandomizerVRF.sol`
- `smart-contracts/RandomizerRNG.sol`
- `test/StreamRandomizerLifecycle.t.sol`
- `test/StreamRandomizerRetry.t.sol`
- `test/StreamRandomizerSeed.t.sol` if a dedicated focused suite is cleaner
- `docs/adr/0005-randomness.md`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Initial implementation notes:

- Current `RandomnessRequest` records `derivedSeed` but not the raw provider
  output hash on `main`; this branch adds `rawOutputHash`.
- Implemented policy stores `rawOutputHash =
  keccak256(abi.encode(randomWords))` and derives the token seed from
  `RANDOMNESS_SEED_TYPEHASH`, provider, request ID, collection, token,
  randomizer epoch, and `rawOutputHash`.
- Full provider word arrays remain outside contract storage; VRF and arRNG now
  both emit provider-specific `RequestFulfilled` words for off-chain
  auditability.
- Fulfillment, failed post-processing, retry success, and retry failure events
  now include both the derived seed and raw-output hash. Fulfillment events also
  include provider and randomizer epoch context for indexers.
- `RandomnessRequest` views by request ID and token ID expose both seed and
  raw-output hash, and `IRandomizerLifecycle` now exposes those lifecycle views
  for typed monitoring and audit tooling.
- Added coverage that post-request mutable `tokenData` changes do not affect the
  stored seed or raw-output hash because seed derivation is independent from
  mutable metadata.
- Added explicit stale-request coverage that `rawOutputHash` remains zero before
  fulfillment, plus provider raw-word event assertions and monotonic log-scan
  helper matching.
- Documented that deterministic retry success emits retry plus fulfillment
  confirmation for the same request ID.
- Issue #43 requires stored randomness data to match ADR 0005, deterministic
  token hash derivation from stored data, no post-request user-significant
  mutation that can bias output, and indexer-sufficient events.

Validation so far:

- PR #69 merge checked locally by fast-forwarding `main` to
  `c5623f69ef5a37be650014ced36bfeb2141bf363`.
- Issue #42 verified closed completed.
- Focused `forge test --match-contract StreamRandomizerLifecycleTest -vvv`
  passed: 19 tests, 0 failed.
- Focused `forge test --match-contract StreamRandomizerRetryTest -vvv` passed:
  10 tests, 0 failed.
- `forge fmt --check smart-contracts\StreamRandomizerLifecycle.sol
  test\StreamRandomizerLifecycle.t.sol test\StreamRandomizerRetry.t.sol`
  passed.
- `git diff --check` passed.
- Traceability grep for `P0-RAND-007`, `rawOutputHash`, raw-output hash,
  `RANDOMNESS_SEED_TYPEHASH`, and the new `RandomnessFulfilled` event signature
  passed.
- Markdown heading scan passed for `ops\ROADMAP.md`,
  `docs\adr\0005-randomness.md`, `docs\known-blockers.md`,
  `docs\status.md`, and `test\README.md`.
- `make check` passed: 171 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed:
  171 tests, 0 failed.
- Slither baseline comparison passed with unchanged counts:
  `slither_exit=-1`, `total=687`, `high=9`, `medium=29`, `weak-prng=2`,
  `arbitrary-send-eth=0`, `reentrancy-eth=0`, `reentrancy-no-eth=0`,
  `reentrancy-events=22`.
- After CodeRabbit review comments, refreshed focused lifecycle and retry
  suites, `forge fmt --check`, `git diff --check`, traceability grep, Markdown
  heading scan, full `make check`, Windows `scripts\check.ps1`, and Slither
  baseline comparison. Results remained 171 tests passing and Slither unchanged
  at `total=687`, `high=9`, `medium=29`.
- Remote CI passed on head `f8d0470b665eee2b528f95c380719014be639295` in
  GitHub Actions run `27295049942`.

Review requests:

- CodeRabbit requested in issue comment `4672775171`.
- CodeRabbit refresh requested in issue comment `4672782169` after the state
  commit moved the head.
- CodeRabbit review comments `4672797859` and `4672799547` were addressed
  locally by adding interface views, arRNG provider raw-word events, retry event
  documentation, stale zero-hash coverage, and monotonic log helpers.
- CodeRabbit latest-head re-review was requested in issue comment `4672869910`.
- CodeRabbit comment `4672884249` verified the review fixes, marked the PR
  clean, and left only non-blocking maintainability notes. Its aggregate commit
  status remained stale pending despite the clean review evidence.

Outcome:

- Merged as PR #70 on `2026-06-10 18:02 UTC`.
- Merge commit: `350667fff6472e938790f0c7db5895fc3c4ddee9`.
- Latest head before merge: `f52cd8f3cf83a8c131bdbc233c4769a4ba72e3fb`.
- Issue #43 closed completed.
- GitHub CI passed on final head in run `27295440912`.
- CodeRabbit final clean comment: `4672928268`.
- Claude was not requested for this PR per user instruction; CodeRabbit was
  sufficient.

### PR #71: Fix dependency script packed encoding (Queue Item 30)

Status: Merged.
Branch: `codex/dependency-script-safe-encoding`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/71`.
Latest head before merge: `1668c6ee9c45aca9193a48ae9b56eb81b5c02583`.
Merge commit: `20bd9d9d1fa36b7142f3a81b9ab0c86060c9f943`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/9`

Goal:

- Complete `P0-META-001` by eliminating the remaining first-party Slither
  `encode-packed-collision` row for dependency script composition.
- Preserve the current rendered dependency script output for compatibility while
  exposing typed, segment-safe chunk and content hashes for proof, indexing, and
  future freeze manifests.
- Keep full dependency versioning, registry identity pinning, provenance, and
  freeze-manifest semantics in the later `P1-META-003` workstream.

Candidate files:

- `smart-contracts/DependencyRegistry.sol`
- `smart-contracts/IDependencyRegistry.sol`
- `smart-contracts/StreamCore.sol`
- `test/StreamMetadataEncoding.t.sol`
- `docs/adr/0006-metadata-freeze.md`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Initial implementation notes:

- `DependencyRegistry` now exposes
  `getDependencyScriptChunkHash(bytes32,uint256)` and
  `getDependencyScriptContentHash(bytes32)`.
- Chunk hashes include `DEPENDENCY_SCRIPT_CHUNK_TYPEHASH`, chunk index,
  `keccak256(bytes(chunk))`, and byte length.
- Content hashes include `DEPENDENCY_SCRIPT_CONTENT_TYPEHASH`, dependency key,
  chunk count, and a folded `abi.encode` hash of all typed chunk hashes.
- `StreamCore.retrieveDependencyScript(uint256)` initializes its accumulator and
  uses `string.concat` for rendering.
- `StreamCore.retrieveDependencyScriptContentHash(uint256)` exposes the
  referenced dependency content hash for minted tokens.
- `test/StreamMetadataEncoding.t.sol` proves that chunks `["ab", "c"]` and
  `["a", "bc"]` render the same script but produce distinct typed content
  hashes, and that empty chunk hashes differ by index.

Validation so far:

- PR #70 merge checked locally by fast-forwarding `main` to
  `350667fff6472e938790f0c7db5895fc3c4ddee9`.
- Focused `forge test --match-contract StreamMetadataEncodingTest -vvv`
  passed: 2 tests, 0 failed.
- `forge fmt` ran on changed Solidity files.
- Slither delta run returned the expected remaining baseline findings while
  removing the target rows: `slither_exit=-1`, `total=685`, `high=8`,
  `medium=28`, `low=63`, `informational=580`, `optimization=6`,
  `encode-packed-collision=0`, and `uninitialized-local=10`.
- `forge fmt --check smart-contracts\DependencyRegistry.sol
  smart-contracts\IDependencyRegistry.sol smart-contracts\StreamCore.sol
  test\StreamMetadataEncoding.t.sol` passed.
- Focused `forge test --match-contract StreamMetadataEncodingTest -vvv`
  passed: 2 tests, 0 failed.
- `make check` passed: 173 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed:
  173 tests, 0 failed.
- `git diff --check` passed.
- Markdown heading scan passed for the roadmap, Slither baseline, autonomous
  run state, ADR 0006, status docs, known blockers, and test README.
- Traceability grep passed for `P0-META-001`, `StreamMetadataEncoding`,
  dependency typehashes, dependency hash views, Slither detector rows, PR #70
  merge commit `350667fff6472e938790f0c7db5895fc3c4ddee9`, and CodeRabbit
  final clean comment `4672928268`.
- Final Slither confirmation returned
  `{"slither_exit":-1,"total":685,"high":8,"medium":28,"low":63,"informational":580,"optimization":6,"encode_packed_collision":0,"uninitialized_local":10,"calls_loop":8}`.
- GitHub CI passed on head `fd0b5b89d16fc0e42a839431fcae5e7edc3b399c`
  in run `27297022773`.
- CodeRabbit comment `4673171581` confirmed the PR is correct and well-scoped,
  with only non-blocking observations.
- Follow-up addressed the non-blocking NatSpec and zero-chunk test observations
  by documenting the new public hash views and adding
  `testEmptyDependencyContentHashIsDeterministic`.
- Follow-up `forge fmt --check smart-contracts\DependencyRegistry.sol
  smart-contracts\StreamCore.sol test\StreamMetadataEncoding.t.sol` passed.
- Follow-up focused `forge test --match-contract StreamMetadataEncodingTest
  -vvv` passed: 3 tests, 0 failed.
- Follow-up `make check` passed: 174 tests, 0 failed.
- Follow-up `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed: 174 tests, 0 failed.
- Follow-up Slither confirmation remained unchanged:
  `{"slither_exit":-1,"total":685,"high":8,"medium":28,"low":63,"informational":580,"optimization":6,"encode_packed_collision":0,"uninitialized_local":10,"calls_loop":8}`.
- GitHub CI passed on final head in run `27297432586`.
- CodeRabbit final clean comment: `4673227541`.
- Issue #9 closed completed.

Review requests:

- CodeRabbit requested in issue comment `4673145958`.
- CodeRabbit review comment `4673171581` reported the PR correct and
  well-scoped; non-blocking observations were addressed in follow-up.
- Claude is intentionally skipped per current user instruction; use CodeRabbit
  unless risk or future user instruction changes.

### PR #72: Remove dead mint-accounting state (Queue Item 31)

Status: Merged.
Branch: `codex/remove-dead-mint-accounting`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/72`.
Latest head before merge: `a0c6830862719861648697d722027b40c2090401`.
Merge commit: `ba2f0cd483bd178f801250ee6ef842ff3a4e77a5`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/13`

Goal:

- Complete `P0-CORE-001` by resolving the two first-party Slither
  `uninitialized-state` rows in `StreamCore`.
- Remove the never-written public-sale and allowlist mint-count mappings rather
  than expose always-zero views with no accepted drop quota or allowlist
  semantics.
- Preserve and test the retained airdrop counter as the only current
  per-address mint-accounting surface in `StreamCore`.

Candidate files:

- `smart-contracts/StreamCore.sol`
- `smart-contracts/IStreamCore.sol`
- `test/StreamMintAccounting.t.sol`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Removed `tokensMintedPerAddress` and
  `tokensMintedAllowlistAddress` from `StreamCore`.
- Removed `retrieveTokensMintedPublicPerAddress` and
  `retrieveTokensMintedALPerAddress` from `StreamCore` and `IStreamCore`.
- Added `test/StreamMintAccounting.t.sol` to prove the retained airdrop counter
  starts at zero, increments on authorized minter calls, and remains unchanged
  after an unauthorized mint attempt.
- Updated `ops/SLITHER_BASELINE.md` and `ops/ROADMAP.md` to mark
  `uninitialized-state` as `0 current / 2 fixed`.

Validation:

- PR #71 merge checked locally by fast-forwarding `main` to
  `20bd9d9d1fa36b7142f3a81b9ab0c86060c9f943`.
- `forge fmt --check smart-contracts\StreamCore.sol
  smart-contracts\IStreamCore.sol test\StreamMintAccounting.t.sol` passed.
- Focused `forge test --match-contract StreamMintAccountingTest -vvv` passed:
  2 tests, 0 failed.
- `make check` passed: 176 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed:
  176 tests, 0 failed.
- `git diff --check` passed.
- Markdown heading scan passed for the roadmap, Slither baseline, autonomous
  run state, status docs, known blockers, and test README.
- Traceability grep passed for `P0-CORE-001`, `StreamMintAccounting`,
  `uninitialized-state`, `uninitialized_state`, Slither count `680`, branch
  `codex/remove-dead-mint-accounting`, and PR #71 merge commit
  `20bd9d9d1fa36b7142f3a81b9ab0c86060c9f943`.
- Slither confirmation returned
  `{"slither_exit":-1,"total":680,"high":6,"medium":28,"low":63,"informational":577,"optimization":6,"uninitialized_state":0,"uninitialized_local":10,"weak_prng":2,"encode_packed_collision":0}`.

Review requests:

- CodeRabbit requested in issue comment `4673355477`.
- CodeRabbit final review/status was clean on head
  `a0c6830862719861648697d722027b40c2090401`; review comment
  `4673355663` reported no actionable comments.
- Claude is intentionally skipped per current user instruction; use CodeRabbit
  unless risk or future user instruction changes.

Outcome:

- Merged as PR #72 on `2026-06-10`.
- GitHub CI run `27298359897` passed on the final head.
- Issue #13 closed completed.

### PR #73: Remove weak helper randomness (Queue Item 32)

Status: Merged.
Branch: `codex/remove-weak-helper-randomness`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/74`.
Latest head before merge: `4ce60549922db5b223597be7c69ff0e94b3b3af5`.
Merge commit: `8ced3efa316211fa634187c596d3db64e0b4c665`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/73`

Goal:

- Complete `P0-RAND-008` by removing the concrete `XRandoms` weak randomness
  helper from production source.
- Keep `RandomizerNXT` legacy-only and impossible to configure through
  `StreamCore.addRandomizer`.
- Refresh Slither, roadmap, ADR, status, and test traceability so the two
  former `weak-prng` rows are marked fixed instead of accepted risk.

Candidate files:

- `smart-contracts/XRandoms.sol`
- `smart-contracts/IXRandoms.sol`
- `docs/adr/0005-randomness.md`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Deleted `smart-contracts/XRandoms.sol`.
- Kept `smart-contracts/IXRandoms.sol` because `RandomizerNXT` and the inline
  `MockXRandoms` regression still need the interface.
- Formatted `IXRandoms` so the touched legacy boundary passes targeted
  `forge fmt --check`.
- Kept `RandomizerNXT.isRandomizerContract()` returning false, so
  `StreamCore.addRandomizer` rejects it for production collections.
- Created issue #73 as the concrete implementation tracker because issue #14
  already closed the ADR decision.

Validation so far:

- Focused `forge test --match-test
  testNxtRandomizerCannotBeConfiguredForProductionCollections -vvv` passed:
  1 test, 0 failed.
- `make check` passed on the final local head: 176 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed on the
  final local head: 176 tests, 0 failed.
- `forge fmt --check smart-contracts\IXRandoms.sol
  smart-contracts\RandomizerNXT.sol test\StreamRandomizerLifecycle.t.sol`
  passed.
- `git diff --check` passed.
- Markdown heading scan passed for the roadmap, Slither baseline, autonomous
  run state, ADR 0005, status docs, known blockers, and test README.
- Traceability grep passed for `P0-RAND-008`, issue #73, `weak-prng=0`,
  Slither count `676`, `4 High`, branch `codex/remove-weak-helper-randomness`,
  and `testNxtRandomizerCannotBeConfiguredForProductionCollections`.
- Slither confirmation returned
  `{"arbitrary_send_eth":0,"high":4,"informational":575,"low":63,"medium":28,"optimization":6,"reentrancy_eth":0,"slither_exit":-1,"total":676,"uninitialized_state":0,"weak_prng":0}`.

Review requests:

- CodeRabbit requested in issue comment `4673578679`.
- CodeRabbit final review/status was clean on head
  `4ce60549922db5b223597be7c69ff0e94b3b3af5`; review comment
  `4673579305` reported no actionable comments and all pre-merge checks passed.
- Claude is intentionally skipped per current user instruction; use CodeRabbit
  unless risk or future user instruction changes.

Outcome:

- Merged as PR #74 on `2026-06-10`.
- GitHub CI run `27299886749` passed on the final head.
- Issue #73 closed completed.

### PR #75: Resolve first-party uninitialized locals (Queue Item 33)

Status: Merged.
Branch: `codex/resolve-uninitialized-locals`.
Pull request: `#75`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/15`

Goal:

- Complete `P0-INIT-001` by resolving the remaining first-party production
  Slither `uninitialized-local` rows.
- Preserve behavior by making Solidity default locals explicit instead of
  changing control flow.
- Add targeted tests for externally observable default-local behavior in
  string counting, delegation status/gating, generated script rendering, and
  minter return indexes.

Candidate files:

- `smart-contracts/Bytes32Strings.sol`
- `smart-contracts/NFTdelegation.sol`
- `smart-contracts/StreamCore.sol`
- `smart-contracts/StreamMinter.sol`
- `test/StreamInitialization.t.sol`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Initialized `Bytes32Strings.containsExactCharacterQty`'s occurrence counter
  and loop index explicitly.
- Initialized `NFTdelegation` subdelegation-rights and status accumulators
  explicitly to false.
- Initialized `StreamCore.retrieveGenerativeScript`'s script accumulator to an
  empty string.
- Initialized `StreamMinter.mint`'s returned `mintIndex` to zero.
- Added `test/StreamInitialization.t.sol` covering the production rows and
  keeping the accepted test-only `MockStreamMinter` baseline separate.

Validation so far:

- `forge fmt --check smart-contracts\Bytes32Strings.sol
  smart-contracts\NFTdelegation.sol smart-contracts\StreamCore.sol
  smart-contracts\StreamMinter.sol test\StreamInitialization.t.sol` passed.
- Focused `forge test --match-path test\StreamInitialization.t.sol -vvv`
  passed: 6 tests, 0 failed.
- `make check` passed on the final local head: 182 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed on the
  final local head: 182 tests, 0 failed.
- `git diff --check` passed.
- Markdown heading scan passed for the roadmap, Slither baseline, autonomous
  run state, status docs, known blockers, and test README.
- Traceability grep passed for `P0-INIT-001`, issue #15,
  `uninitialized-local`, `uninitialized_local`, `StreamInitialization`,
  `testBytes32CharacterCountingUsesExplicitZeroStart`,
  `testSubdelegationRightsGateRegisterAndRevokePaths`, branch
  `codex/resolve-uninitialized-locals`, and Queue Item 33.
- Slither confirmation returned
  `{"slither_exit":-1,"total":666,"high":4,"medium":19,"low":63,"informational":574,"optimization":6,"uninitialized_local":1,"weak_prng":0,"uninitialized_state":0,"arbitrary_send_eth":0,"reentrancy_eth":0}`.
- The only current `uninitialized-local` row is the accepted test-only
  `test/mocks/MockStreamMinter.sol#L71` `mintedCount` helper.

Review requests:

- CodeRabbit finished successfully on final head `b28466f`.
- Claude is intentionally skipped per current user instruction; use CodeRabbit
  unless risk or future user instruction changes.

Outcome:

- Merged as PR #75 on `2026-06-10`.
- GitHub CI run `27301659259` passed on the final head.
- CodeRabbit status was green and both actionable review threads were marked
  addressed.
- Issue #15 closed completed.

### PR #76: Prove vendored library provenance (Queue Item 34)

Status: Merged.
Branch: `codex/prove-vendored-library-provenance`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/76`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/11`

Goal:

- Complete `P0-LIB-001` by proving provenance for retained OpenZeppelin utility
  files and resolving the remaining vendored high/medium Slither rows without
  suppressing detectors.
- Add focused regressions for the exact `Base64` and `Math.mulDiv` behavior
  Slither flags.
- Keep the current import layout stable; do not introduce package-manager churn
  in the same PR.

Candidate files:

- `docs/vendored-libraries.md`
- `smart-contracts/Strings.sol`
- `test/StreamVendoredLibraries.t.sol`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Added a vendored-library manifest with OpenZeppelin tag URLs, upstream
  hashes, local hashes, and local delta notes.
- Corrected the `Strings.sol` provenance header to the v4.9.0 OpenZeppelin
  content it actually matches, while keeping local sibling imports.
- Added focused Base64 golden-vector/padding tests and `Math.mulDiv`
  precision, rounding, overflow, and zero-denominator tests.
- Updated Slither baseline, roadmap, status, blockers, and test README
  traceability so the vendored rows are documented false positives rather than
  `Needs Issue`.

Validation so far:

- `forge fmt --check test\StreamVendoredLibraries.t.sol` passed.
- Focused `forge test --match-path test\StreamVendoredLibraries.t.sol -vvv`
  passed: 5 tests, 0 failed.
- `make check` passed on the final local head: 187 tests, 0 failed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed on the
  final local head: 187 tests, 0 failed.
- `git diff --check` passed.
- Markdown heading scan passed for the vendored-library doc, status docs, test
  README, roadmap, Slither baseline, and autonomous run state.
- Traceability grep passed for `P0-LIB-001`, `StreamVendoredLibraries`,
  `docs/vendored-libraries.md`, `False Positive`, `incorrect-exp`,
  `divide-before-multiply`, OpenZeppelin v4.7.0/v4.8.0/v4.9.0 tags, and the
  `668 total` / `4 High and 19 Medium` Slither status.
- Slither confirmation returned
  `{"slither_exit":-1,"total":668,"high":4,"medium":19,"low":63,"informational":575,"optimization":7,"incorrect_exp":1,"divide_before_multiply":9,"unused_return":1}`.
- The only current `unused-return` row remains the accepted test-only
  `StreamDropsERC1271Test` tuple helper; the vendored-library test adds no
  high/medium Slither rows.

Review requests:

- CodeRabbit was requested and completed without remaining actionable comments.
- Claude is intentionally skipped per current user instruction; use CodeRabbit
  unless risk or future user instruction changes.

Outcome:

- Merged as PR #76 on `2026-06-10 20:18 UTC`.
- Follow-up review fix added an exact `Panic(uint256)` zero-denominator revert
  assertion for the vendored `Math.mulDiv` regression.
- GitHub CI run `27303499168` passed on the final head.
- CodeRabbit status was green on the final head.
- Issue #11 closed as completed.

### PR `#77`: Add payment invariant baseline (Queue Item 35)

Status: Merged.
Branch: `codex/add-payment-invariant-baseline`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/77`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/8`

Goal:

- Complete the remaining P0-PAY-008 test gap by adding a bounded sequence fuzz
  invariant baseline for the current local payment ledgers.
- Exercise fixed-price drops, auction bidding/settlement, curator claims,
  withdrawals, emergency withdrawals, randomizer reserves, and deterministic
  forced-balance surplus in mixed orders.
- Prove category totals equal per-account credits, contract balances cover owed
  and reserved funds, and emergency-withdrawable views expose only surplus.
- Keep broader shared-ledger abstraction work open for issues #25, #26, and #30
  unless a later implementation introduces a unified protocol-wide ledger.

Candidate files:

- `test/StreamPaymentsInvariant.t.sol`
- `docs/known-blockers.md`
- `docs/status.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/SLITHER_BASELINE.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Added `StreamPaymentsInvariantTest`, a bounded sequence fuzz harness that
  runs 24 mixed operations per generated sequence.
- The handler deploys real `StreamDrops`, `StreamAuctions`,
  `StreamCuratorsPool`, `StreamMinter`, and `NextGenRandomizerRNG` instances
  and shares a configured `StreamAdmins.emergencyRecipient()`.
- Invariants assert local Drops, Auctions, CuratorsPool, StreamMinter, and RNG
  category totals, owed totals, balance coverage, reserves, and
  emergency-withdrawable surplus after every operation.
- The sequence uses `vm.deal` as a deterministic forced-balance model; existing
  scenario tests still cover the selfdestruct-forced ETH path directly.
- Kept Slither high/medium counts stable by moving harmless harness bookkeeping
  before external calls where rollback preserves correctness, and by adding
  narrow source-level suppressions for deliberate test-only payable calls,
  generated-sequence bookkeeping, and the payable mock randomness provider.
- Applied CodeRabbit review fixes: recorded concrete PR numbering and full
  merge timestamp in this run log, decoupled bid amount generation from action
  selection in the fuzz harness, and added harness bookkeeping to skip duplicate
  randomizer requests for synthetic token IDs.

Validation so far:

- `forge fmt --check test\StreamPaymentsInvariant.t.sol` passed.
- Focused `forge test --match-path test\StreamPaymentsInvariant.t.sol -vvv`
  passed: 1 fuzz test, 256 runs, 0 failed.
- Canonical local gate passed: `make check` with 188 tests, 0 failed.
- Windows wrapper passed:
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` with 188 tests,
  0 failed.
- Formatting, whitespace, Markdown heading scan, and traceability greps passed:
  `forge fmt --check test\StreamPaymentsInvariant.t.sol`,
  `git diff --check`, `rg -n "^#|^##|^###" ...`, and traceability grep for
  `StreamPaymentsInvariant`, `P0-PAY-008`, `bounded sequence fuzz`, and Slither
  suppression markers.
- Slither remains non-gating and exits non-zero because accepted test-only,
  vendored false-positive, and lower-impact findings remain. The final JSON
  reports 693 total findings: 4 High, 19 Medium, 82 Low, 577 Informational, and
  11 Optimization. High/medium counts are unchanged versus the previous tracked
  baseline, `arbitrary-send-eth=0`, `reentrancy-eth=0`,
  `reentrancy-no-eth=0`, `incorrect-equality=1`, and `locked-ether=7`.
- After CodeRabbit review fixes, focused invariant testing, `make check`, the
  Windows wrapper, `git diff --check`, and Slither were rerun successfully on
  `2026-06-10 20:54 UTC`. Slither remained unchanged at 693 total findings, 4
  High, and 19 Medium.

Review requests:

- CodeRabbit was requested in issue comment `4674282933`.
- CodeRabbit completed on commit `54597eaa77995236d65e54df33e77db323fd3c54`
  with two inline comments and one outside-diff comment; all three are applied
  in the local review-fix diff.
- Claude is intentionally skipped per current user instruction; use CodeRabbit
  unless risk or future user instruction changes.

Outcome:

- Merged as PR #77 on `2026-06-10 20:57 UTC`.
- GitHub CI run `27305755033` passed on the final head.
- CodeRabbit status was green on the final head and previous review threads
  were resolved as addressed by commit `5b25559`.
- Issue #8 closed as completed.

### PR `#78`: Add payment ledger view aliases (Queue Item 36)

Status: Merged.
Branch: `codex/add-payment-ledger-view-aliases`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/78`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/26`

Goal:

- Close the remaining P0-PAY-002 view-surface gap by making the accepted ADR
  0003 local-ledger model easier to query consistently.
- Add additive read APIs for `totalReserved()` and `surplus()` to current
  value-holding payment surfaces.
- Add fixed-price category aliases in `StreamDrops` so poster, protocol, and
  curator-reserve totals are available under ADR-style names.
- Assert the aliases in `StreamPaymentsInvariant.t.sol` so mixed payment
  operation sequences keep the new views coherent.
- Reconcile roadmap/status/docs state without introducing a riskier shared
  storage abstraction in this PR.

Candidate files:

- `smart-contracts/StreamDrops.sol`
- `smart-contracts/AuctionContract.sol`
- `smart-contracts/StreamCuratorsPool.sol`
- `smart-contracts/StreamMinter.sol`
- `smart-contracts/RandomizerRNG.sol`
- `test/StreamPaymentsInvariant.t.sol`
- `docs/adr/0003-payment-accounting.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Added additive local-ledger view aliases only; no existing payment behavior,
  storage layout, authorization, custody, or withdrawal semantics changed.
- `StreamDrops` now exposes fixed-price poster/protocol/curator-reserve totals
  through ADR-style aliases and treats curator reserve as the contract-local
  reserved balance.
- `StreamAuctions` now exposes active highest-bid escrow as its local reserved
  balance and zero-valued aliases for categories it does not own.
- `StreamCuratorsPool`, `StreamMinter`, and `NextGenRandomizerRNG` now expose
  the same `totalReserved()` / `surplus()` local-ledger view pattern.
- The bounded payment sequence invariant now asserts the aliases after every
  generated operation.

Validation so far:

- `forge test --match-path test\StreamPaymentsInvariant.t.sol -vvv` passed.
- `make check` passed with 188 tests.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with
  188 tests.
- `forge fmt --check smart-contracts\StreamDrops.sol
  smart-contracts\AuctionContract.sol smart-contracts\StreamCuratorsPool.sol
  smart-contracts\StreamMinter.sol smart-contracts\RandomizerRNG.sol
  test\StreamPaymentsInvariant.t.sol` passed.
- `git diff --check` passed.
- `rg -n "totalReserved\(\)|surplus\(\)|P0-PAY-002|Add payment ledger view
  aliases" smart-contracts test docs ops` found the expected code, test, docs,
  and run-state references.
- Slither completed with the existing accepted baseline unchanged: 693 total
  findings; High 4, Medium 19, Low 82, Informational 577, Optimization 11.

Review requests:

- CodeRabbit requested in issue comment `4674566512`.
- CodeRabbit completed with green status and one valid nitpick in review
  `4471658076`; accepted by updating this section header to `PR #78`.
- Claude remains intentionally skipped per current user instruction; use
  CodeRabbit unless risk or future user instruction changes.

Outcome:

- Merged as PR #78 on `2026-06-10 21:25 UTC`.
- Merge commit `785f9ebca5c91a18e0cdbe20b35a8b0c955bfb3f`.
- GitHub CI run `27307238585` passed on the final head.
- CodeRabbit status was green on the final head; the only review nitpick was
  fixed by commit `dc8b206`.
- Issue #26 closed as completed.

### PR #80: Add signer lifecycle manager (Queue Item 37)

Status: Merged.
Branch: `codex/add-signer-lifecycle-manager`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/80`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/79`

Goal:

- Complete the remaining ADR 0004 signer-lifecycle implementation gap by
  separating drop-signing identities from signer-management authority.
- Add an explicit signer-manager role and signer-lifecycle target allowlist in
  `StreamAdmins` that the governance root can grant and revoke.
- Preserve owner/root recovery while removing the constructor drop signer's
  implicit role-management authority.
- Add signer-lifecycle tests for grants, revocation, rotation, stale payload
  rejection, fresh signer payload success, and per-drop cancellation.
- Update ADR/status/roadmap/test docs and run-state traceability.

Candidate files:

- `smart-contracts/StreamAdmins.sol`
- `test/StreamAdmins.t.sol`
- `test/StreamAdminSelectors.t.sol`
- `test/StreamSignerAdmin.t.sol`
- `docs/adr/0004-admin-governance.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/SLITHER_BASELINE.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Added root-managed signer managers to `StreamAdmins` through
  `registerSignerManager`, owner-approved signer-lifecycle targets through
  `registerSignerLifecycleTarget`, exact signer-lifecycle selector grants, and
  batch signer-lifecycle grants.
- Removed the constructor drop signer's implicit role-management authority; the
  governance owner/root remains the recovery path for broad role grants.
- Restricted signer managers to approved targets and the exact `StreamDrops`
  lifecycle selectors: `updateTDHsigner(address)`, `incrementSignerEpoch()`,
  and `cancelDrop(bytes32)`.
- Added signer-manager event/test coverage for grant, revoke, disallowed broad
  role management, and disallowed non-signer selector grants.
- Added `StreamSignerAdmin.t.sol` coverage for signer-manager grants, signer
  rotation invalidating stale payloads, fresh new-signer payload execution,
  per-drop cancellation before execution, cancellation failure after
  consumption, and unauthorized lifecycle calls.
- Converted legacy test setup assumptions exposed by the constructor change into
  explicit selector grants, keeping the production contract strict while
  preserving the old tests' intended assertions.
- Updated ADR 0004, roadmap/status/blocker docs, test README, and Slither
  baseline traceability.

Validation so far:

- Focused admin/signer/drop/pause coverage passed:
  `forge test --match-contract "Stream(Admins|AdminSelectors|SignerAdmin|DropsEIP712|PauseControls)Test" -vvv`
  with 59 tests passing.
- Additional focused regression suites passed while migrating explicit test
  grants: `StreamCuratorsPoolTest`,
  `Stream(CoreAdminCharacterization|RandomizerRetry)Test`, and
  `Stream(EmergencyWithdraw|DropsCharacterization)Test`.
- Full local gate passed: `make check` with 197 tests passing.
- Windows contributor wrapper passed:
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` with 197 tests
  passing.
- Formatting check passed for all touched Solidity/test files:
  `forge fmt --check ...`.
- Whitespace check passed: `git diff --check`.
- Traceability grep passed for `P0-ADMIN-003`, signer manager APIs, and
  `StreamSignerAdmin`.
- Slither ran with pinned toolchain and expected non-zero baseline exit:
  721 total findings; High 4, Medium 19, Low 92, Informational 595,
  Optimization 11. High/medium counts are unchanged; `arbitrary-send-eth`,
  `reentrancy-eth`, `encode-packed-collision`, `weak-prng`, and
  `uninitialized-state` remain at zero current findings.

Review requests:

- CodeRabbit requested in issue comment `4675002714`.
- Latest-head CodeRabbit requested in issue comment `4675011167` after the
  state-only follow-up commit; CodeRabbit completed with green status and no
  actionable comments in comment `4675002972`.
- Claude remains intentionally skipped per current user instruction; use
  CodeRabbit unless risk or future user instruction changes.

Outcome:

- Merged as PR #80 on `2026-06-10 22:08 UTC`.
- Merge commit `9c81f71c59357dd124d3513ca6a006ceeba9ad55`.
- Latest head before merge `d4a13a19c19a5f609ea75a308f6defdf17c019e5`.
- GitHub CI run `27309047754` passed on the final head.
- CodeRabbit status was green on the final head and reported no actionable
  comments.
- Issue #79 closed as completed.

### PR #81: Add metadata schema and golden-file tests (Queue Item 38)

Status: Merged.
Branch: `codex/metadata-golden-tests`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/81`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/46`

Goal:

- Start the Gate D metadata verification track under P1-META-001.
- Lock current off-chain pending/final `tokenURI` behavior with deterministic
  golden expectations before deeper metadata rewrites.
- Add on-chain JSON metadata golden coverage for the current schema where the
  existing contract behavior permits stable fixtures.
- Document the current schema/output policy honestly and update roadmap/test
  matrix traceability.

Candidate files:

- `test/StreamMetadataGolden.t.sol`
- `test/fixtures/metadata/`
- `foundry.toml`
- `test/helpers/CharacterizationTestBase.sol`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Added fixture read permissions for `test/fixtures` and exposed
  `vm.readFile` through the local characterization cheatcode interface.
- Added four metadata golden fixtures:
  off-chain pending URI, off-chain final URI, current on-chain pending JSON
  data URI, and current on-chain final JSON data URI.
- Added `StreamMetadataGolden.t.sol` coverage that mints the same deterministic
  token and compares live `tokenURI` output byte-for-byte against fixtures.
- Explicitly labels current on-chain pending output as pre-beta behavior because
  it still embeds the zero token hash; ADR 0006 public-beta work must replace
  this with an explicit pending metadata state.
- Added `docs/metadata.md` with current output shape, fixture purpose, and
  public-beta target requirements.
- Updated roadmap, status, known-blockers, and test README traceability.

Validation so far:

- Focused metadata golden tests passed:
  `forge test --match-contract StreamMetadataGoldenTest -vvv` with 4 tests.
- Full `make check` passed with 201 tests.
- Windows wrapper passed:
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` with 201 tests.
- Formatting check passed:
  `forge fmt --check test\StreamMetadataGolden.t.sol test\helpers\CharacterizationTestBase.sol`.
- Markdown heading scan passed for touched docs/ops/test README files:
  `rg -n "^#|^##|^###" ...`.
- Metadata traceability grep passed across `foundry.toml`, `docs`, `test`, and
  `ops`.
- `git diff --check` passed.
- Slither baseline comparison passed with no new detector count:
  721 total findings, 4 High, 19 Medium, 92 Low, 595 Informational, and 11
  Optimization.
- After CodeRabbit's final-state guard review, focused metadata tests, full
  `make check`, Windows wrapper, and Slither baseline comparison all passed
  again; total tests remain 201 and Slither remains at 721 total findings.

Review requests:

- CodeRabbit requested in issue comment `4675228562`.
- Latest-head CodeRabbit requested in issue comment `4675238958` after the
  state-only follow-up commit; CodeRabbit acknowledged the request in comment
  `4675243338`.
- CodeRabbit review comment `4675250990` requested explicit nonzero-hash guards
  in final metadata tests. Local fix adds those guards while keeping the
  non-blocking helper-promotion note deferred.
- Follow-up CodeRabbit nitpicks were accepted where useful: clarified raw
  `collectionBaseURI` concatenation in metadata docs, made the queue status
  explicitly reference PR #81 and the branch, and documented that
  `NoopRandomizer` is defined in `MockRandomizer.sol`.
- Claude remains intentionally skipped per current user instruction; use
  CodeRabbit unless risk or future user instruction changes.

Outcome:

- Merged as PR #81 on `2026-06-10 22:40 UTC`.
- Merge commit `2b2dbab92c2f4833a8b2e6fff84638ea52edda63`.
- Latest head before merge `226fd28c89e035b233299e4c9299b0e3d5e38a2d`.
- GitHub CI run `27310936726` passed on the final head.
- CodeRabbit explicitly confirmed the guard fix and nitpick fixes in comments
  `4675293732` and `4675354682`, with no further concerns. The CodeRabbit
  commit status remained stale pending, so the autonomous maintainer decision
  used the bot's explicit review comments plus green CI and resolved threads.

### PR #82: Add ERC-4906 metadata update signaling (Queue Item 39)

Status: PR open; waiting for CI and CodeRabbit.
Branch: `codex/metadata-erc4906-events`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/82`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/49`

Goal:

- Implement P1-META-004 for current `StreamCore` metadata behavior.
- Expose ERC-4906 interface support through `supportsInterface(0x49064906)`.
- Emit `MetadataUpdate` for live-token metadata input writes and randomness
  fulfillment.
- Emit `BatchMetadataUpdate` for collection-level metadata mutations over the
  minted-ever contiguous token range.
- Avoid misleading ERC-4906 events for mint-only and burn paths.
- Document current event semantics and update roadmap/test traceability.

Candidate files:

- `smart-contracts/IERC4906.sol`
- `smart-contracts/StreamCore.sol`
- `test/StreamMetadataEvents.t.sol`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Added a minimal `IERC4906` event interface and manual ERC-4906 interface ID
  support in `StreamCore`.
- `setTokenHash` emits `MetadataUpdate` only when the token is still live.
- `changeTokenData` and `updateImagesAndAttributes` emit token-level
  `MetadataUpdate` events.
- `changeMetadataView` and `updateCollectionInfo` emit `BatchMetadataUpdate`
  for the collection's minted-ever token range and skip empty collections.
- Mint-only and burn behavior intentionally do not emit ERC-4906 events.
- Dependency registry content reverse signaling remains future P1-META-003 work
  because the current registry does not know which collections use each
  dependency key; dependency reference changes through `updateCollectionInfo`
  do emit collection batch events.

Validation:

- Focused ERC-4906 metadata event tests passed:
  `forge test --match-contract StreamMetadataEventsTest -vvv` with 7 tests.
- Full canonical local gate passed: `make check` with 208 tests, 0 failed.
- Windows wrapper passed:
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` with 208 tests,
  0 failed.
- Touched-file formatting passed:
  `forge fmt --check smart-contracts\IERC4906.sol smart-contracts\StreamCore.sol test\StreamMetadataEvents.t.sol`.
- Diff whitespace check passed: `git diff --check`.
- Markdown heading scan passed for `docs\metadata.md`, `docs\status.md`,
  `docs\known-blockers.md`, `test\README.md`, `ops\ROADMAP.md`, and
  `ops\AUTONOMOUS_RUN.md`.
- Traceability grep passed for `P1-META-004`, `ERC-4906`, `MetadataUpdate`,
  `BatchMetadataUpdate`, `StreamMetadataEvents`, `0x49064906`,
  `codex/metadata-erc4906-events`, and `Queue Item 39`.
- Slither baseline comparison remains unchanged from the accepted baseline:
  `721` total findings, `4` High, `19` Medium, `92` Low, `595`
  Informational, `11` Optimization. Test-only `StreamMetadataEvents`
  `reentrancy-events` rows are `0`.

Review requests:

- CodeRabbit requested in comment `4675495632`.
- Claude remains intentionally skipped per current user instruction; use
  CodeRabbit unless risk or future user instruction changes.

## Decision Log

| Time UTC | Decision | Rationale |
| --- | --- | --- |
| 2026-06-09 22:34 | Use `ops/ROADMAP.md` as canonical roadmap | Existing roadmap already contains detailed gates, P0 issues, ADRs, Slither appendix, and test matrix |
| 2026-06-09 22:34 | Add `ops/AUTONOMOUS_RUN.md` as durable state | Long-running execution needs repo-persisted state across compaction and PR cycles |
| 2026-06-09 22:34 | Start with a docs/state PR | It establishes the control plane before code changes and is low risk |
| 2026-06-09 22:34 | Create PR 1 from a clean branch based on `origin/main` | The initial checkout contained unrelated dirty files and was on the already-merged PR #2 branch |
| 2026-06-09 22:36 | Open PR #3 for roadmap/control-plane work | PR contains only `ops/ROADMAP.md` and `ops/AUTONOMOUS_RUN.md` |
| 2026-06-09 22:49 | Merge PR #3 | CodeRabbit was green and review threads were resolved |
| 2026-06-09 22:55 | Start Gate A reproducible-baseline PR | Fresh Foundry config exposed that the prior build baseline compiled nothing |
| 2026-06-09 22:55 | Allow compile-surface import fixes in PR 2 | Honest `forge build` requires the randomizer contracts to import existing Stream interfaces |
| 2026-06-09 23:00 | Local validation passed for PR 2 | `make check` and Windows `scripts/check.ps1` pass; generated Foundry artifacts are ignored |
| 2026-06-09 23:02 | Open PR #4 | Explicit Claude review requested because bot review may not run automatically |
| 2026-06-09 23:18 | Implement Claude PR #4 review fixes | Harden Windows/Linux bootstrap, Makefile PATH handling, bash missing-tool UX, and env template ignores |
| 2026-06-09 23:23 | Implement CodeRabbit PR #4 review fixes | Pin CI actions to commit SHAs, disable persisted checkout credentials, and clarify the PR worklog label |
| 2026-06-09 23:28 | Mark PR #4 merge-ready | CI passed, CodeRabbit latest pass had no actionable comments, and visible review threads are resolved |
| 2026-06-09 23:33 | Merge PR #4 | Latest head was CI-clean, CodeRabbit-clean, and all visible review threads were resolved |
| 2026-06-09 23:35 | Start PR #5 | Queue Item 3 adds security, contribution, issue, PR, and ownership intake files before deeper implementation work |
| 2026-06-09 23:43 | Finish local PR #5 validation | Docs/templates parse cleanly, CI hygiene syntax passes, and both smoke entrypoints pass |
| 2026-06-09 23:46 | Open PR #5 | PR packages contributor/security intake docs, review routing, issue forms, PR template, CODEOWNERS, and small CI hygiene |
| 2026-06-09 23:59 | Implement Claude PR #5 review fixes | Make CI hygiene checks validate the PR diff, parse each Bash script, use the full PowerShell parser, and preserve main-branch CI artifacts |
| 2026-06-10 00:05 | Mark PR #5 merge-ready | CI passed, CodeRabbit returned no actionable comments, and Claude review threads were resolved after the workflow fixes |
| 2026-06-10 00:10 | Merge PR #5 | Final head was CI-clean, CodeRabbit-clean, and visible Claude review threads were resolved |
| 2026-06-10 00:17 | Start PR #6 | Queue Item 4 adds the first executable characterization tests without changing production contract behavior |
| 2026-06-10 00:23 | Finish local PR #6 validation | `make check` and `scripts/check.ps1` pass with 14 characterization tests; scope remains test/docs only |
| 2026-06-10 00:29 | Address sidecar PR #6 auction coverage finding | Added real auction mint custody integration coverage through `StreamDrops -> StreamMinter -> StreamCore`; `make check` now passes with 15 tests |
| 2026-06-10 00:36 | Address CodeRabbit PR #6 nitpicks | Consolidated repetitive fixed-price roadmap bullets and expanded `MockStreamMinter` to record full mint batches |
| 2026-06-10 00:45 | Address CodeRabbit PR #6 second-pass comment | Added the empty-batch guard before `MockStreamMinter` reads the first mint array elements |
| 2026-06-10 00:55 | Address Claude PR #6 characterization-honesty comment | Renamed the poster rejection test and added explicit payout-address and curators-pool rejection characterization cases |
| 2026-06-10 01:04 | Address CodeRabbit PR #6 token-hash authorization comment | Mint with a no-op randomizer before the non-randomizer `setTokenHash` assertion, then switch to the configured randomizer to prove first-set and no-overwrite behavior |
| 2026-06-10 01:12 | Merge PR #6 | Final head was CI-clean, CodeRabbit-clean, and visible review threads were resolved or outdated |
| 2026-06-10 01:14 | Start PR #7 | Queue Item 5 captures the Slither high/medium baseline before any detector suppressions or CI gating |
| 2026-06-10 01:17 | Keep Slither non-gating | Slither currently exits non-zero because real findings exist; `make check` remains build/test only until baseline acceptance |
| 2026-06-10 01:17 | Do not suppress Slither detectors yet | The config only filters generated artifact paths; findings stay visible until each high/medium row is fixed, accepted, or proved false positive |
| 2026-06-10 01:24 | Validate config-backed Slither run | `slither . --config-file slither.config.json --foundry-compile-all --json <temp-file>` returned JSON success with 530 findings and expected exit `-1` |
| 2026-06-10 01:27 | Finish local PR #7 smoke validation | Config JSON, Makefile dry-run, ignore rules, Markdown heading scan, `make check`, and Windows `scripts/check.ps1` pass |
| 2026-06-10 01:29 | Finish staged PR #7 validation | `git diff --cached --check` passes after staging all PR #7 files |
| 2026-06-10 01:31 | Open PR #7 | PR packages the Slither config, tracked high/medium baseline, docs links, and durable state updates |
| 2026-06-10 01:37 | Address CodeRabbit PR #7 review | Add compiler activation instructions, mark vendored likely false positives as `Needs Issue`, and assign `P0-META-001` to dependency-script packed encoding |
| 2026-06-10 01:38 | Validate CodeRabbit PR #7 follow-up | JSON parse, targeted text checks, heading scan, whitespace check, and `make check` pass after review edits |
| 2026-06-10 01:41 | Merge PR #7 | CI and CodeRabbit were clean, no review threads were open, and Claude did not respond after two explicit review pings |
| 2026-06-10 01:48 | Create Slither baseline GitHub issues | Group high/medium Slither rows by remediation stream so each open or needs-issue row has a canonical work item |
| 2026-06-10 01:51 | Start PR #8 | Queue Item 6 replaces Slither `TBD` issue placeholders with real GitHub issue links before ADR implementation begins |
| 2026-06-10 01:54 | Validate PR #8 locally | Slither issue-column check, Markdown heading scan, whitespace check, `make check`, and Windows wrapper all pass |
| 2026-06-10 01:55 | Open PR #16 | PR packages the Slither issue-link updates and explicitly asks Claude for review |
| 2026-06-10 01:59 | Merge PR #16 | CI and CodeRabbit were clean, no review threads were open, and Claude did not respond after two explicit review pings |
| 2026-06-10 02:01 | Start drop authorization ADR PR | Gate B1 requires accepted auth design before `tx.origin`, EIP-712, or ERC-1271 implementation |
| 2026-06-10 02:03 | Create auth follow-up issues | Add canonical issues for `P0-AUTH-ADR`, `P0-AUTH-001`, and `P0-AUTH-003`; `P0-AUTH-002` already exists as issue #10 |
| 2026-06-10 02:09 | Open PR #20 | Drop authorization ADR is published with validation evidence and Claude was explicitly pinged in issue comment `4665813753` |
| 2026-06-10 02:18 | Address CodeRabbit PR #20 review | Clarify that `nonce` is the signer-epoch opaque input and `dropId` is the derived replay/cancellation key |
| 2026-06-10 02:24 | Address Claude PR #20 review | Define `salt` and `nonce`, require raw `tokenData` hash enforcement, and reserve auction `recipient` as zero until ADR 0002 |
| 2026-06-10 02:27 | Address CodeRabbit PR #20 timestamp feedback | Keep durable manager state metadata in sync with the latest PR #20 decision-log entry |
| 2026-06-10 02:31 | Address Claude PR #20 quantity review | Constrain P0 signed drop quantity to one token so the EIP-712 schema matches the one-drop-one-token invariant |
| 2026-06-10 02:33 | Validate Claude PR #20 quantity review fix | Quantity traceability, heading scan, whitespace, `make check`, and Windows wrapper all pass |
| 2026-06-10 02:40 | Merge PR #20 | Final head was CI-clean, CodeRabbit-clean, and visible review threads were resolved |
| 2026-06-10 02:45 | Start auction custody ADR PR | Gate B1 requires accepted auction custody design before custody, settlement, or bid-path rewrites |
| 2026-06-10 02:45 | Create auction follow-up issues | Add canonical issues for `P0-AUCT-ADR` and `P0-AUCT-001`; reuse existing issues for auction reentrancy and payment invariants |
| 2026-06-10 02:49 | Draft auction custody ADR | ADR 0002 chooses explicit escrow custody, canonical auction states, no-bid poster settlement, and pull-payment-compatible settlement |
| 2026-06-10 02:50 | Validate auction custody ADR locally | Heading, traceability, whitespace, `make check`, and Windows wrapper validations pass |
| 2026-06-10 02:52 | Open PR #23 | Auction custody ADR is published with validation evidence and Claude was explicitly pinged in issue comment `4666002050` |
| 2026-06-10 03:03 | Address late Claude PR #20 comments in PR #23 | ADR 0001 now pins `DROP_ID_TYPEHASH` and closes remaining signed-field semantic gaps for payer, sale-mode price fields, and poster attribution |
| 2026-06-10 03:08 | Address Claude PR #23 state-machine review | ADR 0002 now clarifies custody-confirmation trigger and `Created -> Active` derivation |
| 2026-06-10 03:17 | Address Claude PR #23 follow-up review | ADR 0002 now specifies no-bid NFT claim fallback, auction recipient policy, and first-bid cancellation guard |
| 2026-06-10 03:22 | Merge PR #23 | Final head was CI-clean, CodeRabbit-clean, and visible Claude review threads were resolved |
| 2026-06-10 03:25 | Create payment accounting ADR issue | Issue #24 defines the required payment accounting decisions before pull-payment rewrites |
| 2026-06-10 03:32 | Draft payment accounting ADR | ADR 0003 chooses pull-payment accounting, owed-balance totals, surplus-only emergency withdrawal, forced-ETH handling, and payment invariants |
| 2026-06-10 03:38 | Validate payment accounting ADR locally | Heading, traceability, whitespace, `make check`, and Windows wrapper validations pass |
| 2026-06-10 03:42 | Create payment implementation issues | Issues #25 through #31 now track the payment ledger, fixed-price, auction refund, curator claim, withdrawal, and emergency surplus workstreams |
| 2026-06-10 03:44 | Revalidate payment ADR traceability | Staged whitespace, `make check`, and Windows wrapper validations pass after issue-link updates |
| 2026-06-10 03:45 | Open PR #32 | Payment accounting ADR is published with validation evidence |
| 2026-06-10 03:46 | Request Claude review on PR #32 | Explicit review ping added in issue comment `4666247442` because Claude may not run automatically |
| 2026-06-10 03:54 | Mark PR #32 merge-ready | CI passed, CodeRabbit reported no actionable comments, no inline review threads are open, and Claude is unavailable due to organization overage limits |
| 2026-06-10 03:59 | Merge PR #32 | Final head was CI-clean, CodeRabbit-clean, and Claude was externally unavailable due to organization overage limits |
| 2026-06-10 04:01 | Create admin/governance issues | Issues #33 through #35 anchor ADR 0004 plus selector/permission and pause/emergency implementation follow-ups |
| 2026-06-10 04:08 | Draft admin/governance ADR | ADR 0004 accepts Safe-rooted roles, target-scoped selector grants, signer lifecycle controls, domain-specific pause, and surplus-only emergency controls |
| 2026-06-10 04:13 | Validate admin/governance ADR locally | Heading, traceability, whitespace, sidecar review, `make check`, and Windows wrapper validations pass |
| 2026-06-10 04:14 | Open PR #36 | Admin/governance ADR is published with validation evidence and Claude was explicitly pinged in issue comment `4666434728` |
| 2026-06-10 04:20 | Mark PR #36 merge-ready | CI passed, CodeRabbit reported no actionable comments, no inline review threads are open, and Claude is unavailable due to organization overage limits |
| 2026-06-10 04:24 | Merge PR #36 | Final head was CI-clean, CodeRabbit-clean, and Claude was externally unavailable due to organization overage limits |
| 2026-06-10 04:28 | Start randomness ADR PR | Gate B1 requires accepted randomness design before callback, provider, migration, or weak-helper rewrites |
| 2026-06-10 04:30 | Create randomness implementation issues | Issues #37 through #43 anchor callback hardening, lifecycle storage, validation, states, migration, retry, and seed storage workstreams |
| 2026-06-10 04:32 | Draft randomness ADR | ADR 0005 accepts provider-backed async randomness, request lifecycle state, provider epoch validation, weak-helper production disablement, deterministic retry limits, and reserve accounting alignment |
| 2026-06-10 04:39 | Validate randomness ADR locally | Heading, traceability, ASCII, whitespace, sidecar review, `make check`, and Windows wrapper validations pass |
| 2026-06-10 04:42 | Open PR #44 | Randomness ADR is published with validation evidence and Claude was explicitly pinged in issue comment `4666596095` |
| 2026-06-10 04:50 | Merge PR #44 | Final head was CI-clean, CodeRabbit-clean, and Claude was externally unavailable due to organization overage limits |
| 2026-06-10 04:51 | Start metadata/freeze ADR PR | Gate B2 requires accepted metadata/freeze design before schema, freeze, dependency, burn, ERC-4906, and metadata test work |
| 2026-06-10 04:55 | Create metadata/freeze issue set | Issues #45 through #51 anchor ADR 0006 and the schema, freeze, dependency, ERC-4906, burn, and escaping implementation tracks; existing issue #9 remains the P0 dependency encoding blocker |
| 2026-06-10 04:58 | Accept sidecar metadata audit findings | ADR 0006 must explicitly decide on-chain pending metadata, complete freeze boundaries, dependency immutability, burned-token tokenURI behavior, ERC-4906 signaling, and escaping/size limits |
| 2026-06-10 04:59 | Draft metadata/freeze ADR | ADR 0006 accepts schema-versioned metadata, base64 on-chain JSON, explicit pending/final states, immutable freeze manifests, dependency version pinning, ERC-4906 support, and ERC-721 burn semantics |
| 2026-06-10 05:05 | Validate metadata/freeze ADR locally | Heading, traceability, ASCII, whitespace, `make check`, and Windows wrapper validations pass |
| 2026-06-10 05:07 | Open PR #52 | Metadata/freeze ADR is published with validation evidence and Claude was explicitly pinged in issue comment `4666753358` |
| 2026-06-10 05:14 | Address CodeRabbit PR #52 style nitpick | Varied ADR rollout verbs and replaced `very careful` with `rigorous`; whitespace, targeted grep, `make check`, and Windows wrapper validations pass |
| 2026-06-10 05:18 | Address CodeRabbit PR #52 clarity review | ADR now pins freeze-eligible randomness to fulfilled live tokens, defines manifest hash encoding, clarifies burn/ERC-4906 behavior, chooses audit-record post-burn callbacks, delegates concrete size limits to P1-META-006, clarifies generated HTML proofing, and marks Gate B2 in progress |
| 2026-06-10 05:25 | Mark PR #52 merge-ready | CI passed, CodeRabbit reported no actionable comments on final head `4e8cab6d488b0602f6d497090d8106b5eb3e8dfb`, and Claude is unavailable due to organization overage limits |
| 2026-06-10 05:32 | Merge PR #52 | Final head was CI-clean, CodeRabbit-clean, and Claude was externally unavailable due to organization overage limits |
| 2026-06-10 05:34 | Create upgrade/redeployment ADR issue | Issue #53 anchors `P2-UPGRADE-ADR` before Gate B2 can close |
| 2026-06-10 05:36 | Start upgrade/redeployment ADR PR | Gate B2 needs ADR 0007 accepted before deployment, release, manifest, deprecation, emergency redeployment, or proxy policy work |
| 2026-06-10 05:41 | Validate upgrade/redeployment ADR locally | Heading, traceability, ASCII, whitespace, sidecar review, `make check`, and Windows wrapper validations pass |
| 2026-06-10 05:42 | Open PR #54 | Upgrade/redeployment ADR is published with validation evidence |
| 2026-06-10 05:43 | Request Claude review on PR #54 | Explicit review ping added in issue comment `4666936783` because Claude may not run automatically |
| 2026-06-10 05:52 | Merge PR #54 | GitHub CI and CodeRabbit checks passed, no review threads were open, and Claude was externally unavailable due to organization overage limits |
| 2026-06-10 05:56 | Start `P0-AUTH-001` implementation PR | Gate C starts with removing executable `tx.origin` usage and adding explicit recipient target-state tests while leaving EIP-712 work to `P0-AUTH-002` |
| 2026-06-10 06:18 | Open PR #55 | `P0-AUTH-001` implementation is published with local build, test, formatting, whitespace, grep, and sidecar-review evidence |
| 2026-06-10 06:19 | Request Claude review on PR #55 | Explicit review ping added in issue comment `4667155915` because Claude may not run automatically |
| 2026-06-10 06:33 | Address CodeRabbit PR #55 review | Use concrete PR state in the durable log and reject zero-poster drop execution so payout and no-bid fallback addresses are never zero |
| 2026-06-10 06:46 | Merge PR #55 | Final head was CI-clean and CodeRabbit-clean; Claude was externally unavailable due to organization overage limits |
| 2026-06-10 06:48 | Start `P0-AUTH-002` implementation PR | Gate C next removes packed drop authorization and adds replay-safe EIP-712 typed authorization |
| 2026-06-10 06:54 | Stage ERC-1271 separately | `P0-AUTH-002` implements EOA/EIP-2098 authorization now and explicitly rejects contract signers until `P0-AUTH-003` lands |
| 2026-06-10 07:01 | Validate focused EIP-712 suite | EOA, EIP-2098, explicit digest encoding, wrong signer/domain/chain, expiry, cancellation, stale epoch, replay, malleability, zero signer, bad quantity, bad payer, and contract-signer rejection tests pass |
| 2026-06-10 07:09 | Finish local `P0-AUTH-002` validation | `make check`, Windows check, formatting, whitespace, legacy-surface grep, heading scan, and targeted Slither delta checks pass; Slither still exits non-zero for unrelated baseline findings |
| 2026-06-10 07:11 | Open PR #56 | EIP-712 drop authorization implementation is published with local validation and Slither delta evidence |
| 2026-06-10 07:12 | Request Claude review on PR #56 | Explicit review ping added in issue comment `4667572552` because Claude may not run automatically |
| 2026-06-10 07:30 | Nudge CodeRabbit PR #56 | CodeRabbit had remained pending since PR open; issue comment `4667699009` requested completion for the latest head |
| 2026-06-10 07:34 | Address CodeRabbit PR #56 command review | Added duplicate-cancel guard, sale-mode negative tests, and lifecycle event assertions; focused suite, full `make check`, and Windows wrapper pass |
| 2026-06-10 07:45 | Merge PR #56 | Final head was CI-clean and CodeRabbit-clean; Claude was externally unavailable due to organization overage limits |
| 2026-06-10 07:47 | Start `P0-AUTH-003` implementation PR | EIP-712 is merged, so Gate C can add ERC-1271 contract signer validation against the same typed-data digest |
| 2026-06-10 07:55 | Finish local `P0-AUTH-003` validation | ERC-1271 exact-magic staticcall validation, fail-closed malformed returns, contract-signer tests, docs, roadmap, full `make check`, and Windows wrapper all pass locally |
| 2026-06-10 07:57 | Open PR #57 | ERC-1271 drop authorization implementation is published with local validation evidence |
| 2026-06-10 07:58 | Request Claude review on PR #57 | Explicit review ping added in issue comment `4667907301` because Claude may not run automatically |
| 2026-06-10 08:13 | Merge PR #57 | CI passed, CodeRabbit review evidence was clean despite stale pending status, the stale-status exception was documented, and Claude was unavailable due to organization overage limits |
| 2026-06-10 08:18 | Start `P0-AUCT-002` implementation PR | Gate C next fixes the high-impact auction bid-path reentrancy/refund issue by converting outbid refunds to bidder pull credits |
| 2026-06-10 08:28 | Validate focused auction payment suite | Bid/outbid pull credits, rejecting previous bidder, failed withdrawal preservation, withdrawal reentrancy, bid thresholds, emergency escrow/surplus boundaries, and settlement replay tests pass |
| 2026-06-10 08:36 | Finish local `P0-AUCT-002` validation | Full `make check` and Windows wrapper pass with 69 tests; format, whitespace, heading scan, and Slither delta evidence pass; Slither remains non-zero for unrelated baseline findings |
| 2026-06-10 08:38 | Open PR #58 | Auction pull-credit implementation is published with local validation and Slither delta evidence |
| 2026-06-10 08:38 | Request Claude review on PR #58 | Explicit review ping added in issue comment `4668219408` because Claude may not run automatically |
| 2026-06-10 08:45 | Merge PR #58 | CI passed, CodeRabbit review evidence was clean despite stale pending status, the stale-status exception was documented, and Claude was unavailable due to organization overage limits |
| 2026-06-10 08:46 | Start `P0-AUCT-001` implementation PR | Gate C next formalizes auction custody/state-machine semantics now that bid/outbid refunds use pull credits |
| 2026-06-10 09:02 | Include auction-local final proceeds credits in `P0-AUCT-001` | ADR 0002 rejects synchronous final payout calls in auction settlement; this PR can satisfy that without claiming full ADR 0003 completion |
| 2026-06-10 09:05 | Validate focused auction custody/payment suites | Explicit escrow custody, status derivation, no-bid pending claims, failed NFT transfer, cancellation, proceeds-credit withdrawal failure, and PR #58 bidder-credit regressions pass locally |
| 2026-06-10 09:16 | Finish local `P0-AUCT-001` validation | Full `make check` and Windows wrapper pass with 80 tests; format, whitespace, heading/traceability scans, and Slither delta evidence pass; Slither remains non-zero for unrelated baseline findings |
| 2026-06-10 09:22 | Open PR #59 | Auction custody/state-machine implementation is published with local validation and Slither delta evidence |
| 2026-06-10 09:23 | Request Claude review on PR #59 | Explicit review ping added in issue comment `4668570581` because Claude may not run automatically |
| 2026-06-10 09:39 | Address CodeRabbit PR #59 review | Add no-bid pending-claim rollback coverage, proceeds rounding coverage, forced-ETH accounting coverage, docs clarifications, auction interface validation, token ID storage, and zero-address proceeds-recipient guards |
| 2026-06-10 09:46 | Validate PR #59 review fixes locally | Focused 35-test suite, full 85-test `make check`, Windows wrapper, formatting, and Slither delta evidence pass; Slither remains non-zero for baseline findings plus intentional test-only `ForceEth` selfdestruct helper |
| 2026-06-10 09:50 | Merge PR #59 | CI passed, CodeRabbit review evidence was clean despite stale pending status, the stale-status exception was documented, and Claude was unavailable due to organization overage limits |
| 2026-06-10 09:53 | Close issue #28 | PR #58 fixed auction outbid refunds and PR #59 preserved the bidder-credit behavior while completing auction custody/settlement |
| 2026-06-10 09:56 | Start `P0-PAY-003` implementation PR | Gate C next removes fixed-price mint-path ETH push payouts by recording `StreamDrops` poster, protocol, and curator-reserve credits |
| 2026-06-10 10:00 | Confirm Claude per-PR operating rule | User noted Claude may not run automatically, so each PR must receive an explicit Claude review request after opening |
| 2026-06-10 10:10 | Implement fixed-price pull credits locally | `StreamDrops` records fixed-price credits, exposes fixed-price owed/surplus views, adds guarded poster/protocol withdrawal, keeps curator reserve non-withdrawable pending curator-claim work, and focused 12-test suite passes |
| 2026-06-10 10:14 | Finish local `P0-PAY-003` validation | Focused 33-test suite, full 97-test `make check`, Windows wrapper, formatting, whitespace, docs heading scans, and Slither delta evidence pass; Slither remains non-zero for known baseline findings plus intentional test-only forced-ETH helpers |
| 2026-06-10 10:17 | Open PR #60 | Fixed-price pull-credit implementation is published with local validation and Slither delta evidence |
| 2026-06-10 10:18 | Request Claude review on PR #60 | Explicit review ping added in issue comment `4669058148` because Claude may not run automatically |
| 2026-06-10 10:23 | Nudge CodeRabbit PR #60 | CodeRabbit status remained pending after CI passed; issue comment `4669093106` requested latest-head review |
| 2026-06-10 10:26 | Address CodeRabbit PR #60 nitpick | Documented intentional Solidity 0.8.19 `selfdestruct` usage in the forced-ETH test helper and reran focused fixed-price validation |
| 2026-06-10 10:31 | Document PR #60 merge decision | CI passed on review-fix head, Claude was unavailable due to organization overage, CodeRabbit's only finding was addressed, no inline threads are open, and stale CodeRabbit status is documented in issue comment `4669162764` |
| 2026-06-10 10:33 | Merge PR #60 | Fixed-price pull credits merged as `f7390f28c48f833a75e28a87995f24df27e152c3` and issue #27 closed completed |
| 2026-06-10 10:35 | Start `P0-PAY-005` implementation PR | Gate C payment work continues by converting `StreamCuratorsPool.claimRewards` from synchronous reward payout to curator pull credits |
| 2026-06-10 10:53 | Finish local `P0-PAY-005` validation | Curator reward claims now use pull credits, rejecting reward addresses cannot block claims, withdrawal/reentrancy/emergency-surplus tests pass, full 109-test checks pass, and Slither no longer reports `StreamCuratorsPool` in `arbitrary-send-eth` |
| 2026-06-10 10:55 | Open PR #61 and request Claude review | Curator reward claim credit implementation is published, and Claude review was explicitly requested in issue comment `4669369055` |
| 2026-06-10 11:11 | Merge PR #61 | Curator reward claim credits merged as `51db3fd936b1ed7077fe5a7d033037581b9b4997`, issue #29 closed completed, and stale CodeRabbit status was documented before merge |
| 2026-06-10 11:11 | Select Queue Item 21 | Remaining `arbitrary-send-eth` findings are now limited to `StreamMinter` and `NextGenRandomizerRNG`, so the next PR will bound their emergency-withdrawal behavior and update Slither traceability |
| 2026-06-10 11:30 | Implement Queue Item 21 locally | `StreamMinter` is modeled as zero-owed surplus-only custody, `NextGenRandomizerRNG` is conservatively modeled as all-balance randomness reserve, and auction emergency withdrawal no longer uses the strict zero-balance equality |
| 2026-06-10 11:30 | Finish local Queue Item 21 validation | Focused emergency/auction tests, full `make check`, Windows wrapper, new test formatting, whitespace, and Slither delta evidence pass; Slither now reports zero `arbitrary-send-eth` findings |
| 2026-06-10 11:51 | Merge PR #62 | Emergency-withdrawal bounds merged as `44a3ebb5b298b437387c056a0c86b1d7ee9db03d`; CI and CodeRabbit were green, Claude was unavailable due org overage, and issue #31 closed completed |
| 2026-06-10 11:52 | Select Queue Item 22 | Next P0 Gate C blocker is `P0-ADMIN-001`, because admin selector/target permission semantics must be fixed before pause controls and deeper randomness/admin work |
| 2026-06-10 12:09 | Finish local Queue Item 22 validation | Focused 18-test admin suite, full 129-test `make check`, Windows wrapper, formatting, whitespace, heading scans, and Slither delta evidence pass; Slither reports no `StreamAdmins` high/medium or zero-check findings |
| 2026-06-10 12:13 | Open PR #63 | Admin permission scoping implementation is published with local validation and Slither delta evidence |
| 2026-06-10 12:21 | Address CodeRabbit PR #63 review | Added signer registrar/global-admin asymmetry coverage, triaged the low-impact Slither delta, removed a no-op test prank, and reran focused/full/Windows/Slither validation |
| 2026-06-10 12:34 | Address CodeRabbit PR #63 second review | Updated the durable run timestamp, added explicit `StreamMinter.mint` batch guards and revert tests, reran focused/full/Windows validation, and confirmed Slither stayed at 648 findings with no minter-test `unused-return` delta |
| 2026-06-10 12:46 | Merge PR #63 | Admin permission scoping merged as `12f5f461a3ff784287f650b69efbdc0bbe6e0429`; CI passed, CodeRabbit inline threads were resolved, stale aggregate status was documented, Claude was unavailable due org overage, and issue #34 should close completed |
| 2026-06-10 12:46 | Select Queue Item 23 | Next P0 Gate C blocker is `P0-ADMIN-002`, because accepted pause domains and withdrawal/emergency policy need executable controls before deeper randomness/admin release work |
| 2026-06-10 12:57 | Implement Queue Item 23 locally | Domain pause state, pause/unpause authority separation, operational guards, no-withdrawal-pause policy tests, explicit emergency recipient routing, docs, and roadmap traceability are in place; focused pause/emergency and expanded admin/payment suites pass locally |
| 2026-06-10 13:08 | Finish local Queue Item 23 validation | Full `make check`, Windows wrapper, formatting, whitespace, heading scan, and Slither delta evidence pass; Slither final JSON has 676 findings with unchanged 9 High / 29 Medium totals and zero `arbitrary-send-eth` findings |
| 2026-06-10 13:12 | Open PR #64 | Pause/emergency-controls implementation is published, Claude review requested in issue comment `4670568701`, and CodeRabbit latest-head review requested in issue comment `4670570080` |
| 2026-06-10 13:23 | Merge PR #64 | Pause/emergency controls merged as `4e73435d59dba9bcca05a10ad18a529c53489c75`; CI passed, no review threads were open, Claude was unavailable due org overage, CodeRabbit's aggregate status was stale after producing release notes, and issue #35 closed completed |
| 2026-06-10 13:26 | Select Queue Item 24 | Next P0 Gate C blocker is `P0-RAND-001`, because current randomizer callbacks still lack explicit request lifecycle, provider/epoch validation, and stale/duplicate callback rejection |
| 2026-06-10 13:48 | Implement Queue Item 24 local draft | Added shared randomizer lifecycle storage, collection randomizer epochs, VRF/arRNG callback validation, wrong-collection checks, manual stale marking, `RandomizerNXT` production-disablement, docs, and focused lifecycle tests |
| 2026-06-10 13:55 | Finish local Queue Item 24 validation on pre-review head | Full `make check` and Windows wrapper pass with 151 tests; formatting, whitespace, heading scan, traceability grep, and Slither delta evidence pass; Slither final JSON has 686 findings with unchanged 9 High / 29 Medium totals, two existing `weak-prng` rows, and no randomizer reentrancy delta |
| 2026-06-10 14:00 | Open PR #65 | Randomizer request lifecycle hardening implementation is published, Claude review requested in issue comment `4671046189`, and CodeRabbit latest-head review requested in issue comment `4671047964` |
| 2026-06-10 14:15 | Address CodeRabbit PR #65 follow-up | Added lifecycle invariant comments, direct arRNG request precondition commentary, zero request ID regression coverage, and updated roadmap/test/run-state traceability; focused suite and full `make check`/Windows wrapper pass with 152 tests |
| 2026-06-10 14:24 | Merge PR #65 | Randomizer lifecycle hardening merged as `9bf44c1e292e891f01fa4a7bc27373032e9beaaf`; CI passed, CodeRabbit was green/LGTM, Claude was unavailable due org overage, issue #37 closed completed, and issue #39 was closed with evidence |
| 2026-06-10 14:25 | Select Queue Item 25 | Next P0 randomness child is `P0-RAND-002`; token-level lifecycle views should be explicit before moving into failed-state/retry/metadata work |
| 2026-06-10 14:34 | Validate Queue Item 25 | Token-level randomizer lifecycle views are locally green across focused tests, `make check`, Windows wrapper, formatting, diff hygiene, docs traceability, and Slither baseline comparison |
| 2026-06-10 14:38 | Open PR #66 | Token-level randomizer lifecycle views are published in `https://github.com/6529-Collections/6529Stream/pull/66`; Claude review requested in issue comment `4671390449` and CodeRabbit latest-head review requested in issue comment `4671390698` |
| 2026-06-10 14:47 | Address CodeRabbit PR #66 follow-up | CodeRabbit reported LGTM in issue comment `4671424817` and suggested token-level `Stale` coverage; follow-up extends the stale request test, updates docs/roadmap traceability, and passes focused tests, `make check`, Windows wrapper, formatting, and diff hygiene |
| 2026-06-10 14:52 | Merge PR #66 | Token-level randomizer lifecycle views merged as `1b5c14c802f2c10870f8ee7c089164372d393b54`; CI passed, CodeRabbit reported LGTM on the final head, Claude was unavailable due org overage, and issue #38 closed completed |
| 2026-06-10 15:04 | Start Queue Item 26 | Next P0 randomness child is `P0-RAND-005`; ADR 0005's conservative default is to block lifecycle-aware provider migration while requests are pending |
| 2026-06-10 15:14 | Validate Queue Item 26 | Randomizer pending-migration guard is locally green across focused tests, `make check`, Windows wrapper, formatting, whitespace, docs traceability, heading scans, and Slither baseline comparison |
| 2026-06-10 15:17 | Open PR #67 | Pending randomizer migration guard published at `https://github.com/6529-Collections/6529Stream/pull/67` from head `ecd8810c19ba2e1d80bebae108d318add4ad1fc9` |
| 2026-06-10 15:20 | Request PR #67 bot reviews | Claude requested in issue comment `4671747961`; CodeRabbit requested in issue comment `4671749578` |
| 2026-06-10 15:29 | Merge PR #67 | Pending randomizer migration guard merged as `428cbc8213c344b219e746b47f089b1b75730bfb`; CI passed, CodeRabbit resolved to success with `Review skipped`, Claude was unavailable due org overage, and issue #41 closed completed |
| 2026-06-10 15:33 | Start Queue Item 27 | Next randomness blocker is `P0-RAND-004`; failed post-processing state should become observable before retry semantics in `P0-RAND-006` |
| 2026-06-10 15:48 | Validate Queue Item 27 | Failed post-processing state is locally green across focused VRF/arRNG lifecycle tests, full `make check`, Windows wrapper, formatting, whitespace, docs traceability, heading scans, and Slither baseline comparison |
| 2026-06-10 15:48 | Reconfirm Claude manual trigger | User noted Claude may not run automatically and pointed back to PR #3; every new PR must receive an explicit `@claude review` issue comment before waiting on bot feedback |
| 2026-06-10 15:53 | Open PR #68 and request bot reviews | Failed randomness post-processing state PR published at `https://github.com/6529-Collections/6529Stream/pull/68`; Claude requested in issue comment `4671968774` and CodeRabbit requested in issue comment `4671968843` |
| 2026-06-10 16:04 | Address CodeRabbit PR #68 event-context review | Add provider and randomizer epoch to `RandomnessPostProcessingFailed`, update tests/docs/run-state traceability, and proceed with CodeRabbit/CI as sufficient for this PR per user instruction |
| 2026-06-10 16:07 | Validate CodeRabbit PR #68 review fix | Focused lifecycle tests, full `make check`, Windows wrapper, formatting, whitespace, docs traceability, heading scan, and Slither baseline comparison all pass after adding provider/epoch event context |
| 2026-06-10 16:16 | Address final CodeRabbit PR #68 mock nitpick | Align `MockRandomizerCore.setTokenHash` with production caller/overwrite guards and rerun focused lifecycle tests, `make check`, Windows wrapper, formatting, and whitespace checks |
| 2026-06-10 16:20 | Merge PR #68 | Final head was CI-clean, CodeRabbit reported no actionable comments, Claude was not required for this PR per user instruction, and issue #40 closed completed |
| 2026-06-10 16:21 | Select Queue Item 28 | Next randomness blocker is `P0-RAND-006`; retry should reuse the accepted derived seed and avoid new provider output |
| 2026-06-10 16:31 | Implement Queue Item 28 local draft | Added admin-gated VRF/arRNG `retryRandomnessPostProcessing`, lifecycle retry count/limit/events/errors, focused retry tests, and docs/roadmap/run-state traceability |
| 2026-06-10 16:39 | Validate Queue Item 28 locally | Full `make check`, Windows wrapper, focused retry/lifecycle tests, formatting, diff hygiene, traceability, heading scan, and Slither comparison all passed with high/medium counts unchanged |
| 2026-06-10 16:43 | Expand Queue Item 28 retry validation | Added explicit retry rejection tests for changed randomizer epoch and provider, refreshed full gates to 168 passing tests, and kept Slither high/medium counts unchanged |
| 2026-06-10 16:45 | Open PR #69 | PR packages bounded deterministic post-processing retry for VRF and arRNG adapters, closes issue #42, and records full local validation evidence |
| 2026-06-10 16:59 | Address CodeRabbit PR #69 review | Split retry-failure state mutation from initial-failure event emission, refresh fulfillment timing on retry success, add arRNG edge-case parity, and refresh full gates to 170 passing tests with Slither high/medium counts unchanged |
| 2026-06-10 17:08 | Address CodeRabbit PR #69 roadmap wording review | Remove stale top-level `deterministic randomness retry` remaining-blocker wording now that P0-RAND-006 is implemented and passing in the traceability matrix |
| 2026-06-10 17:15 | Merge PR #69 | CI passed, CodeRabbit confirmed the event refactor and roadmap wording fix, final status was clean, and issue #42 closed completed |
| 2026-06-10 17:21 | Select Queue Item 29 | Next randomness blocker is `P0-RAND-007`; ADR 0005 requires explicit raw-output hash exposure alongside the stored derived seed without retaining full provider words |
| 2026-06-10 17:39 | Implement Queue Item 29 local draft | Store canonical raw-output hashes, derive seeds from raw-output hash plus request-bound fields, emit raw-output hash in fulfillment/failure/retry events, and add focused lifecycle/retry coverage |
| 2026-06-10 17:43 | Align Queue Item 29 with ADR event and seed shape | Add `RANDOMNESS_SEED_TYPEHASH` domain separation and provider/epoch context to fulfillment events before opening the PR |
| 2026-06-10 17:45 | Validate Queue Item 29 locally | Focused lifecycle/retry suites, full `make check`, Windows wrapper, formatting, diff hygiene, traceability, heading scan, and Slither baseline comparison all pass with 171 total tests and unchanged high/medium counts |
| 2026-06-10 17:45 | Use CodeRabbit-only review path for Queue Item 29 | Latest user instruction says Claude is not needed and CodeRabbit is fine, so this PR will request CodeRabbit explicitly and skip Claude unless risk or new instructions change |
| 2026-06-10 17:46 | Open PR #70 | PR packages P0-RAND-007 raw-output hash storage, domain-separated seed derivation, event/view exposure, focused tests, full local validation evidence, and a CodeRabbit review request |
| 2026-06-10 17:52 | Address CodeRabbit PR #70 review | Add lifecycle interface request views, arRNG provider raw-word fulfillment event, stale zero-hash coverage, monotonic log helpers, retry-event documentation, and a defense-in-depth seed guard comment |
| 2026-06-10 17:56 | Validate CodeRabbit PR #70 review response | Focused lifecycle/retry suites, full `make check`, Windows wrapper, formatting, diff hygiene, traceability, heading scan, and Slither baseline comparison all pass with 171 tests and unchanged high/medium counts |
| 2026-06-10 17:58 | Mark PR #70 merge-ready by review evidence | GitHub CI passed on head `f8d0470b665eee2b528f95c380719014be639295`, CodeRabbit comment `4672884249` verified the fixes and marked the PR clean, and the stale aggregate pending context is documented as non-blocking |
| 2026-06-10 18:02 | Merge PR #70 | Raw-output hash storage merged as `350667fff6472e938790f0c7db5895fc3c4ddee9`; CI passed on final head `f52cd8f3cf83a8c131bdbc233c4769a4ba72e3fb`, CodeRabbit final clean comment `4672928268`, and issue #43 closed completed |
| 2026-06-10 18:05 | Select Queue Item 30 | Next open P0 Slither blocker is `P0-META-001`, a focused dependency-script `encode-packed-collision` fix with clear tests and low coupling to later metadata/freeze work |
| 2026-06-10 18:11 | Implement Queue Item 30 local draft | Added typed dependency chunk/content hashes, initialized `StreamCore` dependency script rendering, focused ambiguous-boundary tests, and Slither delta evidence showing `encode-packed-collision=0` |
| 2026-06-10 18:18 | Validate Queue Item 30 locally | Focused metadata tests, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and final Slither confirmation pass with 173 tests and `encode-packed-collision=0` |
| 2026-06-10 18:20 | Open PR #71 | Dependency-script encoding hash fix published with full local validation evidence; CodeRabbit review will be requested on the PR-state head |
| 2026-06-10 18:21 | Request CodeRabbit PR #71 review | CodeRabbit review requested in issue comment `4673145958`; Claude intentionally skipped per current user instruction |
| 2026-06-10 18:27 | Address CodeRabbit PR #71 non-blocking observations | Added NatSpec for the new hash views, added zero-chunk dependency hash coverage, refreshed focused/full/Windows/Slither validation, and kept Slither counts unchanged |
| 2026-06-10 18:33 | Merge PR #71 | Dependency-script encoding hashes merged as `20bd9d9d1fa36b7142f3a81b9ab0c86060c9f943`; CI passed on final head `1668c6ee9c45aca9193a48ae9b56eb81b5c02583`, CodeRabbit final clean comment `4673227541`, and issue #9 closed completed |
| 2026-06-10 18:35 | Select Queue Item 31 | Next focused P0 Slither blocker is `P0-CORE-001`, because `StreamCore` exposes two never-written public/allowlist mint counters that Slither reports as high-impact uninitialized state |
| 2026-06-10 18:38 | Implement Queue Item 31 local draft | Removed the dead public/allowlist mint-count mappings and views, preserved the retained airdrop counter, and added focused retained-counter regressions |
| 2026-06-10 18:39 | Validate Queue Item 31 Slither delta | Slither now reports `uninitialized_state=0`, total findings `680`, and High findings `6`; the remaining High rows are weak helper randomness, vendored math, and accepted test-only forced-ETH helpers |
| 2026-06-10 18:43 | Finish local Queue Item 31 validation | Focused accounting tests, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither confirmation all pass with 176 total tests |
| 2026-06-10 18:45 | Open PR #72 and request CodeRabbit | PR #72 packages `P0-CORE-001`; CodeRabbit review requested in issue comment `4673355477`, and Claude is skipped per current user instruction |
| 2026-06-10 18:54 | Merge PR #72 | Dead mint-accounting state merged as `ba2f0cd483bd178f801250ee6ef842ff3a4e77a5`; CI passed on final head `a0c6830862719861648697d722027b40c2090401`, CodeRabbit final clean comment `4673355663`, and issue #13 closed completed |
| 2026-06-10 18:57 | Select Queue Item 32 | Next focused P0 Slither blocker is weak helper randomness because deleting the concrete `XRandoms` helper can reduce first-party production `weak-prng` findings to zero |
| 2026-06-10 18:57 | Create issue #73 | Issue #14 was already closed for ADR acceptance, so `P0-RAND-008` now tracks the concrete `XRandoms` removal implementation |
| 2026-06-10 19:03 | Implement Queue Item 32 local draft | Deleted `smart-contracts/XRandoms.sol`, kept `IXRandoms` and the inline `MockXRandoms` regression, and updated Slither/roadmap/status/ADR/test traceability for `weak-prng=0` |
| 2026-06-10 19:09 | Finish local Queue Item 32 validation | Focused production-scope regression, full `make check`, Windows wrapper, targeted formatting, whitespace, heading scan, traceability grep, and Slither confirmation all pass; Slither final JSON has `weak_prng=0`, `total=676`, `high=4`, and `medium=28` |
| 2026-06-10 19:18 | Merge PR #74 | Weak helper randomness removal merged as `8ced3efa316211fa634187c596d3db64e0b4c665`; CI passed on final head `4ce60549922db5b223597be7c69ff0e94b3b3af5`, CodeRabbit final clean comment `4673579305`, and issue #73 closed completed |
| 2026-06-10 19:20 | Select Queue Item 33 | Next focused P0 Slither blocker is `P0-INIT-001`, because explicit local initialization can eliminate remaining first-party production `uninitialized-local` rows while preserving behavior |
| 2026-06-10 19:25 | Implement Queue Item 33 local draft | Initialized remaining first-party production locals explicitly, added `StreamInitialization.t.sol`, and refreshed Slither/roadmap/status/test traceability; Slither now reports one accepted test-only `uninitialized-local` row, `total=666`, `high=4`, and `medium=19` |
| 2026-06-10 19:30 | Finish local Queue Item 33 validation | Focused initialization tests, full `make check`, Windows wrapper, targeted formatting, whitespace, heading scan, traceability grep, and Slither confirmation all pass; Slither final JSON has `uninitialized_local=1` test-only, `total=666`, `high=4`, and `medium=19` |
| 2026-06-10 19:46 | Merge PR #75 | First-party production uninitialized locals merged as `f042b14a43ed427fa57567d8d58a65ca2851e382`; issue #15 closed completed after CI and CodeRabbit were green |
| 2026-06-10 19:48 | Select Queue Item 34 | The only remaining non-test high/medium Slither rows are vendored OpenZeppelin utility-library findings owned by `P0-LIB-001` |
| 2026-06-10 19:55 | Implement Queue Item 34 local draft | Added vendored-library provenance docs, Base64/Math regressions, `Strings.sol` header correction, and Slither/roadmap/status/test traceability for false-positive disposition |
| 2026-06-10 20:01 | Finish local Queue Item 34 validation | Focused vendored tests, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither confirmation all pass; high/medium Slither counts remain `4 High / 19 Medium` and vendored rows are documented false positives |
| 2026-06-10 20:18 | Merge PR #76 | Vendored-library provenance merged as `4f1e69a44327017697204bf44b5b14a3f5bd2fd3`; CI and CodeRabbit were green, and issue #11 closed completed |
| 2026-06-10 20:22 | Select Queue Item 35 | P0-PAY-008 remains open for executable payment invariants after emergency-withdraw and local pull-payment work landed |
| 2026-06-10 20:27 | Implement Queue Item 35 local draft | Added a bounded payment sequence fuzz invariant harness covering local ledgers, owed totals, reserves, withdrawals, emergency surplus, randomizer reserves, and forced-balance surplus |
| 2026-06-10 20:40 | Finish local Queue Item 35 validation | Focused payment invariant fuzzing, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither confirmation all pass; Slither high/medium remain `4 High / 19 Medium` with the updated total at 693 findings |
| 2026-06-10 20:42 | Open PR #77 and request CodeRabbit | Payment invariant baseline published at `https://github.com/6529-Collections/6529Stream/pull/77`; CodeRabbit review requested in issue comment `4674282933`, and Claude is skipped per current user instruction |
| 2026-06-10 20:57 | Merge PR #77 | Payment invariant baseline merged as `9f2337009114fc4263bc88bc2f26f220d17c91fc`; CI and CodeRabbit were green, all visible review threads were resolved, and issue #8 closed completed |
| 2026-06-10 21:02 | Select Queue Item 36 | The remaining P0-PAY-002 view-surface issue can be closed conservatively by exposing ADR 0003 local-ledger aliases and asserting them in the bounded payment invariant, without introducing a riskier shared storage abstraction |
| 2026-06-10 21:12 | Open PR #78 and request CodeRabbit | Payment ledger view aliases published at `https://github.com/6529-Collections/6529Stream/pull/78`; CodeRabbit review requested in issue comment `4674566512`, and Claude remains skipped per current user instruction |
| 2026-06-10 21:21 | Apply PR #78 CodeRabbit nitpick | CodeRabbit status was green and CI run `27306718755` passed; the only review note was to replace the run-state section header's `PR TBD` placeholder with concrete PR `#78` |
| 2026-06-10 21:25 | Merge PR #78 | Payment ledger view aliases merged as `785f9ebca5c91a18e0cdbe20b35a8b0c955bfb3f`; CI and CodeRabbit were green, the visible review nitpick was fixed, and issue #26 closed completed |
| 2026-06-10 21:27 | Create issue #79 and select Queue Item 37 | The remaining signer-lifecycle test-matrix row is `In Progress`; a focused P0-ADMIN-003 issue lets the next PR separate drop-signing identity from signer-management authority without bundling deployment ceremony work |
| 2026-06-10 21:53 | Finish local Queue Item 37 validation | Signer-manager implementation with owner-approved lifecycle targets, focused 59-test admin/drop coverage, full 197-test `make check`, Windows wrapper, formatting, whitespace, traceability grep, and Slither baseline comparison all pass; Slither high/medium counts remain unchanged at 4 High / 19 Medium |
| 2026-06-10 21:57 | Open PR #80 | Signer lifecycle manager PR opened on head `8aab8a4cfa0442afcb6933c5ec11516a25d5a005`; CodeRabbit requested in issue comment `4675002714`; Claude intentionally skipped per current user instruction |
| 2026-06-10 22:08 | Merge PR #80 | CI passed on final head `d4a13a19c19a5f609ea75a308f6defdf17c019e5`, CodeRabbit status was green with no actionable comments, merge commit is `9c81f71c59357dd124d3513ca6a006ceeba9ad55`, and issue #79 closed completed |
| 2026-06-10 22:10 | Select Queue Item 38 | Next Gate D gap is P1-META-001 metadata schema and golden-file coverage because pending/final/on-chain metadata fixtures remain missing while the randomness and payment foundations are now in place |
| 2026-06-10 22:22 | Finish local Queue Item 38 validation | Metadata golden fixtures now lock current off-chain pending/final and current on-chain pending/final outputs; focused tests, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither baseline comparison all pass; Slither remains at 721 total findings with unchanged 4 High / 19 Medium counts |
| 2026-06-10 22:25 | Open PR #81 | Metadata golden baseline PR opened on head `a2218e110ff5886dd94db74ead3986afcfcad0d6`; CodeRabbit requested in issue comment `4675228562`; Claude intentionally skipped per current user instruction |
| 2026-06-10 22:31 | Apply PR #81 CodeRabbit guard fix | CodeRabbit comment `4675250990` correctly noted that the final metadata golden tests should prove they are exercising a fulfilled hash state; added explicit nonzero-hash guards and reran focused metadata tests, `make check`, Windows wrapper, and Slither baseline comparison |
| 2026-06-10 22:35 | Apply PR #81 CodeRabbit nitpicks | Accepted low-cost follow-ups by documenting raw `collectionBaseURI` URI concatenation, making the Queue Item 38 status explicitly reference PR #81 and branch `codex/metadata-golden-tests`, and noting that `NoopRandomizer` comes from `MockRandomizer.sol` |
| 2026-06-10 22:40 | Merge PR #81 | CI run `27310936726` passed, CodeRabbit explicitly reported no further concerns in comment `4675354682`, visible review threads were resolved, merge commit is `2b2dbab92c2f4833a8b2e6fff84638ea52edda63`, and issue #46 remains open for final schema-versioned metadata work |
| 2026-06-10 22:47 | Select Queue Item 39 | Next Gate D gap is P1-META-004 because current metadata can change after mint but `StreamCore` still lacks ERC-4906 interface support and update events for indexers |
| 2026-06-10 22:47 | Implement Queue Item 39 local draft | Added ERC-4906 interface support, token and collection metadata update events, focused event tests, and docs/roadmap/run-state traceability; dependency registry content reverse signaling remains scoped to P1-META-003 |
| 2026-06-10 22:58 | Finish local Queue Item 39 validation | Focused ERC-4906 event tests, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither baseline comparison all pass; Slither remains at 721 total findings with unchanged 4 High / 19 Medium counts and zero `StreamMetadataEvents` reentrancy-event rows |
| 2026-06-10 23:02 | Open PR #82 | ERC-4906 metadata update event PR opened on head `96052819e2cfd5d6f53c4793af03baaadda2ad00`; CodeRabbit requested in issue comment `4675495632`; Claude intentionally skipped per current user instruction |

## Resume Instructions

If this thread resumes after compaction:

1. Read `ops/AUTONOMOUS_RUN.md`.
2. Read `ops/ROADMAP.md`.
3. Run `git status --short`.
4. Continue the current PR worklog item.
5. If a PR is open, fetch PR comments/checks and resolve them before starting
   the next PR.
6. If no PR is open, continue the next item in `PR Queue`.
