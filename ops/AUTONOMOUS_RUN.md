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
  after opening. Do not request Claude review unless a future user instruction
  explicitly asks for it.
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
| Active PR branch | `codex/release-evidence-label-drift` |
| Last merged PR | `https://github.com/6529-Collections/6529Stream/pull/238` |
| Active issue | `https://github.com/6529-Collections/6529Stream/issues/239` |
| Active PR | `https://github.com/6529-Collections/6529Stream/pull/240` |
| Next issue | After issue #239, continue Gate G no-secret release-evidence tracker hardening before attempting retained external evidence tasks |
| Roadmap file | `ops/ROADMAP.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-06-13 14:20 UTC` |

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
| 39 | Add ERC-4906 metadata update signaling | Gate D | Implement P1-META-004 for `StreamCore`: interface support, token-level and collection-range metadata update events, no misleading mint/burn-only events, docs, and roadmap/test traceability | Merged in PR #82 |
| 40 | Add schema-v1 metadata state outputs | Gate D | Continue P1-META-001 by adding schema-versioned on-chain base64 JSON, explicit pending/final metadata state views, golden fixtures, docs, and roadmap/test traceability | Merged in PR #83 |
| 41 | Add collection freeze manifests and guards | Gate D | Implement the first P1-META-002 slice: deterministic freeze manifest hash/event/views, terminal-randomness freeze eligibility, final-supply freeze boundary, post-freeze guards for current StreamCore metadata-significant paths, tests, docs, and roadmap traceability | Merged in PR #84 |
| 42 | Add dependency version immutability | Gate D | Implement P1-META-003 dependency registry version records, content-hash/provenance views, deprecation events, collection dependency pinning, frozen-output stability tests, docs, and roadmap traceability | Merged in PR #85 |
| 43 | Add burn metadata semantics | Gate D | Implement P1-META-005 retained burned-token audit state, protocol burn event, callback-after-burn audit events, freeze-safe post-burn fulfillment, tests, docs, and roadmap traceability | Merged in PR #86 |
| 44 | Add metadata escaping and render-safety baseline | Gate D | Implement the first P1-META-006 slice for JSON escaping, generated metadata/parser tests, render-safety docs, and roadmap/test traceability | Merged in PR #87 |
| 45 | Add animation HTML wrapper safety | Gate D | Continue P1-META-006 by hardening generated animation HTML/script boundaries, dependency-script JavaScript-string embedding, hostile `tokenData` handling, tests, docs, and roadmap traceability | Merged in PR #88 |
| 46 | Reduce `StreamCore` deployment size | Gate E | Start P1-DEPLOY-001 by measuring the EIP-170 blocker, extracting pure metadata rendering/escaping code behind a stable library boundary where safe, preserving metadata behavior, and documenting the remaining size budget | Merged in PR #90 |
| 47 | Add deployment rehearsal baseline | Gate E | Implement P1-DEPLOY-002 by adding a local deploy-and-wire Foundry rehearsal, manifest schema/example, deployment docs, manifest parsing/wiring tests, and check-script integration while leaving fork/testnet broadcast artifacts for follow-up | Merged in PR #92 |
| 48 | Generate release artifact catalog | Gate G/Gate E support | Implement P1-RELEASE-001 by generating deterministic ABI checksums, bytecode checksums, interface IDs, and event topic catalog outputs from Foundry artifacts, then wire drift checks into local/CI gates and deployment docs | Merged in PR #94 |
| 49 | Generate and check deployment manifests | Gate E/Gate G support | Implement P1-DEPLOY-003 by generating the Anvil manifest from committed inputs, filling current ABI/runtime bytecode hashes, adding deterministic manifest checksums, and wiring drift checks into local/CI gates and deployment docs | Merged in PR #96 |
| 50 | Add ABI compatibility checks | Gate G support | Implement P1-RELEASE-002 by committing a production ABI surface baseline, failing local/CI checks on removed or changed ABI entries, reporting additive entries, and documenting baseline refresh policy | Merged in PR #98 |
| 51 | Generate deployment address books | Gate G/Gate E support | Implement P1-RELEASE-003 by projecting committed deployment manifests into compact deterministic address-book artifacts for integrators, scripts, and docs, with drift checks in local/CI gates | Merged in PR #100 |
| 52 | Add signable release checksum bundle | Gate G support | Implement P1-RELEASE-004 by generating deterministic SHA256SUMS and machine-readable checksum manifests over committed release/deployment artifacts, with drift checks in local/CI gates | Merged in PR #102 |
| 53 | Add release change approval policy and changelog gate | Gate G support | Implement P1-RELEASE-005 by documenting ABI/schema/release change approval rules and adding a local/CI changelog gate for release-impacting paths | Merged in PR #104 |
| 54 | Generate machine-readable release manifest | Gate G support | Implement P1-RELEASE-006 by generating a deterministic top-level release manifest over committed release/deployment artifacts, governance docs, and release-ceremony status, with local/CI drift checks | Merged in PR #106 |
| 55 | Generate source verification inputs | Gate G support | Implement P1-RELEASE-007 by generating deterministic source-verification inputs from Foundry artifacts, source files, compiler settings, and contract config, with local/CI drift checks | Merged in PR #108 |
| 56 | Add Foundry broadcast manifest ingestion | Gate E/Gate G support | Implement P1-DEPLOY-004 by parsing sanitized Foundry broadcast output into deterministic deployment-manifest evidence with local/CI drift checks | Merged in PR #110 |
| 57 | Add metadata size limits | Gate D/Gate G support | Continue P1-META-006 by enforcing numeric byte caps for metadata storage inputs, generated `tokenURI` output, and dependency registry metadata, with focused tests, docs, release artifact refresh, and roadmap traceability | Merged in PR #111 |
| 58 | Add metadata render-sandbox fixture checks | Gate D | Continue P1-META-006 by validating committed metadata golden fixtures for JSON/data-URI/HTML script-boundary shape and URI scheme policy in local/CI gates, without changing production bytecode | Merged in PR #112 |
| 59 | Add metadata token image URI policy | Gate D/Gate G support | Continue P1-META-006 by defining renderer content/script URI policy helpers and rejecting unsafe token image URI writes in production while preserving collection base URI, external library URL, structured-attributes, invalid-UTF-8, and browser-sandbox work as follow-up slices | Merged in PR #113 |
| 60 | Add collection URI production enforcement | Gate D/Gate G support | Continue P1-META-006 by enforcing optional collection base URI and external library URL policy in production, preserving empty optional fields, using custom-error cleanup to keep `StreamCore` under EIP-170, and updating docs/artifacts/state traceability | Merged in PR #114 |
| 61 | Recover `StreamCore` bytecode headroom | Gate D/Gate G support | Implement P1-SIZE-001 by replacing selected legacy `StreamCore` string reverts with typed custom errors, adding focused selector regressions, documenting the minimum size floor and warning threshold, and refreshing release artifacts | Merged in PR #116 |
| 62 | Add dependency artifact manifest packaging | Gate D/Gate G support | Implement issue #117 by adding deterministic dependency artifact descriptors, a generated release manifest, local/CI drift checks, release checksum coverage, docs, and roadmap traceability without Solidity bytecode changes | Merged in PR #118 |
| 63 | Add metadata fixture UTF-8 and semantic attribute safety tests | Gate D/Gate G support | Implement issue #119 by adding focused fixture-checker regressions for invalid UTF-8 metadata/animation payloads and semantic attribute shape failures, and include issue #120's release-artifact LF pinning fix discovered during validation; docs and roadmap traceability, no Solidity bytecode changes | Merged in PR #121 |
| 64 | Enforce production raw attribute schema | Gate D/Gate G support | Implement issue #122 by hardening `StreamMetadataRenderer.isSafeRawAttributes` so production writes accept only empty fragments or comma-separated `trait_type` / `value` string-pair objects, with focused tests, docs, release artifact refresh, and roadmap state updates | Merged in PR #123 |
| 65 | Enforce dependency registry UTF-8 metadata policy | Gate D/Gate G support | Implement the mergeable issue #124 slice by adding a shared strict UTF-8 scanner, enforcing it for `DependencyRegistry` script/provenance writes, documenting the `StreamCore` EIP-170 blocker in issue #125, and refreshing tests/docs/artifacts | Merged in PR #126 |
| 66 | Recover Core UTF-8 enforcement headroom | Gate D/Gate G support | Implement issue #125 by recovering or avoiding enough `StreamCore` bytecode to enforce strict UTF-8 for Core metadata inputs without violating EIP-170, with focused tests/docs/artifacts | Merged in PR #127 |
| 67 | Add browser execution metadata sandbox checks | Gate D | Implement issue #128 by adding a deterministic browser-backed check for committed final animation metadata, pinning reproducible browser tooling, wiring local/CI gates, and updating docs/roadmap/state | Merged in PR #129 |
| 68 | Expose stale and failed randomness metadata states | Gate D | Implement issue #130 by mapping lifecycle-aware `Stale` and `FailedPostProcessing` requests into public metadata state strings, off-chain URIs, schema-v1 on-chain JSON, fixtures, docs, and roadmap traceability | Merged in PR #131 |
| 69 | Recover `StreamCore` release-floor bytecode headroom | Gate D/Gate G support | Implement issue #132 by recovering at least 156 bytes of `StreamCore` production runtime headroom, preserving metadata state behavior, refreshing size docs/artifacts, and keeping the production IR size gate green | Merged in PR #133 |
| 70 | Reconcile completed roadmap issues | Gate G support | Implement issue #134 by marking stale umbrella issues as evidence-backed completed work, creating narrower follow-ups for true remaining work, and preparing issue-closure actions after review | Merged in PR #137 |
| 71 | Document dependency migration runbooks | Gate D/Gate G support | Implement issue #136 by adding production dependency operation, migration, source-retention, deprecation, and rollback runbooks, linking them from release/deployment docs, and refreshing generated release evidence | Merged in PR #138 |
| 72 | Add deployment-rehearsal metadata browser coverage | Gate D/Gate E support | Implement issue #135 by executing metadata generated from a local deployment rehearsal in the same Chromium sandbox policy as committed metadata fixtures, wiring local/CI gates, and updating release evidence docs | Merged in PR #139 |
| 73 | Add dry-run auction ceremony rehearsal | Gate E | Implement issue #140 by proving a local deployed stack can run the operational auction ceremony from signed auction drop through bid, settlement, proceeds withdrawal, and final accounting without RPC secrets | Merged in PR #141 |
| 74 | Add local emergency redeployment rehearsal | Gate E | Implement issue #142 by proving ADR 0007 immutable redeployment evidence locally: distinct old/replacement deployment versions, manifests, drop domains, contract addresses, Safe-rooted ceremonies, and replacement smoke mint without RPC secrets | Merged in PR #143 |
| 75 | Add deployment ceremony evidence bundle schema | Gate E/Gate G support | Implement issue #144 by defining a no-secret ceremony evidence schema, local Anvil evidence bundle, validator, tests, local/CI gates, release-manifest/checksum coverage, docs, roadmap, and run-state updates | Merged in PR #145 |
| 76 | Add local gas snapshot baseline | Gate D/Gate G support | Implement issue #146 by adding deterministic gas snapshot scenarios, a committed baseline, local/CI drift checks, release-manifest/checksum coverage, docs, roadmap, and run-state updates | Merged in PR #147 |
| 77 | Add supply/replay/freeze invariant baseline | Gate D | Implement issue #148 by adding bounded sequence coverage for supply counters, drop replay/cancellation state, burns, freeze manifests, and post-freeze guards, with docs/roadmap/run-state updates | Merged in PR #149 |
| 78 | Add auction consistency invariant baseline | Gate D | Implement issue #150 by adding bounded sequence coverage for auction registration, custody, bids, outbids, cancellation, terminal settlement, proceeds/credits, and invalid-operation preservation, with docs/roadmap/run-state updates | Merged in PR #151 |
| 79 | Add request-level randomizer reserve lifecycle tests | Gate D | Implement issue #152 by adding focused `NextGenRandomizerRNG` reserve lifecycle coverage for request-cost spending, multiple pending requests, fulfillment, stale marking, failed post-processing, retry, forced ETH, and emergency-withdrawal boundaries | Merged in PR #153 |
| 80 | Add randomizer operations evidence bundle | Gate E/Gate G support | Implement issue #154 by adding a no-secret randomizer operations evidence schema, local Anvil bundle, validator/tests, local/CI gate wiring, release manifest/checksum coverage, docs, roadmap, and run-state updates | Merged in PR #155 |
| 81 | Add release signature evidence baseline | Gate G support | Implement issue #156 by adding a no-secret release signature evidence schema, local placeholder bundle, validator/tests, local/CI gate wiring, release manifest/checksum coverage, docs, roadmap, and run-state updates | Merged in PR #157 |
| 82 | Add external audit package index | Gate F | Implement issue #158 by adding an auditor-facing audit package index, checker/tests, local/CI gate wiring, release-manifest coverage, docs, roadmap, and run-state updates without Solidity changes | Merged in PR #159 |
| 83 | Add architecture and threat model audit docs | Gate F | Implement issue #160 by adding auditor-facing architecture/threat-model docs, checker/tests, local/CI gate wiring, release-manifest coverage, docs, roadmap, and run-state updates without Solidity changes | Merged in PR #161 |
| 84 | Add release readiness dashboard and blocker checker | Gate G | Implement issue #162 by adding a Gate G dashboard, checker/tests, local/CI gate wiring, release-manifest coverage, docs, roadmap, and run-state updates without Solidity changes | Merged in PR #163 |
| 85 | Add public beta evidence status manifest | Gate G | Implement issue #164 by adding a no-secret public-beta evidence status artifact, schema, checker/tests, local/CI gate wiring, release-manifest/checksum coverage, docs, roadmap, and run-state updates without Solidity changes | Merged in PR #165 |
| 86 | Reconcile Gate G roadmap after public beta evidence merge | Gate G support | Implement issue #166 by marking PR #165 merged, refreshing stale roadmap verification metadata, removing #164 from active Gate G blockers, and adding the next non-local evidence queue target | Merged in PR #167 |
| 87 | Add non-local release evidence intake runbook | Gate E/Gate G support | Document the operator workflow for retaining fork/testnet/live deployment, metadata-browser, ceremony, randomizer, verification, address-book, gas, invariant, audit, and signed-release evidence without secrets, then wire the docs into readiness/public-beta evidence maintenance | Merged in PR #169 |
| 88 | Add non-local release evidence metadata schema and checker | Gate E/Gate G support | Add a no-secret schema, template/example, checker, and tests for reviewed non-local evidence metadata so future operators can produce machine-checkable artifacts without claiming external readiness | Merged in PR #171 |
| 89 | Reconcile Gate G roadmap after non-local evidence schema merge | Gate G support | Implement issue #172 by marking PR #171 merged, refreshing stale roadmap verification metadata, recording CI and CodeRabbit evidence, and preserving the next queue target | Merged in PR #174 |
| 90 | Add protocol incident response runbooks | Gate E/Gate G support | Implement issue #173 by adding no-secret operator runbooks for stuck auctions, failed or stale randomness, bad Merkle roots, bad metadata/dependency configuration, signer compromise, and release artifact/evidence mistakes | Merged in PR #175 |
| 91 | Reconcile roadmap after incident response runbook merge | Gate G support | Implement issue #176 by marking PR #175 merged, refreshing stale roadmap verification metadata, recording CI and CodeRabbit evidence, and selecting the next signing examples target | Merged in PR #178 |
| 92 | Add drop authorization signing examples and fixtures | Gate G/Gate C support | Implement issue #177 by adding no-secret EIP-712/ERC-1271 signing examples, deterministic fixtures, checker/tests, docs links, and release artifact coverage if needed | Merged in PR #179 |
| 93 | Add no-secret drop authorization payload generator tooling | Gate G/Gate C support | Implement issue #180 by adding a production-safe unsigned typed-data generator, derived-hash output, tests, docs links, and maintained local/CI gates without private-key handling | Merged in PR #181 |
| 94 | Reconcile autonomous run state after drop authorization payload generator merge | Gate G support | Implement issue #182 by marking PR #181 merged, recording CI and CodeRabbit evidence, and selecting the next no-secret signing evidence target | Merged in PR #184 |
| 95 | Add drop authorization signing evidence schema and checker | Gate G/Gate C support | Implement issue #183 by adding a no-secret schema, template/example, checker, tests, docs links, and maintained local/CI gates for retained drop authorization signing evidence | Merged in PR #185 |
| 96 | Reconcile drop authorization signing evidence merge state | Gate G support | Implement issue #186 by marking PR #185 merged, recording final CI/CodeRabbit evidence, refreshing roadmap verification metadata, and selecting the next no-secret signer-custody readiness target | Merged in PR #188 |
| 97 | Add production signer custody readiness evidence | Gate G/Gate C support | Implement issue #187 by adding a no-secret signer custody/readiness evidence schema/template/checker/tests/docs and local/CI gates without private keys, signer-service secrets, or public-beta readiness claims | Merged in PR #189 |
| 98 | Reconcile signer custody readiness merge state | Gate G support | Implement issue #190 by marking PR #189 merged, recording final CI/CodeRabbit evidence, refreshing roadmap verification metadata, and selecting the next public-beta evidence blocker-report target | Merged in PR #192 |
| 99 | Add public beta evidence blocker report artifact | Gate G support | Implement issue #191 by generating a deterministic no-secret report from `release-artifacts/latest/public-beta-evidence.json` that lists incomplete public-beta evidence rows and validation commands without changing readiness claims | Merged in PR #193 |
| 100 | Reconcile public beta blocker report merge state | Gate G support | Implement issue #194 by recording PR #193 merge, CI, CodeRabbit, and next-target state without changing readiness claims | Merged in PR #196 |
| 101 | Add per-requirement public beta evidence templates | Gate G support | Implement issue #195 by adding public-safe templates for each incomplete public-beta evidence row, with checks/docs and no fork/testnet/live/audit readiness claims | Merged in PR #197 |
| 102 | Reconcile public beta template merge state | Gate G support | Implement issue #198 by recording PR #197 merge, CI, CodeRabbit, and next-target state without changing readiness claims | Merged in PR #200 |
| 103 | Add per-requirement production release evidence templates | Gate G support | Implement issue #199 by adding public-safe templates for each incomplete production-release evidence row, with checks/docs and no production readiness claims | Merged in PR #201 |
| 104 | Reconcile production release template merge state | Gate G support | Implement issue #202 by recording PR #201 merge evidence, refreshing stale roadmap verification metadata, and selecting the next no-secret production-readiness support target | Merged in PR #204 |
| 105 | Add production release blocker report artifact | Gate G support | Implement issue #203 by generating a deterministic production-focused blocker report from committed evidence metadata and templates without changing readiness claims | Merged in PR #205 |
| 106 | Reconcile production blocker report merge state | Gate G support | Implement issue #206 by recording PR #205 merge evidence, refreshing stale roadmap verification metadata, and selecting the next no-secret release-readiness support target | Merged in PR #208 |
| 107 | Add release evidence packet index and checker | Gate G support | Implement issue #207 by generating one deterministic no-secret packet index that maps public-beta and production-release blocker rows to templates, retained-artifact expectations, validation commands, and current readiness posture | Merged in PR #209 |
| 108 | Reconcile release evidence packet index merge state | Gate G support | Implement issue #210 by recording PR #209 merge evidence, refreshing stale roadmap verification metadata, and selecting the next no-secret roadmap target without changing readiness claims | Merged in PR #211 |
| 109 | Add release evidence issue backlog artifact | Gate G support | Implement issue #212 by generating deterministic no-secret issue-ready backlog entries for every incomplete public-beta and production-release evidence requirement without auto-creating issues or changing readiness claims | Merged in PR #213 |
| 110 | Link release evidence backlog entries to GitHub tracker issues | Gate G support | Implement issue #214 by committing a deterministic no-secret issue-link map for release evidence backlog rows, validating one GitHub issue per row, and wiring docs/local/CI checks without changing readiness claims | Merged in PR #232 |
| 111 | Reconcile release evidence issue links merge state | Gate G support | Implement issue #233 by recording PR #232 merge evidence, refreshing stale roadmap verification metadata, and preserving the next tracker-issue queue posture without changing readiness claims | Merged in PR #234 |
| 112 | Generate and apply release evidence tracker issue bodies | Gate G support | Implement issue #235 by generating exact no-secret GitHub issue body payloads from the committed backlog/link map, wiring them into local/CI/release gates, applying them to issues #215 through #231, and preserving blocked readiness claims | Merged in PR #236 |
| 113 | Reconcile release evidence issue body sync merge state | Gate G support | Implement issue #237 by recording PR #236 merge evidence, tracker-label reconciliation, refreshed roadmap verification metadata, and the next no-secret evidence-tracker hardening target | Merged in PR #238 |
| 114 | Harden release evidence tracker label drift checks | Gate G support | Add a no-secret label audit/sync helper so tracker issues #215 through #231 cannot silently drift from committed `applied_labels` before retained evidence completion | Active |

## Current PR Worklog

### PR candidate: Harden release evidence tracker label drift checks (Queue Item 114)

Status: PR #240 open; CI passed, CodeRabbit provenance comments being addressed.
Issue: `https://github.com/6529-Collections/6529Stream/issues/239`.
PR: `https://github.com/6529-Collections/6529Stream/pull/240`.
Branch: `codex/release-evidence-label-drift`.
Branch started from PR #238 squash merge commit
`3c738f51c8fa2cf623fda1f3d1fe5284db946d99`.

Prior queue transition:

- Queue Item 113 merged in PR #238 as squash commit
  `3c738f51c8fa2cf623fda1f3d1fe5284db946d99`.
- PR #238 final implementation head was
  `d56f7d2405fd0c52fdf2320a0f167253aceb4bf7`.
- PR #238 GitHub Actions CI run `27468501813` passed on the final head.
- PR #238 CodeRabbit status was success with no unresolved review threads.
- Issue #237 closed completed after merge.

Goal:

- Add a deterministic no-network checker for committed
  `release-evidence-issue-links.json` `applied_labels` posture.
- Add an optional exported live GitHub issue snapshot audit mode for issues
  #215 through #231, including deterministic remediation commands for missing
  labels.
- Wire the deterministic checker into local/CI/release-readiness gates and
  document the optional live audit workflow without changing readiness claims.

Completed local validation:

- `python scripts/test_release_evidence_issue_labels.py`.
- `python scripts/check_release_evidence_issue_labels.py`.
- `python scripts/test_release_evidence_issue_body_sync.py`.
- `python scripts/generate_release_evidence_issue_body_sync.py --check`.
- `python scripts/check_release_readiness.py`.
- `python scripts/test_release_readiness.py`.
- `python scripts/test_release_manifest.py`.
- `python scripts/generate_release_manifest.py --check`.
- `python scripts/test_release_checksums.py`.
- `python scripts/generate_release_checksums.py --check`.
- `python scripts/check_changelog.py`.
- `bash -n scripts/check.sh`.
- PowerShell parser check for `scripts/check.ps1`.
- `rg -n "^#|^##|^###" docs/tooling.md docs/public-beta-evidence.md docs/release-readiness.md release-artifacts/README.md ops/ROADMAP.md ops/AUTONOMOUS_RUN.md`.
- `git diff --check`.
- Live GitHub label snapshot audit with
  `python scripts/check_release_evidence_issue_labels.py --live-json tmp/release-evidence-issue-labels.json`.

### Completed: Reconcile release evidence issue body sync merge state (Queue Item 113)

Status: merged in PR #238.
Issue: `https://github.com/6529-Collections/6529Stream/issues/237`.
PR: `https://github.com/6529-Collections/6529Stream/pull/238`.
Branch: `codex/release-evidence-body-state`.
Branch started from PR #236 squash merge commit
`1a825466d2333dc75e2fb8e2aeb11dc9b0dccc5a`.

Prior queue transition:

- Queue Item 112 merged in PR #236 as squash commit
  `1a825466d2333dc75e2fb8e2aeb11dc9b0dccc5a`.
- PR #236 final implementation head was
  `4606bb127d491b18cb6d4411657e985faebf1c12`.
- PR #236 GitHub Actions CI run `27468161616` passed on the final head,
  including deployment rehearsal.
- PR #236 CodeRabbit status was success after review-response commit
  `4606bb127d491b18cb6d4411657e985faebf1c12`; the two original review threads
  were resolved as addressed and no unresolved review threads remained.
- Issue #235 closed completed after merge.
- Tracker issues #215 through #231 remain open because they require reviewed
  retained external evidence; their live `release` and `roadmap` labels were
  re-applied after the merge to match committed `applied_labels`.

Goal:

- Mark Queue Item 112 complete and record the final PR #236 evidence.
- Refresh roadmap verification metadata to the merged PR #236 baseline.
- Record the tracker-label reconciliation without changing readiness claims.
- Select the next no-secret evidence-tracker hardening target.

Completed local validation:

- `python scripts/check_release_readiness.py`.
- `python scripts/test_release_readiness.py`.
- `python scripts/check_changelog.py`.
- `python scripts/generate_release_manifest.py --check`.
- `python scripts/generate_release_checksums.py --check`.
- `rg -n "^#|^##|^###" ops/ROADMAP.md ops/AUTONOMOUS_RUN.md`.
- `git diff --check`.

### Completed: Generate and apply release evidence tracker issue bodies (Queue Item 112)

Status: merged in PR #236.
Issue: `https://github.com/6529-Collections/6529Stream/issues/235`.
PR: `https://github.com/6529-Collections/6529Stream/pull/236`.
Branch: `codex/release-evidence-issue-bodies`.
Branch started from PR #234 squash merge commit
`1ac0765632f053c5a29c27375d04de8c9d75736b`.

Prior queue transition:

- Queue Item 111 merged in PR #234 as squash commit
  `1ac0765632f053c5a29c27375d04de8c9d75736b`.
- PR #234 final implementation head was
  `2a26f748b087543147a8a756775eea0e3ff5839e`.
- PR #234 GitHub Actions CI run `27466683865` passed on the final head.
- PR #234 CodeRabbit status was success with no actionable review comments or
  unresolved review threads.
- Issue #233 closed completed after merge.
- Child release-evidence tracker issues #215 through #231 remain open because
  they require reviewed retained external evidence.

Goal:

- Add deterministic body-sync JSON and Markdown artifacts that join
  `release-artifacts/latest/release-evidence-issue-backlog.json` and
  `release-artifacts/latest/release-evidence-issue-links.json` into exact
  GitHub issue body payloads.
- Validate the body-sync artifact with no-secret scanning, source parity,
  required issue-body sections, duplicate/stale issue-link protection, local
  tests, CI wiring, release manifest coverage, and checksum coverage.
- Apply the generated expected bodies to live tracker issues #215 through #231
  without closing those issues or claiming evidence completion.
- Preserve public-beta and production readiness claims: tracker issue bodies
  organize missing retained evidence work, but do not satisfy external audit,
  fork/testnet/live, signature, or production evidence rows.

Completed local validation:

- `python -m py_compile scripts/generate_release_evidence_issue_body_sync.py scripts/test_release_evidence_issue_body_sync.py`.
- `python scripts/generate_release_evidence_issue_body_sync.py`.
- `python scripts/test_release_evidence_issue_body_sync.py`.
- `python scripts/generate_release_evidence_issue_body_sync.py --check`.
- `python scripts/generate_release_artifacts.py`.
- `python scripts/generate_release_manifest.py`.
- `python scripts/generate_release_checksums.py`.
- `python scripts/test_release_artifacts.py`.
- `python scripts/generate_release_artifacts.py --check`.
- `python scripts/test_release_manifest.py`.
- `python scripts/generate_release_manifest.py --check`.
- `python scripts/test_release_checksums.py`.
- `python scripts/generate_release_checksums.py --check`.
- `python scripts/test_release_readiness.py`.
- `python scripts/check_release_readiness.py`.
- `python scripts/test_changelog_check.py`.
- `python scripts/check_changelog.py`.
- `bash -n scripts/check.sh`.
- PowerShell parser check for `scripts/check.ps1`.
- `rg -n "^#|^##|^###" docs/release-readiness.md docs/public-beta-evidence.md docs/tooling.md release-artifacts/README.md ops/ROADMAP.md ops/AUTONOMOUS_RUN.md release-artifacts/latest/release-evidence-issue-body-sync.md`.
- `git diff --check`.
- `make check`.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`.

Remote issue-body application:

- Applied generated `expected_body` payloads from
  `release-artifacts/latest/release-evidence-issue-body-sync.json` to issues
  #215 through #231 using `gh issue edit --body-file` with temporary files
  outside the repository.
- Verified all 17 live GitHub issue bodies match the generated artifact content
  after normalizing trailing newlines.

Remote review:

- PR #236 opened against `main` from head
  `f7dc33795e45129da62e3636448f781c4bcbe251`.
- CodeRabbit review requested in comment `4698628618`.
- State-only follow-up commit `285b942034521e83b4b361bf8b759c30b97bd0c4`
  recorded the PR after opening.
- GitHub Actions Foundry smoke run `27467859837` passed on head
  `285b942034521e83b4b361bf8b759c30b97bd0c4`.
- CodeRabbit review `4491474201` posted two actionable comments:
  `docs/tooling.md` needed to name the committed issue-link map in checksum
  coverage, and `ops/ROADMAP.md` needed to replace stale body-sync status
  wording with PR #236 / complete wording.
- Review-response commit `4606bb127d491b18cb6d4411657e985faebf1c12`
  addressed the CodeRabbit comments and regenerated release manifest/checksum
  artifacts.
- CodeRabbit second pass completed successfully with no new actionable threads.
- Original CodeRabbit review threads were resolved as addressed and outdated.
- Final GitHub Actions Foundry smoke run `27468161616` passed on head
  `4606bb127d491b18cb6d4411657e985faebf1c12`.
- PR #236 squash-merged as
  `1a825466d2333dc75e2fb8e2aeb11dc9b0dccc5a`, closing issue #235 as completed.
- After merge, tracker issues #215 through #231 were reconciled to retain
  `release` and `roadmap` labels, matching committed `applied_labels`; they
  remain open for reviewed retained evidence.

### Completed: Reconcile release evidence issue links merge state (Queue Item 111)

Status: merged in PR #234.
Issue: `https://github.com/6529-Collections/6529Stream/issues/233`.
PR: `https://github.com/6529-Collections/6529Stream/pull/234`.
Branch: `codex/release-evidence-link-state`.
Branch started from PR #232 squash merge commit
`acfb94230ad596de6a4578f6b269cbc6fa8fd78d`.

Prior queue transition:

- Queue Item 110 merged in PR #232 as squash commit
  `acfb94230ad596de6a4578f6b269cbc6fa8fd78d`.
- PR #232 final implementation head was
  `d1a0245e3d56401fa442ac03767f346ab8f6d79b`.
- PR #232 GitHub Actions CI run `27466388746` passed on the final head,
  including deployment rehearsal.
- PR #232 CodeRabbit status was success; the only actionable review thread was
  resolved by the follow-up commit.
- Issue #214 closed completed after merge.
- Child release-evidence tracker issues #215 through #231 remain open because
  they require reviewed retained external evidence, not repository-only state.

Goal:

- Mark Queue Item 110 as merged and record PR #232 merge evidence.
- Refresh `ops/ROADMAP.md` verification metadata from PR #213 to PR #232.
- Keep release-readiness claims unchanged: the issue-link artifact organizes
  missing external evidence but does not complete any fork/testnet/live,
  external audit, signature, or production evidence row.
- Preserve the next queue posture for reviewing the open child tracker issues.

Completed local validation:

- `rg -n "^#|^##|^###" ops/ROADMAP.md ops/AUTONOMOUS_RUN.md`.
- `rg -n "Queue Item 110|Queue Item 111|PR #232|#214|#233|Last verified|CI run" ops/ROADMAP.md ops/AUTONOMOUS_RUN.md`.
- `git diff --check`.

Remote review:

- PR #234 opened against `main` from head
  `dff1c2d4aad9c3708cf19031a99840fe37bfa31e`.
- PR #234 final implementation head was
  `2a26f748b087543147a8a756775eea0e3ff5839e`.
- GitHub Actions CI run `27466683865` passed.
- CodeRabbit reported success with no actionable comments or unresolved review
  threads.
- PR #234 merged as squash commit
  `1ac0765632f053c5a29c27375d04de8c9d75736b`, and issue #233 closed
  completed.

### Completed: Link release evidence backlog entries to GitHub tracker issues (Queue Item 110)

Status: merged in PR #232.
Issue: `https://github.com/6529-Collections/6529Stream/issues/214`.
PR: `https://github.com/6529-Collections/6529Stream/pull/232`.
Branch: `codex/release-evidence-issue-links`.
Branch started from PR #213 squash merge commit
`fc8df90cea2ac77fb8be88c3d2258a77693f374c`.

Outcome:

- Committed `release-artifacts/latest/release-evidence-issue-links.json` as a
  no-secret tracker map from every generated backlog entry to exactly one
  GitHub issue.
- Added checker/tests for schema, parent issue, policy flags, source backlog
  identity, entry parity, issue URL/number matching, duplicate protection,
  label traceability, secret-like data scanning, and IO/UTF-8 failure wrapping.
- Wired the checker into Makefile, shell/PowerShell wrappers, CI, release
  manifest, checksum coverage, release-artifact downstream handling,
  release-readiness docs, public-beta evidence docs, tooling docs, changelog,
  roadmap, and this durable state file.
- Preserved blocked readiness claims: tracker issues organize missing evidence
  work, but do not satisfy external audit, fork/testnet/live, signature, or
  production evidence gates.

Merge evidence:

- PR #232 opened against `main` from head
  `b159a596923f16d33e6bdb8f59700a39ed9cd913`.
- CodeRabbit requested in comments `4698436262`, `4698439740`, and
  `4698478299`.
- CodeRabbit review `4491391500` requested consistent IO/UTF-8 decode error
  wrapping in the issue-link JSON loader; commit
  `d1a0245e3d56401fa442ac03767f346ab8f6d79b` addressed it and the thread was
  resolved.
- GitHub Actions CI run `27466388746` passed on final head
  `d1a0245e3d56401fa442ac03767f346ab8f6d79b`.
- PR #232 squash-merged as
  `acfb94230ad596de6a4578f6b269cbc6fa8fd78d`.
- Issue #214 closed completed after merge.

### PR candidate: Add release evidence issue backlog artifact (Queue Item 109)

Status: merged in PR #213.
Issue: `https://github.com/6529-Collections/6529Stream/issues/212`.
PR: `https://github.com/6529-Collections/6529Stream/pull/213`.
Branch: `codex/release-evidence-issue-backlog`.
Branch started from PR #211 squash merge commit
`767dd61183b0b350c114f48aa034e08192a16c23`.

Prior queue transition:

- Queue Item 108 merged in PR #211 as squash commit
  `767dd61183b0b350c114f48aa034e08192a16c23`.
- PR #211 final implementation head was
  `2b777346e85ee2a932293042acbd8f3ae6817e08`.
- PR #211 GitHub Actions CI run `27463609371` passed on the final head.
- PR #211 CodeRabbit status was success with no actionable comments, no review
  threads, and five pre-merge checks passed.
- Issue #210 was closed completed after merge.

Goal:

- Generate `release-artifacts/latest/release-evidence-issue-backlog.json` and
  `release-artifacts/latest/release-evidence-issue-backlog.md` from the
  committed release evidence packet index.
- Include one issue-ready backlog entry per incomplete public-beta and
  production-release evidence requirement, with title, labels, body, completion
  gate, validation commands, owner/reviewer posture, blocker reference, template
  path, and retained-artifact expectation.
- Keep `template_only_can_complete = false`, avoid secrets, avoid automatic
  issue creation, and preserve blocked readiness claims.
- Wire generator tests/checks into Makefile, shell/PowerShell wrappers, CI,
  release manifest, checksum coverage, release-artifact downstream handling,
  release-readiness docs, public-beta evidence docs, tooling docs, changelog,
  roadmap, and this durable state file.

Completed local validation so far:

- `python -m py_compile scripts/generate_release_evidence_issue_backlog.py scripts/test_release_evidence_issue_backlog.py scripts/generate_release_manifest.py scripts/test_release_manifest.py scripts/check_release_readiness.py scripts/test_release_artifacts.py`.
- `python scripts/test_release_evidence_issue_backlog.py`.
- `python scripts/generate_release_evidence_issue_backlog.py --check`.
- `python scripts/test_release_manifest.py`.
- `python scripts/generate_release_manifest.py --check`.
- `python scripts/test_release_checksums.py`.
- `python scripts/generate_release_checksums.py --check`.
- `python scripts/test_release_artifacts.py`.
- `python scripts/generate_release_artifacts.py --check`.
- `python scripts/test_release_readiness.py`.
- `python scripts/check_release_readiness.py`.
- `python scripts/test_changelog_check.py`.
- `python scripts/check_changelog.py`.
- `bash -n scripts/check.sh`.
- PowerShell parser check for `scripts/check.ps1`.
- `rg -n "^#|^##|^###" ops/ROADMAP.md ops/AUTONOMOUS_RUN.md docs/release-readiness.md docs/public-beta-evidence.md release-artifacts/README.md docs/tooling.md`.
- `git diff --check` (passes with the existing Windows LF-to-CRLF warning for
  `scripts/check.ps1`).
- `make check` (passes with existing Solidity compiler and Foundry trace warning
  noise only).

Remote review:

- PR #213 opened against `main` from head
  `c45d49c2cb31ceddf0d0657c532b09654b7c4207`.
- CodeRabbit requested in comment `4698282548`.
- CodeRabbit review `4491326886` requested typed packet-field validation, a
  missing nested-field regression, and tooling command-list parity.
- Review fix commit `6ac85e8e1d04e1fe383e81fb390f0573f3c9406f` passed focused
  local validation and full `make check`.
- GitHub Actions CI run `27465004282` passed on the final head.
- CodeRabbit status was success with no actionable comments after the review
  fix.
- PR #213 squash-merged as
  `fc8df90cea2ac77fb8be88c3d2258a77693f374c`.

### Completed: Reconcile release evidence packet index merge state (Queue Item 108)

Status: merged in PR #211.
Issue: `https://github.com/6529-Collections/6529Stream/issues/210`.
PR: `https://github.com/6529-Collections/6529Stream/pull/211`.
Branch: `codex/reconcile-release-packet-merge`.

Results:

- Queue Item 107 and PR #209 were recorded as merged.
- Roadmap verification metadata was refreshed from PR #209 state.
- PR #211 opened against `main` from head
  `6a9ff2c3e2e4970c874b1dffd4a76a5b285d9457`, then received follow-up state
  commit `2b777346e85ee2a932293042acbd8f3ae6817e08`.
- GitHub Actions CI run `27463609371` passed on the final head.
- CodeRabbit status was success with no actionable comments and five pre-merge
  checks passed.
- PR #211 squash-merged as
  `767dd61183b0b350c114f48aa034e08192a16c23`.
- Issue #210 was closed completed after merge.

### Completed: Add release evidence packet index and checker (Queue Item 107)

Status: Merged in PR #209.
Issue: `https://github.com/6529-Collections/6529Stream/issues/207`.
PR: `https://github.com/6529-Collections/6529Stream/pull/209`.
Branch: `codex/release-evidence-packet-index`.
Branch started from PR #208 squash merge commit
`43a9596ab429a6e46132b106655b52b848db1670`.

Prior queue transition:

- Queue Item 106 merged in PR #208 as squash commit
  `43a9596ab429a6e46132b106655b52b848db1670`.
- PR #208 final implementation head was
  `ff909596dfd1e272619f8a5bd37fac3bb0183075`.
- PR #208 GitHub Actions CI run `27462015238` passed on the final head.
- PR #208 CodeRabbit status was success with no actionable comments and five
  pre-merge checks passed.
- Issue #206 was closed completed after merge.

Goal:

- Generate a deterministic no-secret release evidence packet index in JSON and
  Markdown under `release-artifacts/latest/`.
- Map every public-beta and production-release evidence row to its blocker
  report row, checked template path, retained-artifact expectation, validation
  commands, current status, and owner/reviewer posture.
- Prove template-only evidence cannot complete a row and that the packet drifts
  when templates, blocker reports, or generated outputs drift.
- Wire the packet into Make, PowerShell, Unix shell, CI, release-manifest,
  checksum, release-readiness, public-beta evidence, release-artifact, tooling,
  roadmap, changelog, and durable run-state docs.
- Preserve the blocked public-beta and production-release baseline; do not
  change Solidity, deployment behavior, evidence contents, or readiness claims.

Implementation summary:

- Added `scripts/generate_release_evidence_packet_index.py` and
  `scripts/test_release_evidence_packet_index.py`.
- Added
  `release-artifacts/latest/release-evidence-packet-index.json` and
  `release-artifacts/latest/release-evidence-packet-index.md`.
- Added packet-index downstream coverage to `scripts/generate_release_artifacts.py`,
  `scripts/generate_release_manifest.py`, `scripts/test_release_artifacts.py`,
  `scripts/test_release_manifest.py`, and regenerated the release manifest and
  checksum bundle.
- Wired checks into `Makefile`, `scripts/check.sh`, `scripts/check.ps1`, and
  `.github/workflows/ci.yml`.
- Updated `docs/public-beta-evidence.md`, `docs/release-readiness.md`,
  `docs/tooling.md`, `release-artifacts/README.md`, `ops/ROADMAP.md`, and
  `CHANGELOG.md`.

Completed local validation:

- `python -m py_compile scripts/generate_release_evidence_packet_index.py scripts/test_release_evidence_packet_index.py scripts/generate_release_manifest.py scripts/test_release_manifest.py scripts/generate_release_artifacts.py scripts/test_release_artifacts.py scripts/check_release_readiness.py`.
- `python scripts/test_release_evidence_packet_index.py`.
- `python scripts/generate_release_evidence_packet_index.py --check`.
- `python scripts/test_public_beta_evidence.py`.
- `python scripts/check_public_beta_evidence.py`.
- `python scripts/test_public_beta_blocker_report.py`.
- `python scripts/generate_public_beta_blocker_report.py --check`.
- `python scripts/test_production_release_blocker_report.py`.
- `python scripts/generate_production_release_blocker_report.py --check`.
- `python scripts/test_non_local_release_evidence.py`.
- `python scripts/check_non_local_release_evidence.py`.
- `python scripts/test_release_artifacts.py`.
- `python scripts/generate_release_artifacts.py --check`.
- `python scripts/test_release_manifest.py`.
- `python scripts/generate_release_manifest.py --check`.
- `python scripts/test_release_checksums.py`.
- `python scripts/generate_release_checksums.py --check`.
- `python scripts/test_release_readiness.py`.
- `python scripts/check_release_readiness.py`.
- `python scripts/test_changelog_check.py`.
- `python scripts/check_changelog.py`.
- `bash -n scripts/check.sh`.
- PowerShell parser check for `scripts/check.ps1`.
- `rg -n "^#|^##|^###" ops/ROADMAP.md ops/AUTONOMOUS_RUN.md docs/public-beta-evidence.md docs/release-readiness.md docs/tooling.md release-artifacts/README.md`.
- `git diff --check` passed with the existing CRLF-normalization warning for
  `scripts/check.ps1`.
- `make check` passed with existing Solidity compiler warnings, Foundry
  trace-source warnings, etherscan-config warning, and deployer-selection
  warning noise only.

Remote review:

- PR #209 opened against `main` from head
  `dc2a0b000dbe3855aa043c09fe67ec19a15a2c5b`.
- CodeRabbit requested in comment `4698133258`.
- State follow-up pushed head `8e2d9afd9328dde66abaa65a0d9d4160b5fff965`.
- GitHub Actions run `27462987501` passed on head
  `8e2d9afd9328dde66abaa65a0d9d4160b5fff965`.
- CodeRabbit posted three actionable quick wins and one roadmap nit on head
  `8e2d9afd9328dde66abaa65a0d9d4160b5fff965`.
- Accepted all CodeRabbit findings locally: CI py_compile ordering, public-beta
  evidence packet-index check command, derived packet test cardinality/template
  expectations, and expanded roadmap packet-field summary.
- Review-fix local validation: `python scripts/test_release_evidence_packet_index.py`,
  `python scripts/generate_release_evidence_packet_index.py --check`,
  `python -m py_compile scripts/test_release_evidence_packet_index.py scripts/generate_release_evidence_packet_index.py`,
  `python scripts/check_release_readiness.py`, regenerated release manifest and
  checksum bundle, and final drift/whitespace checks before push.
- Final implementation head was
  `e571a2a2b4107c27f5c229e02d00dbe93c78381a`.
- GitHub Actions CI run `27463241499` passed on final head
  `e571a2a2b4107c27f5c229e02d00dbe93c78381a`.
- CodeRabbit status was success; the visible CodeRabbit threads were resolved
  or outdated, and five pre-merge checks passed.
- PR #209 squash-merged as
  `dec345094e26304a50c5b5e098c002b002972c37`, closing issue #207.

### Completed: Reconcile production blocker report merge state (Queue Item 106)

Status: Merged in PR #208.
Issue: `https://github.com/6529-Collections/6529Stream/issues/206`.
PR: `https://github.com/6529-Collections/6529Stream/pull/208`.
Branch: `codex/reconcile-production-blocker-report-merge`.
Branch started from PR #205 squash merge commit
`bc0384a7b77b582d954d861b2545ab2fc818d860`.

Implementation summary:

- Marked Queue Item 105 merged in the durable queue.
- Recorded PR #205 final CI, CodeRabbit, resolved-thread, and squash-merge
  evidence.
- Refreshed roadmap verification metadata that still said PR #205 checks were
  pending.
- Selected Queue Item 107 / issue #207 as the next no-secret release-readiness
  support target.
- Preserved the blocked public-beta and production-release baseline without
  changing Solidity, deployment behavior, evidence contents, or readiness
  claims.

Validation and merge evidence:

- Local heading, state-reconciliation grep, and whitespace checks passed.
- PR #208 opened against `main` from head
  `097ac7506820359388bb76eba11778021d5edfe2`.
- CodeRabbit requested in comment `4698031592`.
- Final head before merge: `ff909596dfd1e272619f8a5bd37fac3bb0183075`.
- GitHub Actions CI run `27462015238` passed.
- CodeRabbit status was success with no actionable comments and five
  pre-merge checks passed.
- Merged as squash commit
  `43a9596ab429a6e46132b106655b52b848db1670`.
- Issue #206 closed completed.

### Completed: Add production release blocker report artifact (Queue Item 105)

Status: Merged in PR #205.
Issue: `https://github.com/6529-Collections/6529Stream/issues/203`.
PR: `https://github.com/6529-Collections/6529Stream/pull/205`.
Branch: `codex/production-release-blocker-report`.
Branch started from PR #204 squash merge commit
`de5df8e382fbafe6c15c4f84dd978532debee90b`.

Prior queue transition:

- Queue Item 104 merged in PR #204 as squash commit
  `de5df8e382fbafe6c15c4f84dd978532debee90b`.
- PR #204 final implementation head was
  `8b6eadc265bbbe488b10800a62bfe22d28753a36`.
- PR #204 GitHub Actions CI run `27460486021` passed on the final head.
- PR #204 CodeRabbit status was success with no actionable comments or open
  review threads.
- PR #204 closed issue #202 at merge.
- Issue #203 now tracks the next no-secret Gate G support slice:
  a deterministic production-release blocker report generated from committed
  evidence metadata and production-release templates.

Goal:

- Add `scripts/generate_production_release_blocker_report.py` and focused
  self-tests.
- Generate and track
  `release-artifacts/latest/production-release-blockers.md`.
- Wire the report into Makefile, Windows wrapper, CI, release manifest,
  release-artifact drift handling, release checksums, docs, changelog, roadmap,
  and release-readiness validation.
- Preserve the blocked public-beta and production-release baseline; do not
  change Solidity, deployment behavior, or readiness claims.

Validation completed locally at `2026-06-13 08:11 UTC`:

- `python -m py_compile scripts/generate_production_release_blocker_report.py scripts/test_production_release_blocker_report.py scripts/generate_release_manifest.py scripts/test_release_manifest.py scripts/check_release_readiness.py`.
- `python scripts/test_production_release_blocker_report.py`.
- `python scripts/generate_production_release_blocker_report.py --check`.
- `python scripts/test_release_artifacts.py`.
- `python scripts/test_release_manifest.py`.
- `python scripts/test_release_readiness.py`.
- `python scripts/check_release_readiness.py`.
- `python scripts/generate_public_beta_blocker_report.py --check`.
- `python scripts/generate_release_manifest.py`.
- `python scripts/generate_release_checksums.py`.
- `python scripts/test_public_beta_blocker_report.py`.
- `python scripts/test_release_checksums.py`.
- `python scripts/generate_release_checksums.py --check`.
- `python scripts/check_public_beta_evidence.py`.
- `python scripts/check_non_local_release_evidence.py`.
- `python scripts/test_changelog_check.py`.
- `python scripts/check_changelog.py`.
- `python scripts/test_audit_package.py`.
- `python scripts/check_audit_package.py`.
- `python scripts/test_architecture_threat_model.py`.
- `python scripts/check_architecture_threat_model.py`.
- `rg -n "^#|^##|^###" ops/ROADMAP.md ops/AUTONOMOUS_RUN.md docs/public-beta-evidence.md docs/release-readiness.md release-artifacts/README.md docs/tooling.md README.md CHANGELOG.md`.
- `git diff --check` (no whitespace errors; Git printed the existing
  `scripts/check.ps1` line-ending warning).
- PowerShell syntax parse for `scripts/check.ps1`.
- `make check`.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`.

Bot review follow-up at `2026-06-13 08:26 UTC`:

- CodeRabbit left one actionable comment on PR #205 requesting production
  blocker rows to be grouped by shared status order before requirement ID.
- Updated `scripts/generate_production_release_blocker_report.py` to sort
  matching rows by `STATUS_ORDER` and requirement ID.
- Added a mixed-status regression in
  `scripts/test_production_release_blocker_report.py`.
- Regenerated `release-artifacts/latest/production-release-blockers.md`,
  `release-artifacts/latest/release-manifest.json`,
  `release-artifacts/latest/SHA256SUMS`, and
  `release-artifacts/latest/release-checksums.json`.
- Focused validation passed:
  `python -m py_compile scripts/generate_production_release_blocker_report.py scripts/test_production_release_blocker_report.py scripts/generate_release_manifest.py scripts/test_release_manifest.py scripts/check_release_readiness.py`,
  `python scripts/test_production_release_blocker_report.py`,
  `python scripts/generate_production_release_blocker_report.py --check`,
  `python scripts/test_release_manifest.py`,
  `python scripts/generate_release_manifest.py --check`,
  `python scripts/test_release_checksums.py`,
  `python scripts/generate_release_checksums.py --check`,
  `python scripts/test_release_readiness.py`,
  `python scripts/check_release_readiness.py`, and `git diff --check`.
- Final GitHub Actions CI run `27461633469` passed on final head
  `df5ef8342340e842725347aada48ca2ebf81a879`.
- CodeRabbit status was success, and the row-order review thread was resolved
  by CodeRabbit.
- PR #205 squash-merged as
  `bc0384a7b77b582d954d861b2545ab2fc818d860`, closing issue #203.

### Completed: Reconcile production release template merge state (Queue Item 104)

Status: Merged in PR #204.
Issue: `https://github.com/6529-Collections/6529Stream/issues/202`.
PR: `https://github.com/6529-Collections/6529Stream/pull/204`.
Branch: `codex/reconcile-production-template-merge`.
Branch started from PR #201 squash merge commit
`02ce230500cb016e45b67c8dbd6710c08cadc000`.

Prior queue transition:

- Queue Item 103 merged in PR #201 as squash commit
  `02ce230500cb016e45b67c8dbd6710c08cadc000`.
- PR #201 final implementation head was
  `a47870ddeee096e8f9d3212fe1579d56e3163c23`.
- PR #201 GitHub Actions CI run `27460093022` passed on the final head.
- PR #201 CodeRabbit status was success with no actionable comments or open
  review threads.
- PR #201 closed issue #199 at merge.
- Issue #203 now tracks the next no-secret Gate G support slice:
  a deterministic production-release blocker report generated from committed
  evidence metadata and production-release templates.

Goal:

- Mark Queue Item 103 merged in the durable queue.
- Record PR #201 final CI, CodeRabbit, and squash-merge evidence.
- Refresh roadmap verification metadata that still referenced PR #200.
- Replace Gate G wording that still described issue #199 as active.
- Select Queue Item 105 / issue #203 as the next no-secret production-release
  support slice.
- Do not change Solidity, deployment code, CI behavior, generated readiness
  artifacts, or public-beta/production readiness claims.

Validation completed locally at `2026-06-13 07:31 UTC`:

- `python scripts\check_release_readiness.py`.
- `python scripts\check_public_beta_evidence.py`.
- `python scripts\check_non_local_release_evidence.py`.
- `python scripts\generate_public_beta_blocker_report.py --check`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\generate_release_checksums.py --check`.
- `python scripts\check_changelog.py`.
- `rg -n "Queue Item 103|Queue Item 104|Queue Item 105|PR #201|27460093022|a47870d|02ce230|#199|#202|#203|Last verified|CI run" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `git diff --check`.

PR opened:

- PR #204 opened against `main` on head
  `d84d0ea119131dcaee899c25a6af6ab3b5f06297`.
- CodeRabbit review requested in PR comment `4697878038`.

### PR candidate: Add per-requirement production release evidence templates (Queue Item 103)

Status: Merged in PR #201 on `2026-06-13`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/199`.
PR: `https://github.com/6529-Collections/6529Stream/pull/201`.
Branch: `codex/production-release-evidence-templates`.
Branch started from PR #200 squash merge commit
`728eb7161c80f6b3690de45caf11fd3c9e01e277`.

Prior queue transition:

- Queue Item 102 merged in PR #200 as squash commit
  `728eb7161c80f6b3690de45caf11fd3c9e01e277`.
- PR #200 final implementation head was
  `98b0a807a698a96748f312e0531a86991693a8c3`.
- PR #200 GitHub Actions CI run `27459177572` passed on the final head.
- PR #200 CodeRabbit status was success with no actionable comments or open
  review threads.
- PR #200 closed issue #198 at merge.

Goal:

- Add one public-safe template per production-release evidence requirement so
  future operators have issue-ready starting points for non-local production
  evidence.
- Keep `release-artifacts/latest/public-beta-evidence.json` blocked/missing for
  public beta and production release until real reviewed evidence exists.
- Extend the non-local evidence checker so default validation proves the
  production-release template set is complete, unique, and limited to
  production-release requirement IDs.
- Include the templates in deterministic release-manifest/checksum coverage.
- Update docs, changelog, roadmap, and durable run state without adding live,
  audit, signer-service, private-key, or production readiness evidence.

Implementation in this branch:

- Added `release-artifacts/evidence/production-release-templates/` with one
  JSON template for each production-release requirement ID and a shared
  retained-artifact placeholder.
- Extended `scripts/check_non_local_release_evidence.py` and
  `scripts/test_non_local_release_evidence.py` to validate production-release
  template coverage, duplicates, and public-beta-only requirement mistakes.
- Updated `scripts/test_release_manifest.py` so nested production-release
  evidence templates are explicitly covered by release manifest tests.
- Updated public-beta, non-local evidence, release-readiness, tooling, release
  artifact, changelog, roadmap, and run-state docs.
- Regenerated `release-artifacts/latest/release-manifest.json`,
  `release-artifacts/latest/SHA256SUMS`, and
  `release-artifacts/latest/release-checksums.json`.

Validation completed locally at `2026-06-13 07:11 UTC`:

- `python -m py_compile scripts\check_non_local_release_evidence.py scripts\test_non_local_release_evidence.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py`.
- `python scripts\test_non_local_release_evidence.py`.
- `python scripts\check_non_local_release_evidence.py`.
- `python scripts\test_release_manifest.py`.
- `python scripts\generate_release_manifest.py`.
- `python scripts\generate_release_checksums.py` after manifest refresh.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\test_release_checksums.py`.
- `python scripts\generate_release_checksums.py --check`.
- `python scripts\test_public_beta_evidence.py`.
- `python scripts\check_public_beta_evidence.py`.
- `python scripts\test_public_beta_blocker_report.py`.
- `python scripts\generate_public_beta_blocker_report.py --check`.
- `python scripts\test_release_readiness.py`.
- `python scripts\check_release_readiness.py`.
- `python scripts\test_changelog_check.py`.
- `python scripts\check_changelog.py`.
- `rg -n "^#|^##|^###" docs\public-beta-evidence.md docs\non-local-release-evidence.md docs\release-readiness.md docs\tooling.md release-artifacts\README.md release-artifacts\evidence\production-release-templates\README.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `git diff --check`.
- `make check`.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`.

PR opened:

- PR #201 opened against `main` on head
  `f16075b6cb0c78cfa7c38d609019684e28559112`.
- CodeRabbit review requested in PR comment `4697838014`.

Final state before merge:

- PR #201 final implementation head was
  `a47870ddeee096e8f9d3212fe1579d56e3163c23`.
- GitHub Actions CI run `27460093022` passed on the final head.
- CodeRabbit status was success with no actionable comments or open review
  threads.
- PR #201 squash-merged as
  `02ce230500cb016e45b67c8dbd6710c08cadc000`.
- Issue #199 closed completed.

### PR candidate: Reconcile public beta template merge state (Queue Item 102)

Status: Merged in PR #200 on `2026-06-13`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/198`.
PR: `https://github.com/6529-Collections/6529Stream/pull/200`.
Branch: `codex/reconcile-public-beta-template-merge`.
Branch started from PR #197 squash merge commit
`2bd94683414fb86e0f9172b96d52bfef7fb58742`.

Goal:

- Mark Queue Item 101 merged in both durable state files.
- Record PR #197 final CI, CodeRabbit, and squash-merge evidence.
- Refresh roadmap Gate G wording that still described issue #195 as active or
  represented PR #196 as the latest merged baseline.
- Select Queue Item 103 / issue #199 as the next no-secret Gate G support
  slice.

Validation completed locally at `2026-06-13 06:28 UTC`:

- `python scripts\check_release_readiness.py`.
- `python scripts\check_public_beta_evidence.py`.
- `python scripts\check_non_local_release_evidence.py`.
- `python scripts\generate_public_beta_blocker_report.py --check`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\generate_release_checksums.py --check`.
- `python scripts\check_changelog.py`.
- `rg -n "Queue Item 101|Queue Item 102|Queue Item 103|PR #197|27458794705|e3034c4|2bd9468|#195|#198|#199|Last verified|CI run" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `git diff --check`.

Final state before merge:

- PR #200 final head `98b0a807a698a96748f312e0531a86991693a8c3`
  passed GitHub Actions CI run `27459177572`.
- CodeRabbit status was success with no actionable comments or open review
  threads.
- PR #200 squash-merged as
  `728eb7161c80f6b3690de45caf11fd3c9e01e277`.
- Issue #198 closed completed.

### PR candidate: Add per-requirement public beta evidence templates (Queue Item 101)

Status: Merged in PR #197 on `2026-06-13`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/195`.
PR: `https://github.com/6529-Collections/6529Stream/pull/197`.
Branch: `codex/public-beta-evidence-templates`.
Branch started from PR #196 squash merge commit
`99b0845e81c0b81bb9105c1d35970a92b47b22a0`.

Prior queue transition:

- Queue Item 100 merged in PR #196 as squash commit
  `99b0845e81c0b81bb9105c1d35970a92b47b22a0`.
- PR #196 final implementation head was
  `7db6a5c24a15848926dd91c778303169fea5b274`.
- PR #196 GitHub Actions CI run `27457583246` passed on the final head.
- PR #196 CodeRabbit status was success with no actionable comments or open
  review threads.
- PR #196 closed issue #194 at merge.
- Issue #195 is now the active Gate G support target for Queue Item 101.

Goal:

- Add one public-safe template per public-beta evidence requirement so future
  operators have issue-ready starting points for non-local evidence.
- Keep `release-artifacts/latest/public-beta-evidence.json` blocked/missing for
  public beta and production release until real reviewed evidence exists.
- Extend the non-local evidence checker so default validation proves the
  public-beta template set is complete, unique, and limited to public-beta
  requirement IDs.
- Include the templates in deterministic release-manifest/checksum coverage.
- Update docs, changelog, roadmap, and durable run state without adding fork,
  testnet, live, audit, signer-service, or private-key evidence.

Implementation in this branch:

- Added `release-artifacts/evidence/public-beta-templates/` with one JSON
  template for each public-beta requirement ID and a shared retained-artifact
  placeholder.
- Extended `scripts/check_non_local_release_evidence.py` and
  `scripts/test_non_local_release_evidence.py` to validate template coverage,
  duplicates, and production-only requirement mistakes.
- Updated `scripts/generate_release_manifest.py` and
  `scripts/test_release_manifest.py` so nested non-local evidence templates are
  included in release manifest coverage.
- Updated public-beta, non-local evidence, release-readiness, tooling, release
  artifact, changelog, roadmap, and run-state docs.
- Regenerated `release-artifacts/latest/release-manifest.json`,
  `release-artifacts/latest/SHA256SUMS`, and
  `release-artifacts/latest/release-checksums.json`.

Validation completed locally at `2026-06-13 05:58 UTC`:

- `python -m py_compile scripts\check_non_local_release_evidence.py scripts\test_non_local_release_evidence.py scripts\check_public_beta_evidence.py scripts\generate_public_beta_blocker_report.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py`.
- `python scripts\test_non_local_release_evidence.py`.
- `python scripts\check_non_local_release_evidence.py`.
- `python scripts\test_public_beta_evidence.py`.
- `python scripts\check_public_beta_evidence.py`.
- `python scripts\test_public_beta_blocker_report.py`.
- `python scripts\generate_public_beta_blocker_report.py --check`.
- `python scripts\test_release_manifest.py`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\test_release_checksums.py`.
- `python scripts\generate_release_checksums.py --check`.
- `python scripts\test_release_readiness.py`.
- `python scripts\check_release_readiness.py`.
- `python scripts\test_changelog_check.py`.
- `python scripts\check_changelog.py`.
- `rg -n "^#|^##|^###" docs\public-beta-evidence.md docs\non-local-release-evidence.md docs\release-readiness.md docs\tooling.md release-artifacts\README.md release-artifacts\evidence\public-beta-templates\README.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `git diff --check`.
- `make check`.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`.

PR opened:

- PR #197 opened against `main` on head
  `1f4b240822c80909782212dbb625a8f31ccd0665`.
  This follow-up state commit records the concrete PR URL before CodeRabbit
  review is requested.

CodeRabbit review response:

- CodeRabbit review submitted at `2026-06-13 06:10 UTC` with three actionable
  comments.
- Fixed `docs/public-beta-evidence.md` so the public-beta evidence workflow
  starts from the matching template before adding retained evidence and
  computing the `sha256:` digest.
- Changed public-beta template discovery from top-level `glob("*.json")` to
  recursive `rglob("*.json")`.
- Added non-local release evidence metadata filtering in
  `scripts/generate_release_manifest.py` so nested JSON sidecars under
  `release-artifacts/evidence/` are not treated as evidence records unless they
  carry the non-local evidence schema and required metadata keys.
- Added a release-manifest fixture sidecar JSON assertion proving non-evidence
  JSON is skipped.
- Regenerated `release-artifacts/latest/release-manifest.json`,
  `release-artifacts/latest/SHA256SUMS`, and
  `release-artifacts/latest/release-checksums.json`.

Follow-up validation completed locally at `2026-06-13 06:13 UTC`:

- `python -m py_compile scripts\check_non_local_release_evidence.py scripts\generate_release_manifest.py scripts\test_non_local_release_evidence.py scripts\test_release_manifest.py`.
- `python scripts\test_non_local_release_evidence.py`.
- `python scripts\check_non_local_release_evidence.py`.
- `python scripts\test_release_manifest.py`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\test_release_checksums.py`.
- `python scripts\generate_release_checksums.py --check`.
- `python scripts\check_release_readiness.py`.
- `python scripts\check_changelog.py`.
- `git diff --check`.

Final state before merge:

- PR #197 final head `e3034c40b211497ccbb091c7b1fc318b28e2176d`
  passed GitHub Actions CI run `27458794705`.
- CodeRabbit status was success; the original three actionable threads were
  resolved by the bot after commit
  `e3034c40b211497ccbb091c7b1fc318b28e2176d`, and the follow-up review
  generated no actionable comments.
- PR #197 squash-merged as
  `2bd94683414fb86e0f9172b96d52bfef7fb58742`.
- Issue #195 closed completed.

### PR candidate: Reconcile public beta blocker report merge state (Queue Item 100)

Status: Merged in PR #196 on `2026-06-13`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/194`.
PR: `https://github.com/6529-Collections/6529Stream/pull/196`.
Branch: `codex/reconcile-public-beta-blocker-state`.
Branch started from PR #193 squash merge commit
`69df0c1af4e63080a9c4a822e167f0284d349c74`.

Prior queue transition:

- Queue Item 99 merged in PR #193 as squash commit
  `69df0c1af4e63080a9c4a822e167f0284d349c74`.
- PR #193 final implementation head was
  `61ed7e8bc259c4daa4ac3adaeb746b96904dcbda`.
- PR #193 GitHub Actions CI run `27457209173` passed on the final head.
- PR #193 CodeRabbit status was success with no actionable comments remaining
  after the low-value metadata nitpick was fixed.
- PR #193 closed issue #191 at merge.
- Issue #195 is queued next for public-safe per-requirement public-beta
  evidence templates without changing public-beta or production readiness
  claims.

Goal:

- Mark Queue Item 99 merged in both durable state files.
- Record PR #193 final CI, CodeRabbit, and squash-merge evidence.
- Refresh stale roadmap Gate G wording that still described issue #191 as in
  progress.
- Select Queue Item 101 / issue #195 as the next no-secret Gate G support
  slice.

Validation completed locally at `2026-06-13 05:15 UTC`:

- `python scripts\check_release_readiness.py`.
- `python scripts\check_public_beta_evidence.py`.
- `python scripts\generate_public_beta_blocker_report.py --check`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\generate_release_checksums.py --check`.
- `rg -n "Queue Item 99|Queue Item 100|Queue Item 101|PR #193|27457209173|61ed7e8|69df0c1|#191|#194|#195|Issue #191|Last verified|CI run" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `git diff --check`.

PR opened:

- PR #196 opened against `main` on head
  `d1861b4a2cd8545c312a27c46c2ba0fda9f40f83`.
  This follow-up state commit records the concrete PR URL before CodeRabbit
  review is requested.
- Final state before merge:
  - PR #196 final head `7db6a5c24a15848926dd91c778303169fea5b274`
    passed GitHub Actions CI run `27457583246`.
  - CodeRabbit status was success with no actionable comments and no open
    review threads.
  - PR #196 squash-merged as
    `99b0845e81c0b81bb9105c1d35970a92b47b22a0`.
  - Issue #194 closed completed.

### PR candidate: Add public beta evidence blocker report artifact (Queue Item 99)

Status: Merged in PR #193 on `2026-06-13`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/191`.
PR: `https://github.com/6529-Collections/6529Stream/pull/193`.
Branch: `codex/public-beta-blocker-report`.
Branch started from PR #192 squash merge commit
`b222e7ef1d0a4525b00a66a9fa90b957ccdac3bd`.

Prior queue transition:

- Queue Item 98 merged in PR #192 as squash commit
  `b222e7ef1d0a4525b00a66a9fa90b957ccdac3bd`.
- PR #192 final implementation head was
  `057ae6659b4ec0b34d97bf91f89019d93fbe4964`.
- PR #192 GitHub Actions CI run `27455898124` passed on the final head.
- PR #192 CodeRabbit status was success with no actionable comments remaining.
- PR #192 closed issue #190 at merge.
- Issue #191 became the active Gate G support target for Queue Item 99.

Goal:

- Generate `release-artifacts/latest/public-beta-blockers.md` deterministically
  from `release-artifacts/latest/public-beta-evidence.json`.
- Preserve the no-secret policy and the intentionally blocked public-beta and
  production-release status.
- List incomplete public-beta and production rows, evidence posture, future
  external evidence categories, reviewed external evidence rows when present,
  and validation commands.
- Wire report drift checks into local wrappers, `make check`, and CI.
- Include the committed report in release manifest and checksum coverage.
- Update docs, changelog, roadmap, and durable run state.

Validation completed locally at `2026-06-13 04:40 UTC`:

- `python -m py_compile scripts\generate_public_beta_blocker_report.py scripts\test_public_beta_blocker_report.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_artifacts.py scripts\test_release_artifacts.py`.
- `python scripts\test_public_beta_blocker_report.py`.
- `python scripts\generate_public_beta_blocker_report.py`.
- `python scripts\generate_public_beta_blocker_report.py --check`.
- `python scripts\test_release_manifest.py`.
- `python scripts\generate_release_manifest.py`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\test_release_artifacts.py`.
- `python scripts\generate_release_checksums.py`.
- `python scripts\test_release_checksums.py`.
- `python scripts\generate_release_checksums.py --check`.
- `python scripts\check_release_readiness.py`.
- `python scripts\check_public_beta_evidence.py`.
- `python scripts\check_changelog.py`.
- `python scripts\test_release_readiness.py`.
- `python scripts\test_changelog_check.py`.
- `git diff --check`.
- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md docs\public-beta-evidence.md docs\release-readiness.md release-artifacts\README.md release-artifacts\latest\public-beta-blockers.md`.
- `bash -n scripts/check.sh`.
- PowerShell parser validation for `scripts\check.ps1`.
- `make check`.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`.

PR opened:

- PR #193 opened against `main` on head
  `21b1de2ad53792ae8c1c688964bcd6e83db988a7`.
- CodeRabbit review requested in comment `4697524739`.
- Final state before merge:
  - PR #193 implementation head `56f62b9ba879d20b599c112e49563f9625b1046e`
    passed GitHub Actions CI run `27456879641` before the final metadata
    nitpick fix.
  - CodeRabbit status passed with one low-value nitpick in review
    `4490941768`.
  - The nitpick requested deriving the blocker-report generator metadata from
    the script name and `GENERATOR_VERSION` instead of repeating a literal
    script/version string.
  - Follow-up commit `61ed7e8bc259c4daa4ac3adaeb746b96904dcbda` resolved the
    nitpick without changing the generated
    report text.
  - GitHub Actions CI run `27457209173` passed on the final head
    `61ed7e8bc259c4daa4ac3adaeb746b96904dcbda`.
  - CodeRabbit returned success with no actionable comments remaining.
  - PR #193 merged as squash commit
    `69df0c1af4e63080a9c4a822e167f0284d349c74`.
  - Issue #191 closed completed at merge.

### PR candidate: Reconcile signer custody readiness merge state (Queue Item 98)

Status: Merged in PR #192 on `2026-06-13`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/190`.
PR: `https://github.com/6529-Collections/6529Stream/pull/192`.
Branch: `codex/reconcile-signer-custody-state`.
Branch started from PR #189 squash merge commit
`ae87028d7471c35faa0bc3a3555583e24be50d4d`.

Prior queue transition:

- Queue Item 97 merged in PR #189 as squash commit
  `ae87028d7471c35faa0bc3a3555583e24be50d4d`.
- PR #189 final implementation head was
  `e0c64d91cfbcfabea7b7b89d8b1d61521c8487fa`.
- PR #189 GitHub Actions CI run `27455567547` passed on the final head.
- PR #189 CodeRabbit status was success, and all visible CodeRabbit review
  threads were resolved by the bot.
- PR #189 closed issue #187 at merge.
- Issue #190 was the active state-only reconciliation target.
- Issue #191 was queued next for a deterministic public-beta evidence blocker
  report generated from the committed evidence manifest without changing any
  public-beta or production readiness claims.
- PR #192 final implementation head was
  `057ae6659b4ec0b34d97bf91f89019d93fbe4964`.
- PR #192 GitHub Actions CI run `27455898124` passed on the final head.
- PR #192 CodeRabbit status was success with no actionable comments remaining.
- PR #192 merged as squash commit
  `b222e7ef1d0a4525b00a66a9fa90b957ccdac3bd`.

Goal:

- Mark Queue Item 97 merged in both durable state files.
- Record PR #189 final CI, CodeRabbit, and squash-merge evidence.
- Refresh stale roadmap verification metadata that still referenced PR #188 or
  the initial PR #189 CI run.
- Select Queue Item 99 as the next no-secret Gate G support slice.

Validation completed locally at `2026-06-13 03:53 UTC`:

- `rg -n "Queue Item 97|Queue Item 98|Queue Item 99|PR #189|27455567547|ae87028d|#191" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`.
- `git diff --check`.

### PR candidate: Add drop authorization signing evidence schema and checker (Queue Item 95)

Status: Merged in PR #185 on `2026-06-13`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/183`.
PR: `https://github.com/6529-Collections/6529Stream/pull/185`.
Branch: `codex/drop-signing-evidence-schema`.
Branch started from PR #184 squash merge commit
`1a6b0691165c6f21b31a16c2ef4cd1d3456d34a9`.
Implementation head at PR open:
`ca4866616e335c374afb144269cc611a26bd232e`.

Prior queue transition:

- Queue Item 94 merged in PR #184 as squash commit
  `1a6b0691165c6f21b31a16c2ef4cd1d3456d34a9`.
- PR #184 final implementation head was
  `964eabe1e5a959d699f10ebf7f13c446e9838d5d`.
- PR #184 GitHub Actions CI run `27451124264` passed on the final head.
- PR #184 CodeRabbit reported no actionable comments after explicit review
  request `4696769792`.
- PR #184 closed issue #182 at merge.
- Issue #183 is the next no-secret implementation target for retained drop
  authorization signing evidence.

Goal:

- Add a no-secret retained drop authorization signing evidence schema and
  checked local template.
- Validate the evidence against the generated unsigned drop authorization
  payload output, signer identity, signer epoch, typed-data domain/message
  fields, retained artifact hashes, review status, signature status, and
  no-secret policy.
- Wire the checker into local and CI gates, release manifest generation,
  release checksum coverage, release-readiness/audit/incident-response docs,
  and the roadmap.
- Preserve the distinction between a local checked template and actual
  fork/testnet/live production signer custody or signing evidence.

Validation target:

- `python -m py_compile scripts\check_drop_authorization_signing_evidence.py scripts\test_drop_authorization_signing_evidence.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py`.
- `python scripts\test_drop_authorization_signing_evidence.py`.
- `python scripts\check_drop_authorization_signing_evidence.py`.
- `python scripts\test_release_manifest.py`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\test_release_checksums.py`.
- `python scripts\generate_release_checksums.py --check`.
- `python scripts\test_release_readiness.py`.
- `python scripts\check_release_readiness.py`.
- `python scripts\test_audit_package.py`.
- `python scripts\check_audit_package.py`.
- `python scripts\test_incident_response.py`.
- `python scripts\check_incident_response.py`.
- `python scripts\check_changelog.py`.
- `git diff --check`.
- Full `make check` before opening the PR.

Local validation:

- `python -m py_compile scripts\check_drop_authorization_signing_evidence.py scripts\test_drop_authorization_signing_evidence.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py scripts\test_release_readiness.py`.
- `python scripts\test_drop_authorization_signing_evidence.py`.
- `python scripts\check_drop_authorization_signing_evidence.py`.
- `python scripts\test_release_manifest.py`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\test_release_checksums.py`.
- `python scripts\generate_release_checksums.py --check`.
- `python scripts\test_release_readiness.py`.
- `python scripts\check_release_readiness.py`.
- `python scripts\test_audit_package.py`.
- `python scripts\check_audit_package.py`.
- `python scripts\test_incident_response.py`.
- `python scripts\check_incident_response.py`.
- `python scripts\test_drop_authorization_payload_generator.py`.
- `python scripts\test_drop_authorization_fixtures.py`.
- `python scripts\check_drop_authorization_fixtures.py`.
- `python scripts\test_public_beta_evidence.py`.
- `python scripts\check_public_beta_evidence.py`.
- `python scripts\test_non_local_release_evidence.py`.
- `python scripts\check_non_local_release_evidence.py`.
- `python scripts\test_changelog_check.py`.
- `python scripts\check_changelog.py`.
- `git diff --check`.
- `make check`.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`.

Remote validation:

- PR #185 opened at
  `https://github.com/6529-Collections/6529Stream/pull/185`.
- CodeRabbit review requested in issue comment `4696975873`.
- GitHub Actions CI run `27452741736` passed on head
  `a45232dd0f685ca8e37b7baaeac746e36fcf1c2e`.

CodeRabbit follow-up:

- Added a maintainer note for the intentional `SECRET_KEY_RE` final-segment
  `secret` match and whitelist process.
- Added regression coverage for `record_type="evidence"` paired with
  `review_status="template"`.
- Aligned the release-manifest test fixture redaction list with the committed
  drop authorization signing evidence template by adding `seed_phrase`.

Follow-up validation:

- `python -m py_compile scripts\check_drop_authorization_signing_evidence.py scripts\test_drop_authorization_signing_evidence.py scripts\test_release_manifest.py`.
- `python scripts\test_drop_authorization_signing_evidence.py`.
- `python scripts\check_drop_authorization_signing_evidence.py`.
- `python scripts\test_release_manifest.py`.
- `python scripts\generate_release_manifest.py --check`.

Second CodeRabbit follow-up:

- Replaced time-relative PR-creation wording in `ops/ROADMAP.md` with dated
  PR #185 CI evidence and local-baseline wording.
- Rephrased the docs public-beta requirement to avoid implying a completed
  third-party review before external audit evidence exists.
- Enforced non-negative payload numeric fields and signing identity signer
  epoch in the drop authorization signing evidence checker, matching the JSON
  schema minimums.
- Added regression coverage for negative payload numeric fields and negative
  signing identity signer epoch.
- Documented `release-artifacts/schema/` release-checksum coverage in
  `docs/tooling.md`.
- Linked the drop authorization signing evidence schema and retained-artifact
  placeholder directly from the signer-compromise incident runbook.

Final remote validation:

- PR #185 final implementation head
  `fa1a6e949558dc7178564da179d576047ac428a9` passed GitHub Actions CI run
  `27453065590`.
- CodeRabbit aggregate status was success, and all visible review threads were
  resolved.
- Squash merge commit:
  `fd453a652d228c3e43002aca27f72e1d86cd53d9`.
- Issue #183 closed completed at merge.

### PR candidate: Reconcile autonomous run state after drop authorization payload generator merge (Queue Item 94)

Status: Merged in PR #184 on `2026-06-13`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/182`.
PR: `https://github.com/6529-Collections/6529Stream/pull/184`.
Branch: `codex/reconcile-payload-generator-merge`.
Branch started from PR #181 squash merge commit
`97800f4570740c7aefd88e407cb78e47ee5e80db`.
Implementation head at PR open:
`2a4433de540cecb57079583b97a57d8284abb6b0`.
Final implementation head:
`964eabe1e5a959d699f10ebf7f13c446e9838d5d`.
Squash merge commit:
`1a6b0691165c6f21b31a16c2ef4cd1d3456d34a9`.

Prior queue transition:

- Queue Item 93 merged in PR #181 as squash commit
  `97800f4570740c7aefd88e407cb78e47ee5e80db`.
- PR #181 final implementation head was
  `423988b440272f564f924df5b402a50eeaa10ef8`.
- PR #181 GitHub Actions CI run `27450665978` passed on the final head.
- PR #181 CodeRabbit status was success after the visible actionable comments
  were fixed and the final review reported no actionable comments.
- PR #181 closed issue #180 at merge.
- Issue #182 was created as a state-only reconciliation issue before the next
  implementation slice.
- Issue #183 was created as the next no-secret implementation target for drop
  authorization signing evidence.

Goal:

- Keep the durable autonomous run state truthful after PR #181.
- Record the PR #181 merge, final head, CI evidence, and CodeRabbit outcome.
- Select Queue Item 95 as the next safe no-secret Gate G/Gate C support slice.
- Avoid Solidity, CI, release artifact, or production-readiness changes in this
  state-only PR.

Validation target:

- `git diff --check`.
- Heading scan if broader Markdown sections change.
- CodeRabbit and GitHub Actions must be clean before merge.

Local validation:

- `git diff --check`.
- `rg -n "^#|^##|^###" ops\AUTONOMOUS_RUN.md`.

Remote validation:

- PR #184 opened at
  `https://github.com/6529-Collections/6529Stream/pull/184`.
- CodeRabbit review requested in issue comment `4696769792`.
- GitHub Actions CI run `27451124264` passed on final head
  `964eabe1e5a959d699f10ebf7f13c446e9838d5d`.
- CodeRabbit reported no actionable comments.

### PR candidate: Add no-secret drop authorization payload generator tooling (Queue Item 93)

Status: Merged in PR #181 on `2026-06-13 00:29:20 UTC`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/180`.
PR: `https://github.com/6529-Collections/6529Stream/pull/181`.
Branch: `codex/drop-authorization-payload-generator`.
Branch started from PR #179 squash merge commit
`3e0eedfb31ebac5d5d71c4cb0845e6882c992d9e`.
Implementation head at PR open:
`01103c164b0272fa8db7e67c68f1e01b2bd60b2e`.
Final implementation head:
`423988b440272f564f924df5b402a50eeaa10ef8`.
Squash merge commit:
`97800f4570740c7aefd88e407cb78e47ee5e80db`.

Prior queue transition:

- Queue Item 92 merged in PR #179 as squash commit
  `3e0eedfb31ebac5d5d71c4cb0845e6882c992d9e`.
- PR #179 CodeRabbit review completed after one actionable comment was fixed;
  CodeRabbit resolved the thread and status was success on the latest head.
- PR #179 GitHub Actions CI run `27448523471` passed on head
  `99bf1f3044d0760da07903701419075a463caaf6`.
- Issue #177 closed completed at merge.
- Issue #180 created as the next local tooling slice because no open roadmap
  issues remained.

Goal:

- Add a no-secret CLI or equivalent script that generates canonical unsigned
  EIP-712 drop authorization payload JSON for fixed-price and auction drops.
- Reuse the accepted domain/message field order and derived-hash semantics from
  `scripts/check_drop_authorization_fixtures.py`.
- Emit or write `dropId`, `tokenDataHash`, `domainSeparator`, `structHash`, and
  `digest` for downstream signer comparison without accepting private keys.
- Add focused tests for generation, sale-mode constraints, zero-address
  rejection, stale/missing fields, and no-secret policy.
- Link the tool from signing, tooling, known-blocker, release-readiness, audit,
  and roadmap docs as appropriate.
- Do not change Solidity behavior or claim production signer custody/readiness.

Validation target:

- Focused generator tests and existing drop-authorization fixture tests.
- Updated docs/checker gates if the new tool becomes part of maintained release
  evidence.
- `git diff --check`.
- `make check` before PR unless an implementation-specific blocker is recorded
  here.

Implementation summary:

- Added `scripts/generate_drop_authorization_payload.py` as a no-secret CLI for
  canonical unsigned fixed-price and auction EIP-712 payload artifacts.
- Added deterministic fixed-price and auction input/output examples under
  `test/fixtures/drop-authorization/payload-generator/`.
- Added `scripts/test_drop_authorization_payload_generator.py` coverage for
  committed-output drift, signed-fixture hash parity, sale-mode address rules,
  stale output detection, missing fields, and secret-shaped input rejection.
- Wired the generator into `make check`, Windows and Unix check scripts,
  GitHub Actions, release-readiness/audit/incident/drop-authorization checkers,
  release manifest/checksum artifacts, docs, changelog, and roadmap status.

Local validation:

- `python -m py_compile scripts\generate_drop_authorization_payload.py scripts\test_drop_authorization_payload_generator.py scripts\check_drop_authorization_fixtures.py scripts\check_audit_package.py scripts\check_incident_response.py scripts\check_release_readiness.py`
- `python scripts\test_drop_authorization_payload_generator.py`
- `python scripts\generate_drop_authorization_payload.py --input test\fixtures\drop-authorization\payload-generator\fixed-price-input.json --output test\fixtures\drop-authorization\payload-generator\fixed-price-output.json --check`
- `python scripts\generate_drop_authorization_payload.py --input test\fixtures\drop-authorization\payload-generator\auction-input.json --output test\fixtures\drop-authorization\payload-generator\auction-output.json --check`
- `python scripts\test_drop_authorization_fixtures.py`
- `python scripts\check_drop_authorization_fixtures.py`
- `python scripts\test_audit_package.py`
- `python scripts\check_audit_package.py`
- `python scripts\test_incident_response.py`
- `python scripts\check_incident_response.py`
- `python scripts\test_release_readiness.py`
- `python scripts\check_release_readiness.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\check_changelog.py`
- `git diff --check` passed with only the existing `scripts/check.ps1` LF/CRLF
  warning.
- `make check`

Remote validation:

- PR #181 opened at
  `https://github.com/6529-Collections/6529Stream/pull/181`.
- GitHub Actions run `27449982026` failed at the release-checksum step after
  all earlier gates passed. Root cause: the payload generator used default
  Windows text newlines when writing generated output JSON, while CI checks the
  LF-normalized checkout contents. Fix: pin generated output writes to
  `newline="\n"` and regenerate the checksum bundle.
- Local validation after the CI fix: payload generator tests, both payload
  `--check` commands, `python scripts/generate_release_checksums.py --check`,
  `git diff --check`, and `make check`.
- CodeRabbit review `4489993973` reported three actionable comments:
  mirror payload-generator checks in `docs/audit-package.md` maintenance
  commands, pass generated typed data rather than only the digest to the
  approved signing system in `docs/incident-response.md`, and preserve the
  generator CLI exception chain. All three were fixed locally.
- Local validation after CodeRabbit fixes: generator tests, audit-package tests
  and checker, incident-response tests and checker, release manifest/checksum
  drift checks, `git diff --check`, and `make check`.
- GitHub Actions CI run `27450665978` passed on final head
  `423988b440272f564f924df5b402a50eeaa10ef8`.
- CodeRabbit final status was success and the final review reported no
  actionable comments.

Outcome:

- Merged as PR #181 on `2026-06-13 00:29:20 UTC`.
- Squash commit: `97800f4570740c7aefd88e407cb78e47ee5e80db`.
- Issue #180 closed completed.

### PR candidate: Add drop authorization signing examples and fixtures (Queue Item 92)

Status: merged in PR #179 as
`3e0eedfb31ebac5d5d71c4cb0845e6882c992d9e`; issue #177 closed completed.
Issue: `https://github.com/6529-Collections/6529Stream/issues/177`.
PR: `https://github.com/6529-Collections/6529Stream/pull/179`.
Branch: `codex/drop-authorization-signing-examples`.
Branch started from PR #178 squash merge commit
`0122e670889df63f5359b7add2ac7f68b1ed9a31`.
Implementation head at PR open:
`0e3b1d10e98cdb439cd04e9ca78fd34175760887`.
Current head after run-state update:
`c26c05ad52174ec343794c78bd281483cbc19404`.
Final head:
`99bf1f3044d0760da07903701419075a463caaf6`.
Squash merge commit:
`3e0eedfb31ebac5d5d71c4cb0845e6882c992d9e`.

Prior queue transition:

- Queue Item 91 merged in PR #178 as squash commit
  `0122e670889df63f5359b7add2ac7f68b1ed9a31`.
- PR #178 CodeRabbit review completed with no actionable comments.
- PR #178 Foundry smoke passed in CI run `27445968474`.
- Issue #176 closed completed at merge.

Goal:

- Add no-secret operator-facing EIP-712 drop authorization signing examples.
- Add deterministic fixed-price, auction, and ERC-1271/mock contract-signer
  fixtures that expose the signed domain, message, expected digest, expected
  signature result, and failure expectations without production private keys.
- Add a lightweight checker and tests that validate fixture shape, required
  domain/message fields, digest/signature format, no-secret redaction, and
  documentation links.
- Link the guide from release, tooling, audit, incident-response, known-blocker,
  and roadmap surfaces.
- Refresh release manifest/checksum artifacts if the new guide or fixtures are
  release-manifest inputs.
- Do not change Solidity behavior.

Local validation:

- `python scripts\test_drop_authorization_fixtures.py`.
- `python scripts\check_drop_authorization_fixtures.py`.
- `python scripts\test_audit_package.py`.
- `python scripts\check_audit_package.py`.
- `python scripts\test_incident_response.py`.
- `python scripts\check_incident_response.py`.
- `python scripts\test_release_readiness.py`.
- `python scripts\check_release_readiness.py`.
- `python scripts\test_release_manifest.py`.
- `python scripts\generate_release_manifest.py --check`.
- `python scripts\test_release_checksums.py`.
- `python scripts\generate_release_checksums.py --check`.
- `git diff --check`.
- `make check` passed after regenerating release manifest/checksum artifacts for
  the changelog and signing-fixture coverage.

Remote validation:

- PR #179 opened at `2026-06-12T23:02:17Z`.
- CodeRabbit review requested in issue comment `4696228472`.
- GitHub Actions run `27448102609` passed before the CodeRabbit fix commit.
- CodeRabbit status passed pre-merge checks, then posted one actionable thread
  requiring `poster` to be rejected when zero in the signing fixture validator.
- Local fix validation:
  - `python -m py_compile scripts\check_drop_authorization_fixtures.py scripts\test_drop_authorization_fixtures.py`.
  - `python scripts\test_drop_authorization_fixtures.py`.
  - `python scripts\check_drop_authorization_fixtures.py`.
  - `git diff --check`.
- GitHub Actions run `27448523471` passed on the final head.
- CodeRabbit marked the actionable thread addressed by commit `99bf1f3` and
  resolved it.

### PR candidate: Add protocol incident response runbooks (Queue Item 90)

Status: merged in PR #175 as
`4be2808e9e6f654143794d4db29f455eabff3a70`; issue #173 closed completed.
Issue: `https://github.com/6529-Collections/6529Stream/issues/173`.
PR: `https://github.com/6529-Collections/6529Stream/pull/175`.
CodeRabbit request: issue comment `4695671204`.
Branch: `codex/protocol-incident-response-runbooks`.
Branch started from PR #174 squash merge commit
`074ac3eb510ccafa593812677e6c26cbed4171b1`.
Head before CodeRabbit follow-up:
`08466151647bed25277feb454191f88d00609da7`.
Final head: `574804b6421c5658001839d483dd5a24dcbb2ad8`.
Squash merge commit: `4be2808e9e6f654143794d4db29f455eabff3a70`.
CI run: `27445423380`.
CodeRabbit status: success; one minor alignment thread resolved by the bot.

Goal:

- Add a no-secret protocol incident-response runbook for stuck auctions,
  failed or stale randomness, bad Merkle roots, curator claims, bad
  metadata/dependency configuration, signer compromise, drop-pause decisions,
  and release artifact/evidence mistakes from issue #173.
- Tie incident procedures to existing pause, signer, randomizer, auction,
  dependency, release-readiness, and evidence-retention docs.
- Add a lightweight docs checker/test only if it matches the repository's
  existing documentation gate pattern.
- Link the runbook from security, release-readiness, tooling, randomizer,
  dependency, roadmap, and any release/governance surfaces that need it.
- Keep the change documentation/tooling-only with no Solidity behavior changes.

Initial candidate files:

- `docs/incident-response.md`
- `scripts/check_incident_response.py`
- `scripts/test_incident_response.py`
- `Makefile`
- `.github/workflows/ci.yml`
- `scripts/check.sh`
- `scripts/check.ps1`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `scripts/generate_release_checksums.py`
- `scripts/test_release_checksums.py`
- `docs/release-readiness.md`
- `docs/tooling.md`
- `docs/randomizer-operations.md`
- `docs/dependency-operations.md`
- `SECURITY.md`
- `release-artifacts/README.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation target:

- `python scripts/test_incident_response.py`
- `python scripts/check_incident_response.py`
- `python scripts/test_release_readiness.py`
- `python scripts/check_release_readiness.py`
- `python scripts/test_release_manifest.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/test_release_checksums.py`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/check_changelog.py`
- `bash -n scripts/check.sh`
- PowerShell parse check for `scripts/check.ps1`
- `python -m py_compile` for touched scripts/tests
- `rg -n "^#|^##|^###" docs\incident-response.md docs\release-readiness.md docs\tooling.md docs\randomizer-operations.md docs\dependency-operations.md SECURITY.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `git diff --check`
- `make check`

Remote validation:

- Initial GitHub Actions CI run `27444730234` passed on head
  `08466151647bed25277feb454191f88d00609da7`.
- CodeRabbit requested two alignment fixes; follow-up commit
  `db49a0e73f6a840cdea8b59876cf27b8af34a2ad` added curator-claim/drop-pause
  wording and synchronized the release-readiness local/CI gates row.
- GitHub Actions CI run `27445168296` failed because the release-readiness
  wording changed governance-document hashes without regenerating release
  manifest/checksum artifacts.
- Follow-up commit `574804b6421c5658001839d483dd5a24dcbb2ad8` refreshed the
  release manifest and checksum artifacts.
- Final GitHub Actions CI run `27445423380` passed on head
  `574804b6421c5658001839d483dd5a24dcbb2ad8`.
- CodeRabbit status was success; the visible review thread was resolved by the
  bot, and all five pre-merge checks passed.
- PR #175 squash-merged as
  `4be2808e9e6f654143794d4db29f455eabff3a70`; issue #173 closed completed.

Implementation notes:

- Added `docs/incident-response.md` as a no-secret operator runbook for
  severity classification, universal triage, evidence retention, reopening,
  and post-incident review.
- Covered stuck auctions or settlement, failed/stale randomness, bad Merkle
  roots or curator claims, bad metadata/dependency configuration, signer
  compromise/drop authorization, and release artifact/evidence mistakes.
- Added `scripts/check_incident_response.py` and
  `scripts/test_incident_response.py` to enforce required headings, maturity
  language, no-secret/private-reporting guidance, local commands, and links.
- Wired the new gate into `Makefile`, CI, `scripts/check.sh`, and
  `scripts/check.ps1`.
- Linked the runbook from security, release readiness, tooling, randomizer
  operations, dependency operations, audit package, roadmap, and release
  artifact documentation.
- Added the runbook to release-manifest governance docs, regenerated the
  latest release manifest/checksum artifacts, and updated the changelog.

Validation completed locally:

- `python scripts/test_incident_response.py`
- `python scripts/check_incident_response.py`
- `python scripts/test_release_readiness.py`
- `python scripts/check_release_readiness.py`
- `python scripts/test_audit_package.py`
- `python scripts/check_audit_package.py`
- `python scripts/test_release_manifest.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/test_release_checksums.py`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/check_changelog.py`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts/check.ps1`
- `python -m py_compile` for touched scripts/tests
- `rg -n "^#|^##|^###" docs\incident-response.md docs\release-readiness.md docs\tooling.md docs\randomizer-operations.md docs\dependency-operations.md SECURITY.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `git diff --check`
- `make check`

### PR candidate: Reconcile Gate G roadmap after non-local evidence schema merge (Queue Item 89)

Status: merged in PR #174 as
`074ac3eb510ccafa593812677e6c26cbed4171b1`; issue #172 closed completed.
Issue: `https://github.com/6529-Collections/6529Stream/issues/172`.
PR: `https://github.com/6529-Collections/6529Stream/pull/174`.
CodeRabbit request: issue comment `4695446245`.
Branch: `codex/reconcile-nonlocal-evidence-schema`.
Branch started from PR #171 squash merge commit
`6a5a2f96b8196c2387eda3ed3187cbde2616f9cb`.
Final head: `55b7dc716c5bfdd9e003d5b068f24ba7dfb5eddd`.
Squash merge commit: `074ac3eb510ccafa593812677e6c26cbed4171b1`.
CI run: `27442981046`.
CodeRabbit status: success; no actionable comments.

Goal:

- Mark Queue Item 88 and PR #171 as merged with final CI and CodeRabbit
  evidence.
- Refresh stale `ops/ROADMAP.md` verification metadata from pending PR #171
  state to merged PR #171 state.
- Record that issue #170 closed completed after the squash merge.
- Add Queue Item 90 for issue #173 so the autonomous run can continue into
  protocol incident-response runbooks after this reconciliation.
- Keep the change documentation/state-only with no Solidity, tooling, or
  release-artifact behavior changes.

Initial candidate files:

- `ops/AUTONOMOUS_RUN.md`
- `ops/ROADMAP.md`

Validation target:

- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `python scripts/check_release_readiness.py`
- `python scripts/check_public_beta_evidence.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/check_changelog.py`
- `git diff --check`

Remote validation:

- GitHub Actions CI run `27442981046` passed on final head
  `55b7dc716c5bfdd9e003d5b068f24ba7dfb5eddd`.
- CodeRabbit status was success, the bot reported no actionable comments, and
  all five pre-merge checks passed.
- PR #174 squash-merged as
  `074ac3eb510ccafa593812677e6c26cbed4171b1`; issue #172 closed completed.

Implementation notes so far:

- Recorded PR #171 merge commit
  `6a5a2f96b8196c2387eda3ed3187cbde2616f9cb`, final head
  `7050e0ea474c507126c4d2e11744e8b61fd3ab52`, CI run `27442075849`,
  CodeRabbit success with no actionable comments, and issue #170 closure.
- Created issue #173 for the next no-secret operational runbook slice and added
  it as Queue Item 90.
- Refreshed roadmap verification metadata to reference the completed PR #171
  Linux CI run instead of pending PR state.
- Opened PR #174 against `main`, linked `Closes #172`, and requested
  CodeRabbit review in comment `4695446245`.

Validation completed locally:

- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `python scripts/check_release_readiness.py`
- `python scripts/check_public_beta_evidence.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/check_changelog.py`
- `git diff --check`

### PR candidate: Add non-local release evidence metadata schema and checker (Queue Item 88)

Status: merged in PR #171 as
`6a5a2f96b8196c2387eda3ed3187cbde2616f9cb`; issue #170 closed completed.
Issue: `https://github.com/6529-Collections/6529Stream/issues/170`.
PR: `https://github.com/6529-Collections/6529Stream/pull/171`.
CodeRabbit request: issue comment `4695302692`.
Branch: `codex/nonlocal-evidence-schema-checker`.
Branch started from PR #169 squash merge commit
`1d55df3bfb59ef30b833f751e60b3f77801ae860`.
Final head: `7050e0ea474c507126c4d2e11744e8b61fd3ab52`.
Squash merge commit: `6a5a2f96b8196c2387eda3ed3187cbde2616f9cb`.
CI run: `27442075849`.
CodeRabbit status: success; no actionable comments.

Goal:

- Add a machine-checkable schema for the non-local release evidence metadata
  required by `docs/non-local-release-evidence.md`.
- Commit a no-secret example/template that is explicitly not completion evidence
  and cannot be confused with fork/testnet/mainnet readiness.
- Add a focused checker and tests that validate required fields, supported
  environments, retained paths, hashes, reviewer state, requirement IDs,
  path boundaries, and secret-like keys/values.
- Wire the checker into local/CI gates, platform wrappers, docs, release
  manifest/checksum coverage, roadmap, changelog, and durable run state.
- Keep the change docs/tooling/artifact-only with no Solidity behavior changes
  and no real non-local evidence.

Initial candidate files:

- `release-artifacts/schema/non-local-release-evidence.schema.json`
- `release-artifacts/evidence/non-local-release-evidence-template.json`
- `release-artifacts/evidence/non-local-template-retained-artifact.txt`
- `scripts/check_non_local_release_evidence.py`
- `scripts/test_non_local_release_evidence.py`
- `Makefile`
- `.github/workflows/ci.yml`
- `scripts/check.sh`
- `scripts/check.ps1`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `scripts/generate_release_checksums.py`
- `scripts/test_release_checksums.py`
- `docs/non-local-release-evidence.md`
- `docs/public-beta-evidence.md`
- `docs/release-readiness.md`
- `docs/tooling.md`
- `release-artifacts/README.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation target:

- `python scripts/test_non_local_release_evidence.py`
- `python scripts/check_non_local_release_evidence.py`
- `python scripts/test_public_beta_evidence.py`
- `python scripts/check_public_beta_evidence.py`
- `python scripts/test_release_manifest.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/test_release_checksums.py`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/check_release_readiness.py`
- `python scripts/test_changelog_check.py`
- `python scripts/check_changelog.py`
- `bash -n scripts/check.sh`
- PowerShell parse check for `scripts/check.ps1`
- `python -m py_compile` for touched release evidence, manifest, and checksum scripts/tests
- `git diff --check`
- `make check`

Remote validation:

- GitHub Actions CI run `27442075849` passed on final head
  `7050e0ea474c507126c4d2e11744e8b61fd3ab52`.
- CodeRabbit status was success, the bot reported no actionable comments, and
  no unresolved review threads remained.
- PR #171 squash-merged as
  `6a5a2f96b8196c2387eda3ed3187cbde2616f9cb`; issue #170 closed completed.

Implementation notes:

- Added `release-artifacts/schema/non-local-release-evidence.schema.json`,
  `release-artifacts/evidence/non-local-release-evidence-template.json`, and
  `release-artifacts/evidence/non-local-template-retained-artifact.txt`.
- Added `scripts/check_non_local_release_evidence.py` and
  `scripts/test_non_local_release_evidence.py`; the checker validates exact
  fields, supported environments, chain ID policy, public-beta requirement IDs,
  retained path boundaries, retained artifact hashes, template/reviewed status,
  reviewer requirements, source metadata, redaction policy, and secret-shaped
  keys/values.
- Wired `non-local-release-evidence-check` into `Makefile`, `scripts/check.sh`,
  `scripts/check.ps1`, and GitHub Actions CI between release-signature evidence
  and public-beta evidence.
- Integrated non-local evidence metadata into
  `scripts/generate_release_manifest.py` and release-manifest tests, including
  validation-before-indexing and a negative invalid-metadata regression.
- Added `release-artifacts/evidence/` to release checksum coverage and checksum
  tests.
- Updated operator docs, release-artifacts README, roadmap, changelog, release
  manifest, checksum files, and run state without Solidity changes.

Validation completed locally:

- `python scripts/test_non_local_release_evidence.py`
- `python scripts/check_non_local_release_evidence.py`
- `python scripts/test_public_beta_evidence.py`
- `python scripts/check_public_beta_evidence.py`
- `python scripts/test_release_manifest.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/test_release_checksums.py`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/test_release_readiness.py`
- `python scripts/check_release_readiness.py`
- `python scripts/test_changelog_check.py`
- `python scripts/check_changelog.py`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts/check.ps1`
- `python -m py_compile scripts\check_non_local_release_evidence.py scripts\test_non_local_release_evidence.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py scripts\test_release_checksums.py`
- `git diff --check`
- `make check`

### PR candidate: Add non-local release evidence intake runbook (Queue Item 87)

Status: merged in PR #169 as
`1d55df3bfb59ef30b833f751e60b3f77801ae860`; issue #168 closed completed.
Issue: `https://github.com/6529-Collections/6529Stream/issues/168`.
PR: `https://github.com/6529-Collections/6529Stream/pull/169`.
CodeRabbit request: issue comment `4694642716`.
Branch: `codex/nonlocal-release-evidence-runbook`.
Branch started from PR #167 squash merge commit
`e11dc44ee5eb33f95fede07d6a4045d44d4faa87`.

Goal:

- Add `docs/non-local-release-evidence.md` as the operator-facing intake
  runbook for fork/testnet/live deployment, metadata-browser, ceremony,
  randomizer, verification, address-book, gas, invariant, audit, and
  signed-release evidence.
- Require every retained non-local artifact to carry environment, chain ID,
  block/reference, command/source system, retained path, sha256, redaction
  statement, owner, reviewer, and public-beta requirement ID.
- Link the runbook from release-readiness, release policy, tooling,
  public-beta evidence docs, roadmap, and autonomous state.
- Treat the runbook as a release governance document in the generated release
  manifest and checksum bundle.
- Keep the change documentation/tooling/artifact-only with no Solidity behavior
  changes.

Initial candidate files:

- `docs/non-local-release-evidence.md`
- `docs/release-readiness.md`
- `docs/release-policy.md`
- `docs/public-beta-evidence.md`
- `docs/tooling.md`
- `release-artifacts/README.md`
- `scripts/check_release_readiness.py`
- `scripts/test_release_readiness.py`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation target:

- `python scripts/test_release_readiness.py`
- `python scripts/check_release_readiness.py`
- `python scripts/test_release_manifest.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/check_public_beta_evidence.py`
- `python scripts/check_changelog.py`
- `rg -n "^#|^##|^###" docs\non-local-release-evidence.md docs\release-readiness.md docs\public-beta-evidence.md docs\release-policy.md docs\tooling.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `git diff --check`

Implementation notes so far:

- Added the non-local release evidence runbook with evidence families, required
  retained artifact fields, no-secret checklist, reviewer standard, and
  `public-beta-evidence.json` requirement mapping.
- Added the runbook to release-readiness required phrases and required links.
- Added the runbook to release-manifest governance docs and test fixtures.
- Linked the runbook from release-readiness, release policy, public-beta
  evidence docs, tooling docs, release-artifacts docs, and roadmap.
- Added a changelog entry for the release governance/process change.
- Opened PR #169 against `main` and requested CodeRabbit review.
- GitHub Actions CI run `27438712570` failed repository hygiene on an extra
  blank line at EOF in `docs/non-local-release-evidence.md`; trimmed the EOF
  and regenerated release manifest/checksum artifacts.
- CodeRabbit review `4488726267` requested three fixes: include
  `production_broadcast_retention` and `production_address_books` in the
  non-local evidence runbook gate, clarify checksum-backed production signing
  language in the roadmap, and describe `docs/non-local-release-evidence.md` as
  a maintained governance input rather than a generated artifact.
- Added checker enforcement for complete runbook-governed
  `public-beta-evidence.json` rows: they now need reviewed JSON runbook
  metadata with matching requirement ID, required artifact fields, and a
  non-`TBD` reviewer. Added focused tests for production address-book and
  broadcast-retention rows while preserving accepted-risk behavior.
- Regenerated `release-artifacts/latest/release-manifest.json`,
  `release-artifacts/latest/SHA256SUMS`, and
  `release-artifacts/latest/release-checksums.json` after the CodeRabbit
  follow-up.

Validation so far:

- `python scripts/test_release_readiness.py`
- `python scripts/check_release_readiness.py`
- `python scripts/test_release_manifest.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/check_public_beta_evidence.py`
- `python scripts/check_changelog.py`
- `python -m py_compile scripts\check_release_readiness.py scripts\test_release_readiness.py scripts\generate_release_manifest.py scripts\test_release_manifest.py`
- `rg -n "^#|^##|^###" docs\non-local-release-evidence.md docs\release-readiness.md docs\public-beta-evidence.md docs\release-policy.md docs\tooling.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `git diff --check`
- `make check`
- Post-CI-hygiene fix: `git diff --check`,
  `python scripts/generate_release_manifest.py --check`,
  `python scripts/generate_release_checksums.py --check`,
  `python scripts/check_release_readiness.py`,
  `python scripts/test_release_readiness.py`, and
  `python scripts/check_changelog.py`
- CodeRabbit follow-up: `python scripts/test_public_beta_evidence.py`,
  `python scripts/check_public_beta_evidence.py`,
  `python scripts/test_release_manifest.py`,
  `python scripts/generate_release_manifest.py --check`,
  `python scripts/generate_release_checksums.py --check`,
  `python scripts/check_release_readiness.py`,
  `python scripts/test_release_readiness.py`,
  `python scripts/check_changelog.py`,
  `python -m py_compile scripts\check_public_beta_evidence.py scripts\test_public_beta_evidence.py scripts\check_release_readiness.py scripts\test_release_readiness.py scripts\generate_release_manifest.py scripts\test_release_manifest.py`,
  `rg -n "^#|^##|^###" docs\non-local-release-evidence.md docs\release-readiness.md docs\public-beta-evidence.md docs\release-policy.md docs\tooling.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`,
  `git diff --check`, and `make check`

### PR #167: Reconcile Gate G roadmap after public beta evidence merge (Queue Item 86)

Status: Merged in PR #167 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/166`.
PR: `https://github.com/6529-Collections/6529Stream/pull/167`.
Branch: `codex/reconcile-gate-g-roadmap`.
Branch started from PR #165 squash merge commit
`5e9a6c9f5afb569151b74b2095ef180cbbcfe884`.
Final head: `820eb1ac09cbfe1bb2347a60986f50e8ef8455c0`.
Squash merge commit: `e11dc44ee5eb33f95fede07d6a4045d44d4faa87`.
CI run: `27437060820`.
CodeRabbit status: success.

Goal:

- Mark Queue Item 85 and PR #165 as merged with final CI and CodeRabbit
  evidence.
- Refresh stale `ops/ROADMAP.md` verification metadata from PR #162/Queue Item
  84 to PR #165.
- Remove closed issue #164 from active Gate G blockers while preserving the
  public-beta and production-release blocked status.
- Add the next planned non-local evidence queue item so the run can continue
  from repo state after this reconciliation.
- Keep the change documentation/state-only.

Initial candidate files:

- `ops/AUTONOMOUS_RUN.md`
- `ops/ROADMAP.md`

Validation target:

- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `git diff --check`
- `python scripts\check_release_readiness.py`
- `python scripts\check_public_beta_evidence.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`

Implementation notes so far:

- Reconciled the current repository state after PR #165 merged.
- Marked Queue Item 85 as merged and added Queue Items 86 and 87.
- Updated PR #165 worklog evidence with final head, squash merge commit, CI
  run, and CodeRabbit success.
- Refreshed `ops/ROADMAP.md` verification metadata from PR #162 to PR #165.
- Removed closed issue #164 from active Gate G blocker wording while preserving
  public-beta and production-release blocked status.
- Opened PR #167 against `main`.
- CodeRabbit comment `4694328674` found no blocking issues.
- Addressed CodeRabbit review thread `PRRT_kwDOM7REis6JOXqG` by moving
  completed issue refs `#162` and `#164` out of the Gate G `Blocking issues`
  paragraph and into `Evidence`, leaving only live blockers in the blocker
  text.

Validation so far:

- `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `git diff --check`
- `python scripts\check_release_readiness.py`
- `python scripts\check_public_beta_evidence.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- Remote validation: GitHub Actions CI run `27437060820` passed on final head
  `820eb1ac09cbfe1bb2347a60986f50e8ef8455c0`; CodeRabbit status was
  `success`; there were no unresolved review threads at merge.
- CodeRabbit follow-up focused validation:
  `rg -n "^#|^##|^###" ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`,
  `git diff --check`,
  `python scripts\check_release_readiness.py`,
  `python scripts\check_public_beta_evidence.py`,
  `python scripts\generate_release_manifest.py --check`, and
  `python scripts\generate_release_checksums.py --check`.

### PR #165: Add public beta evidence status manifest (Queue Item 85)

Status: Merged in PR #165 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/164`.
PR: `https://github.com/6529-Collections/6529Stream/pull/165`.
CodeRabbit request: issue comment `4693993623`.
Branch: `codex/public-beta-evidence-status`.
Branch started from PR #163 squash merge commit
`cb01f4668cfad068d6df6e556da3baf03fc23575`.
Final head: `54af773ccbf8c73c6d880a7713932039249053a5`.
Squash merge commit: `5e9a6c9f5afb569151b74b2095ef180cbbcfe884`.
CI run: `27435644265`.

Goal:

- Add `release-artifacts/latest/public-beta-evidence.json` as the no-secret
  status manifest for public-beta and production-release blockers.
- Add `release-artifacts/schema/public-beta-evidence.schema.json`.
- Add deterministic checker/tests so required categories, SHA256 file
  references, path boundaries, no-secret policy, risk-acceptance metadata, and
  overall ready/blocked claims cannot silently regress.
- Wire the checker into Makefile, Unix and Windows check wrappers, CI,
  release-manifest/checksum coverage, audit/readiness docs, release docs, and
  this run state.
- Keep the PR documentation/tooling/artifact-only with no Solidity behavior
  changes and no production evidence claims.

Initial candidate files:

- `release-artifacts/latest/public-beta-evidence.json`
- `release-artifacts/schema/public-beta-evidence.schema.json`
- `docs/public-beta-evidence.md`
- `scripts/check_public_beta_evidence.py`
- `scripts/test_public_beta_evidence.py`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `scripts/check_audit_package.py`
- `scripts/check_release_readiness.py`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `README.md`
- `docs/audit-package.md`
- `docs/known-blockers.md`
- `docs/release-policy.md`
- `docs/release-readiness.md`
- `docs/status.md`
- `docs/tooling.md`
- `release-artifacts/README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Implementation notes so far:

- Created issue #164 and branch `codex/public-beta-evidence-status`.
- Added the public-beta evidence checker and focused tests.
- Added the conservative committed evidence status with public beta and
  production release blocked.
- Added the schema and operator documentation.
- Wired Makefile, shell wrappers, CI, release manifest generation, audit
  package checker, release-readiness checker, README, status, release policy,
  tooling, release-artifact docs, known blockers, changelog, and roadmap.
- Made the release artifact generator treat `public-beta-evidence.json` as a
  downstream release file, matching the existing treatment for generated
  checksum, manifest, source-verification, and dependency-manifest outputs.
- Addressed CodeRabbit comment `4694002688` by adding a release-manifest helper
  docstring, enforcing ISO `YYYY-MM-DD` dates for risk-acceptance metadata,
  documenting schema/checker requirement-count alignment, and tightening the
  secret-key scan to avoid benign future key-name collisions.
- Addressed CodeRabbit review threads `PRRT_kwDOM7REis6JN30J`,
  `PRRT_kwDOM7REis6JN30V`, and `PRRT_kwDOM7REis6JN30b` by documenting ISO
  risk-acceptance dates, parsing them as real calendar dates, fixing
  `--release-artifacts-dir` handling for public-beta evidence, adding schema
  minItems drift coverage, adding custom release-artifacts-dir manifest
  coverage, and updating checksum/governance-doc coverage docs.

Validation so far:

- `python scripts\test_public_beta_evidence.py`
- `python scripts\check_public_beta_evidence.py`
- `python -m py_compile scripts\check_public_beta_evidence.py scripts\test_public_beta_evidence.py`
- `python scripts\test_release_readiness.py`
- `python scripts\test_audit_package.py`
- `python scripts\test_release_manifest.py`
- `python scripts\test_release_artifacts.py`
- `python scripts\generate_release_artifacts.py --check`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts\check.ps1`
- `rg -n "^#|^##|^###" docs\public-beta-evidence.md docs\release-readiness.md docs\audit-package.md docs\tooling.md ops\ROADMAP.md ops\AUTONOMOUS_RUN.md`
- `git diff --check` passes with only the existing `scripts/check.ps1` line-ending warning
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
- CodeRabbit follow-up focused validation:
  `python scripts\test_public_beta_evidence.py`,
  `python scripts\check_public_beta_evidence.py`,
  `python -m py_compile scripts\check_public_beta_evidence.py scripts\test_public_beta_evidence.py scripts\generate_release_manifest.py`,
  `python scripts\test_release_manifest.py`,
  `python scripts\generate_release_manifest.py --check`,
  `python scripts\test_release_artifacts.py`,
  `python scripts\generate_release_artifacts.py --check`,
  `python scripts\test_release_readiness.py`,
  `python scripts\check_release_readiness.py`,
  `python scripts\test_audit_package.py`,
  `python scripts\check_audit_package.py`, and
  `python scripts\generate_release_checksums.py --check`.
- Second CodeRabbit follow-up focused validation:
  `python scripts\test_public_beta_evidence.py`,
  `python scripts\check_public_beta_evidence.py`,
  `python scripts\test_release_manifest.py`,
  `python -m py_compile scripts\check_public_beta_evidence.py scripts\test_public_beta_evidence.py scripts\generate_release_manifest.py scripts\test_release_manifest.py`,
  `python scripts\generate_release_manifest.py --check`,
  `python scripts\generate_release_checksums.py --check`,
  `python scripts\test_release_readiness.py`,
  `python scripts\check_release_readiness.py`,
  `python scripts\test_audit_package.py`,
  `python scripts\check_audit_package.py`,
  `python scripts\test_release_artifacts.py`,
  `python scripts\generate_release_artifacts.py --check`, and
  `git diff --check`.
- Remote validation: GitHub Actions CI run `27435205011` passed on head
  `7aba4c7cd61d8a8dbe2611b324d4c2a073327faa`; CodeRabbit status was
  `success` on the same head; CodeRabbit marked all three visible review
  threads resolved.
- Final remote validation after the state-only merge-readiness commit:
  GitHub Actions CI run `27435644265` passed on final head
  `54af773ccbf8c73c6d880a7713932039249053a5`; CodeRabbit status was
  `success`; CodeRabbit reported no actionable comments for the latest
  `ops/AUTONOMOUS_RUN.md`-only review.

### PR #163: Add release readiness dashboard and blocker checker (Queue Item 84)

Status: Merged in PR #163 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/162`.
PR: `https://github.com/6529-Collections/6529Stream/pull/163`.
CodeRabbit request: issue comment `4693404700`.
CodeRabbit review comment: issue comment `4693433631`.
Branch: `codex/release-readiness-dashboard`.
Branch started from PR #161 squash merge commit
`0bddc2c93157e328c40b88b9c98e0fa7195b5acd`.
Final head: `ac65a41a13141a05e88a6801f487c598d5793302`.
Squash merge commit: `cb01f4668cfad068d6df6e556da3baf03fc23575`.
CI run: `27431237322`.

Goal:

- Add `docs/release-readiness.md` as the Gate G dashboard that separates local
  baseline evidence from public-beta blockers and production-release blockers.
- Add deterministic checker/tests so required headings, maturity warnings,
  evidence links, blocker language, release commands, missing linked files, and
  path-boundary handling cannot silently regress.
- Wire the checker into Makefile, Unix and Windows check wrappers, CI,
  release-manifest governance docs, audit package docs, release docs, and the
  release artifact catalog.
- Keep the PR documentation/tooling-only with no Solidity behavior changes.

Initial candidate files:

- `docs/release-readiness.md`
- `scripts/check_release_readiness.py`
- `scripts/test_release_readiness.py`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `scripts/check_audit_package.py`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `docs/audit-package.md`
- `release-artifacts/README.md`
- `docs/tooling.md`
- `docs/release-policy.md`
- `docs/status.md`
- `README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Implementation notes so far:

- Added the release-readiness dashboard with explicit pre-audit,
  not-production-ready, local-baseline, and no-security-claim maturity language.
- Added `scripts/check_release_readiness.py` and
  `scripts/test_release_readiness.py` to enforce headings, required maturity
  language, public-beta and production blocker terms, release commands, required
  evidence links, missing linked files, and path-boundary rejection.
- Wired the checker into Makefile, shell wrappers, CI, release-manifest
  governance docs, audit-package checker/docs, and release/status/tooling docs.
- Updated the roadmap and this run-state file to show PR #161 merged and issue
  #162 as the active Gate G work item.
- Accepted CodeRabbit review comment `4693433631` by adding focused tests for
  the missing-document error path and the custom `--release-readiness` CLI path.
- Added concise docstrings to the new checker and tests after CodeRabbit's
  pre-merge summary flagged docstring coverage on the new Python files.

Validation so far:

- `python scripts\test_release_readiness.py`
- `python scripts\check_release_readiness.py`
- `python -m py_compile scripts\check_release_readiness.py scripts\test_release_readiness.py`
- `python scripts\test_audit_package.py`
- `python scripts\check_audit_package.py`
- `python -m py_compile scripts\check_release_readiness.py scripts\test_release_readiness.py scripts\check_audit_package.py scripts\test_audit_package.py scripts\generate_release_manifest.py scripts\test_release_manifest.py`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts\check.ps1`
- heading scan for `docs/release-readiness.md`, `docs/audit-package.md`,
  `docs/tooling.md`, `docs/release-policy.md`, `ops/ROADMAP.md`, and
  `ops/AUTONOMOUS_RUN.md`
- `git diff --check`
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
- CodeRabbit follow-up validation: `python scripts\test_release_readiness.py`
  now runs 11 tests, `python scripts\check_release_readiness.py`, targeted
  `python -m py_compile`, `python scripts\check_changelog.py`, and
  `git diff --check` all pass.
- Docstring follow-up validation: `python scripts\test_release_readiness.py`,
  `python scripts\check_release_readiness.py`, targeted
  `python -m py_compile`, `python scripts\check_changelog.py`, and
  `git diff --check` all pass.

### PR #161: Add architecture and threat model audit docs (Queue Item 83)

Status: Merged in PR #161 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/160`.
PR: `https://github.com/6529-Collections/6529Stream/pull/161`.
CodeRabbit request: issue comment `4692872990`.
CodeRabbit final clean comment: issue comment `4692962127`.
Branch: `codex/architecture-threat-model`.
Branch started from PR #159 squash merge commit
`e2e9fcfdf0ef73e058244d4262f4d50137eefd3a`.
Final head: `95a70908b3470488dac8e142c427de28d022824a`.
Squash merge commit: `0bddc2c93157e328c40b88b9c98e0fa7195b5acd`.
CI run: `27428125013`.

Goal:

- Add `docs/architecture.md` as the current auditor-facing component,
  authority, custody/value-flow, randomness/metadata, deployment/release, and
  evidence map.
- Add `docs/threat-model.md` as the current auditor-facing asset, actor,
  trust-boundary, threat-category, control, and residual-risk model.
- Add deterministic checker/tests so required headings, maturity warnings,
  architecture terms, threat terms, commands, links, and missing linked files
  cannot silently regress.
- Wire the checker into Makefile, Unix and Windows check wrappers, CI,
  release-manifest governance docs, the audit package, and release docs.
- Keep the PR documentation/tooling-only with no Solidity behavior changes.

Initial candidate files:

- `docs/architecture.md`
- `docs/threat-model.md`
- `scripts/check_architecture_threat_model.py`
- `scripts/test_architecture_threat_model.py`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `scripts/check_audit_package.py`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `docs/audit-package.md`
- `release-artifacts/README.md`
- `docs/tooling.md`
- `docs/release-policy.md`
- `docs/status.md`
- `README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Implementation notes so far:

- Added the architecture and threat-model docs with explicit pre-audit,
  local-baseline, not-production-ready, and no-security-claim maturity language.
- Added `scripts/check_architecture_threat_model.py` and
  `scripts/test_architecture_threat_model.py` to enforce headings, required
  maturity language, required architecture/threat terms, maintenance commands,
  reciprocal doc links, required evidence links, and missing linked files.
- Wired the checker into Makefile, shell wrappers, CI, release-manifest
  governance docs, the audit package checker, and release/status/tooling docs.
- Accepted CodeRabbit review comment `4692896209` by linking the `StreamMinter`
  component row to ADR 0001, clarifying `arRNG`, anchoring the deployment
  ceremony phrase in the deployment/release threat row, removing redundant
  checker link scans, anchoring committed-doc tests to the script path, and
  adding reciprocal-link rejection tests.
- Accepted CodeRabbit review thread `PRRT_kwDOM7REis6JLvcL` by updating the
  roadmap verification metadata CI row from issue #160 to PR #161. Thread
  `PRRT_kwDOM7REis6JLvcO` was already addressed by commit `b5d531d`.

Validation so far:

- `python scripts\test_architecture_threat_model.py`
- `python scripts\check_architecture_threat_model.py`
- `python -m py_compile scripts\check_architecture_threat_model.py scripts\test_architecture_threat_model.py`
- `python scripts\test_audit_package.py`
- `python scripts\check_audit_package.py`
- `python -m py_compile scripts\check_architecture_threat_model.py scripts\test_architecture_threat_model.py scripts\check_audit_package.py scripts\test_audit_package.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py scripts\test_release_checksums.py scripts\check_changelog.py scripts\test_changelog_check.py`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts\check.ps1`
- `git diff --check`
- heading scan for `docs/architecture.md`, `docs/threat-model.md`,
  `docs/audit-package.md`, and `ops/ROADMAP.md`
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
- CodeRabbit follow-up validation: `python scripts\test_architecture_threat_model.py`,
  `python scripts\check_architecture_threat_model.py`, targeted
  `python -m py_compile`, `python scripts\test_audit_package.py`,
  `python scripts\check_audit_package.py`, `python scripts\test_release_manifest.py`,
  `python scripts\generate_release_manifest.py --check`,
  `python scripts\test_release_checksums.py`,
  `python scripts\generate_release_checksums.py --check`,
  `python scripts\test_changelog_check.py`, `python scripts\check_changelog.py`,
  `bash -n scripts/check.sh`, PowerShell parser check for `scripts\check.ps1`,
  and `git diff --check`.
- CI run `27428125013` passed on final head
  `95a70908b3470488dac8e142c427de28d022824a`, including the architecture and
  threat model, audit package, release manifest, release checksums, changelog,
  and deployment rehearsal steps. CodeRabbit status was `success` on the same
  head.

### PR candidate: Add external audit package index (Queue Item 82)

Status: Merged in PR #159 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/158`.
PR: `https://github.com/6529-Collections/6529Stream/pull/159`.
CodeRabbit request: issue comment `4692444134`.
Branch: `codex/audit-package-index`.
Branch started from PR #157 squash merge commit
`ed5f3b17cec879d74f765cbd457a9b0fbe809cad`.

Goal:

- Add a single auditor-facing index for current maturity, scope, ADRs,
  invariants, static analysis, local deployment/release evidence, known
  blockers, accepted local-baseline dispositions, and security reporting.
- Add a deterministic checker and unit tests so required sections, maturity
  warnings, commands, and linked evidence targets cannot silently disappear.
- Wire the checker into Makefile, Unix and Windows check wrappers, and CI.
- Include `docs/audit-package.md` in release-manifest governance docs so the
  generated manifest and checksum bundle capture the package hash.
- Keep the PR documentation/tooling-only with no Solidity behavior changes.

Initial candidate files:

- `docs/audit-package.md`
- `scripts/check_audit_package.py`
- `scripts/test_audit_package.py`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `release-artifacts/README.md`
- `docs/tooling.md`
- `docs/release-policy.md`
- `docs/status.md`
- `README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Implementation notes:

- Added `docs/audit-package.md` as the canonical Gate F index for audit scope,
  maturity warnings, entry points, ADRs, invariants, Slither, deployment/release
  evidence, blocker/risk separation, security reporting, and verification
  commands.
- Added `scripts/check_audit_package.py` to enforce required headings, maturity
  language, local verification commands, required links, and missing linked
  files.
- Added `scripts/test_audit_package.py` covering the committed package, a
  minimal valid package, missing heading, missing maturity language, missing
  required link, and missing linked file cases.
- Wired the checker into Makefile, Unix and Windows check wrappers, CI,
  release-manifest governance docs, and release documentation.
- Regenerated `release-artifacts/latest/release-manifest.json`,
  `release-artifacts/latest/SHA256SUMS`, and
  `release-artifacts/latest/release-checksums.json`.
- Accepted CodeRabbit's PR #159 follow-up review by aggregating missing-link
  failures, guarding the missing-required-link test replacement, clarifying that
  `generate_*` commands mutate tracked files while `--check` verifies them, and
  changing `AuditPackageError` to inherit from `ValueError`.

Validation:

- `python scripts\test_audit_package.py`
- `python scripts\check_audit_package.py`
- `python -m py_compile scripts\check_audit_package.py scripts\test_audit_package.py scripts\generate_release_manifest.py scripts\test_release_manifest.py`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts\check.ps1`
- `git diff --check`
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
- CodeRabbit follow-up validation: `python scripts\test_audit_package.py`,
  `python scripts\check_audit_package.py`, targeted `python -m py_compile`,
  `python scripts\test_release_manifest.py`,
  `python scripts\generate_release_manifest.py --check`,
  `python scripts\test_release_checksums.py`,
  `python scripts\generate_release_checksums.py --check`,
  `python scripts\test_changelog_check.py`, `python scripts\check_changelog.py`,
  `bash -n scripts/check.sh`, and `git diff --check`.
- Remote validation: GitHub CI run `27424703232` passed on head
  `a62d15a3a34b7476879e056473ca26e5192a506d`, including the audit package,
  release manifest, release checksums, changelog, and deployment rehearsal
  steps. CodeRabbit status was `success` on the same head.
- Merged via squash as
  `e2e9fcfdf0ef73e058244d4262f4d50137eefd3a`.

### PR candidate: Add release signature evidence baseline (Queue Item 81)

Status: Merged in PR #157 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/156`.
PR: `https://github.com/6529-Collections/6529Stream/pull/157`.
CodeRabbit request: issue comment `4691996355`.
Branch: `codex/release-signature-evidence`.
Branch started from PR #155 squash merge commit
`a63a52f81f2dc97bd40954e36772d55ae9087e79`.

Goal:

- Add a machine-readable release signature evidence schema.
- Add a local placeholder evidence bundle that records the self-referential
  release manifest/checksum boundary without claiming production signing has
  happened.
- Add validator/unit tests and wire them into local, Windows, and CI gates.
- Include release signature evidence in the generated release manifest and
  release checksum coverage.
- Document production expectations for detached checksum signatures, signed Git
  tags, public signer fingerprints, verification commands, signer rotation, and
  no-secret redaction.
- Keep private signing keys, real production signatures, and Solidity behavior
  out of scope.

Initial candidate files:

- `scripts/check_release_signatures.py`
- `scripts/test_release_signatures.py`
- `release-artifacts/schema/release-signature-evidence.schema.json`
- `release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json`
- `docs/release-signatures.md`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `release-artifacts/README.md`
- `docs/release-policy.md`
- `docs/status.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Implementation notes:

- Added `scripts/check_release_signatures.py` with no-secret validation,
  self-referential release-manifest/checksum references, signer identity checks,
  local-placeholder restrictions, production signed-output requirements, and
  retained artifact hash checks.
- Added `scripts/test_release_signatures.py` covering valid local evidence,
  negative confirmation depth, secret-like values, stale retained hashes,
  non-local placeholder rejection, signed-output verification command
  requirements, and production signed-output requirements.
- Added local release signature evidence under `release-artifacts/signatures/`
  and a schema under `release-artifacts/schema/`.
- Wired the checker into Makefile, Unix and Windows check wrappers, CI, release
  manifest, and release checksum coverage.
- Updated release policy, release artifact docs, status, roadmap, changelog,
  and run-state docs.

Validation:

- `python scripts\test_release_signatures.py`
- `python scripts\check_release_signatures.py`
- `python -m py_compile scripts\check_release_signatures.py scripts\test_release_signatures.py scripts\generate_release_manifest.py scripts\test_release_manifest.py`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `bash -n scripts/check.sh`
- `git diff --check` passed with the existing PowerShell line-ending warning for
  `scripts/check.ps1`.
- `make check`
- GitHub CI run `27420702347` failed repository hygiene on an extra blank line
  at EOF in `docs/release-signatures.md`; the EOF was trimmed and the release
  manifest/checksum evidence was regenerated.
- Post-CI-fix validation: `python scripts\test_release_signatures.py`,
  `python scripts\check_release_signatures.py`,
  `python scripts\test_release_manifest.py`,
  `python scripts\generate_release_manifest.py --check`,
  `python scripts\test_release_checksums.py`,
  `python scripts\generate_release_checksums.py --check`,
  targeted `python -m py_compile`, `bash -n scripts/check.sh`,
  `bash -n scripts/bootstrap-ec2.sh`, and `git diff --check`.
- CodeRabbit follow-up fixes:
  - Added exact-key evidence validation so the checker rejects unexpected
    top-level and nested fields that the schema marks as disallowed.
  - Made release-manifest generation validate release-signature evidence before
    indexing it, then retain the validated evidence payload in the manifest.
  - Added release-signature schema and evidence paths to default checksum
    coverage and regenerated the manifest/checksum bundle.
- CodeRabbit follow-up focused validation:
  `python scripts\test_release_signatures.py`,
  `python scripts\check_release_signatures.py`,
  `python scripts\test_release_manifest.py`,
  `python scripts\generate_release_manifest.py --check`,
  `python scripts\test_release_checksums.py`,
  `python scripts\generate_release_checksums.py --check`,
  targeted `python -m py_compile`, `bash -n scripts/check.sh`,
  `bash -n scripts/bootstrap-ec2.sh`, and `git diff --check`.

### PR candidate: Add randomizer operations evidence bundle (Queue Item 80)

Status: Merged in PR #155 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/154`.
PR: `https://github.com/6529-Collections/6529Stream/pull/155`.
CodeRabbit requests: issue comments `4691619335` and `4691631125`.
Branch: `codex/randomizer-operations-evidence`.
Branch started from PR #153 squash merge commit
`551185c6399d79c74321d2e4fb128cbb29c4a8e7`.
Initial head: `308bb21117551db5843d31b9b255c7af7b026b84`.

Goal:

- Add a machine-readable randomizer operations evidence schema.
- Add a local Anvil randomizer operations evidence bundle that records
  placeholder provider addresses, provider epochs, local funding status,
  lifecycle controls, reserve-accounting evidence, retained artifacts, and
  redaction policy without claiming fork/testnet/live readiness.
- Add validator/unit tests and wire them into local, Windows, and CI gates.
- Include the new evidence in release manifest and checksum coverage.
- Update deployment, release, status, roadmap, and durable run-state docs.
- Keep production provider credentials, live RPC calls, and Solidity behavior
  out of scope.

Initial candidate files:

- `scripts/check_randomizer_operations.py`
- `scripts/test_randomizer_operations.py`
- `deployments/schema/randomizer-operations-evidence.schema.json`
- `deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json`
- `docs/randomizer-operations.md`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `scripts/generate_release_checksums.py`
- `deployments/README.md`
- `docs/deployment.md`
- `docs/release-policy.md`
- `docs/status.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Implementation notes:

- Added `scripts/check_randomizer_operations.py` with no-secret validation,
  file-reference hash checks, deployment-manifest/address-book alignment,
  provider funding status checks, lifecycle-control evidence checks, retained
  artifact category checks, and stricter production/mainnet evidence
  requirements.
- Added `scripts/test_randomizer_operations.py` with success coverage and
  negative tests for invalid addresses, manifest mismatches, missing passed
  control evidence, secret-like values, non-local local-only funding status,
  production evidence missing provider-funding proof, and duplicate retained
  categories.
- Added local Anvil randomizer evidence under
  `deployments/randomizer-operations/` and a schema under
  `deployments/schema/`.
- Wired the checker into Makefile, Unix and Windows check wrappers, CI, release
  manifest, and release checksum coverage.
- Addressed CodeRabbit follow-up by rejecting negative confirmation depths,
  isolating the production provider-funding evidence test from retained-category
  failures, and leaving production requirements as the operator-facing funding
  evidence gate.

Validation:

- `python scripts\test_randomizer_operations.py`
- `python scripts\check_randomizer_operations.py`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python -m py_compile scripts\check_randomizer_operations.py scripts\test_randomizer_operations.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py scripts\test_release_checksums.py`
- `bash -n scripts/check.sh`
- `git diff --check`
- `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`

CodeRabbit follow-up validation:

- `python scripts\test_randomizer_operations.py`
- `python scripts\check_randomizer_operations.py`
- `python -m py_compile scripts\check_randomizer_operations.py scripts\test_randomizer_operations.py`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`

### PR candidate: Add request-level randomizer reserve lifecycle tests (Queue Item 79)

Status: Merged in PR #153.
Issue: `https://github.com/6529-Collections/6529Stream/issues/152`.
PR: `https://github.com/6529-Collections/6529Stream/pull/153`.
CodeRabbit request: issue comment `4691282971`.
Initial head: `7d97515138fe22d206b6d156e9cf30550377eea2`.
Branch: `codex/randomizer-reserve-lifecycle-tests`.
Branch started from PR #151 squash merge commit
`e7de312e9a74cee5bd9d47edb7bd974421bee17b`.

Goal:

- Add focused local Gate D coverage for request-level
  `NextGenRandomizerRNG` provider reserve accounting.
- Prove arRNG request-cost spending decreases the adapter reserve by the
  configured provider cost while the remaining reserve stays represented by
  `totalRandomnessReserved()`, `totalOwed()`, and `totalReserved()`.
- Cover multiple pending requests, fulfilled requests, stale marking, failed
  post-processing, deterministic retry, forced ETH during a pending request,
  and unauthorized emergency-withdrawal attempts.
- Update changelog, test inventory, project status, roadmap traceability, and
  this durable run state.
- Keep production provider-funding runbooks, fork/testnet/live evidence, and
  provider-model changes out of scope for this local test slice.

Initial candidate files:

- `test/StreamRandomizerPayments.t.sol`
- `test/README.md`
- `docs/status.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Implementation notes:

- Added `test/StreamRandomizerPayments.t.sol`, a scenario suite around
  `NextGenRandomizerRNG` and a payable arRNG controller mock.
- The suite covers direct reserve funding, multiple request-cost payments,
  aggregate pending-request accounting, provider refund-address capture,
  fulfilled requests, stale requests, failed post-processing, retry after
  failure, forced ETH during a pending request, and unauthorized emergency
  withdrawal.
- The tests assert `totalRandomnessReserved()`, `totalOwed()`,
  `totalReserved()`, `surplus()`, `emergencyWithdrawable()`, contract balance,
  pending counts, request states, and provider payment totals at each relevant
  boundary.
- No production Solidity changes were needed; the existing conservative adapter
  model matched the intended local accounting.

Focused validation:

- `forge fmt test\StreamRandomizerPayments.t.sol` passed.
- `forge test --match-path test\StreamRandomizerPayments.t.sol -vvv` passed
  with 6 tests.
- Neighboring focused suites passed:
  `test\StreamEmergencyWithdraw.t.sol`, `test\StreamPaymentsInvariant.t.sol`,
  `test\StreamRandomizerLifecycle.t.sol`, and
  `test\StreamRandomizerRetry.t.sol`.
- Release manifest, release checksum, and changelog self-tests/check modes
  passed after regenerating `release-artifacts/latest/`.
- Full local `make check` passed.
- Windows `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed.
- `git diff --check` passed.

Validation plan:

- `forge fmt test\StreamRandomizerPayments.t.sol`
- `forge test --match-path test\StreamRandomizerPayments.t.sol -vvv`
- `forge test --match-path test\StreamEmergencyWithdraw.t.sol -vvv`
- `forge test --match-path test\StreamPaymentsInvariant.t.sol -vvv`
- `forge test --match-path test\StreamRandomizerLifecycle.t.sol -vvv`
- `forge test --match-path test\StreamRandomizerRetry.t.sol -vvv`
- `python scripts\test_release_manifest.py`
- `python scripts\test_release_checksums.py`
- `python scripts\test_changelog_check.py`
- `python scripts\generate_release_manifest.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\check_changelog.py`
- Full local `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check`

### PR candidate: Add auction consistency invariant baseline (Queue Item 78)

Status: merged in PR #151 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/150`.
PR: `https://github.com/6529-Collections/6529Stream/pull/151`.
CodeRabbit request: issue comment `4690918785`.
Initial head: `f83b68a32e5446c22e40f44ff190c593fed93b06`.
Final head: `2c161ebb709423080519453b3259c35b0f847489`.
Squash merge commit: `e7de312e9a74cee5bd9d47edb7bd974421bee17b`.
CI run: `27413957701`.
Branch started from PR #149 squash merge commit
`3ca6e53eb3b8299a80fbf5d7765e0dd7f0d0d610`.

Goal:

- Add a bounded sequence invariant baseline for auction registration, active
  custody, first bids, higher outbids, pre-bid cancellation, ended no-bid
  settlement, ended with-bid settlement, repeated settlement attempts,
  withdrawals where useful, and invalid-operation preservation.
- Reassert that auction token custody is known at all times, previous bidders
  receive withdrawable credit, active bid escrow remains represented in local
  accounting, cancellation is pre-bid only, terminal auctions reject new bids,
  settlement is terminal/idempotent, and final ownership/proceeds expectations
  remain coherent.
- Update changelog, test inventory, project status, roadmap traceability, and
  this durable run state.
- Keep fork/testnet/live invariant evidence and new auction product semantics
  out of scope unless the local invariant reveals a concrete defect.

Initial candidate files:

- `test/StreamAuctionInvariant.t.sol`
- `test/helpers/Assertions.sol`
- `test/README.md`
- `docs/status.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Implementation notes:

- Added `test/StreamAuctionInvariant.t.sol`, a bounded sequence harness over a
  single deployed stream/auction stack.
- The handler mints signed auction drops, cancels active no-bid auctions,
  places first bids and higher outbids, attempts underbids, settles no-bid and
  with-bid auctions, attempts repeat settlement and late bids, withdraws bidder
  and proceeds credits, forces surplus, and runs emergency surplus withdrawal.
- The invariant reasserts token custody, auction status, highest bid/bidder,
  previous-bidder credits, proceeds splits, active bid escrow, `totalOwed()`,
  `totalReserved()`, balance coverage, and `surplus()`/`emergencyWithdrawable()`
  after each action.
- Invalid-operation attempts snapshot custody/accounting before the call and
  prove failed calls preserve status, owner, bid state, owed totals, and
  contract balance.
- Added `Assertions.assertGte` and replaced the local balance-coverage
  `require` in response to CodeRabbit's consistency nitpick.
- Updated `test/README.md`, `docs/status.md`, `CHANGELOG.md`, and
  `ops/ROADMAP.md` to document the new local Gate D coverage and remaining
  fork/testnet evidence gap.

Focused validation:

- `forge fmt test\StreamAuctionInvariant.t.sol` passed.
- `forge test --match-path test\StreamAuctionInvariant.t.sol -vvv` passed with
  256 fuzz runs.
- After the CodeRabbit nitpick fix, `forge fmt
  test\helpers\Assertions.sol test\StreamAuctionInvariant.t.sol`, focused
  Forge auction-invariant testing, and `git diff --check` passed.
- Release manifest/checksum/changelog self-tests and check modes passed after
  regenerating `release-artifacts/latest/`.
- Full local `make check` passed.
- Windows `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed.
- `git diff --check` passed.

Validation plan:

- `forge fmt test\StreamAuctionInvariant.t.sol`
- `forge test --match-path test\StreamAuctionInvariant.t.sol -vvv`
- `python scripts\test_release_manifest.py`
- `python scripts\test_release_checksums.py`
- `python scripts\test_changelog_check.py`
- `python scripts\generate_release_manifest.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\check_changelog.py`
- Full local `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check`

### PR candidate: Add supply/replay/freeze invariant baseline (Queue Item 77)

Status: merged in PR #149 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/148`.
PR: `https://github.com/6529-Collections/6529Stream/pull/149`.
CodeRabbit request: issue comment `4690503803`.
Final head: `ed6bd87f50877fdf711f14fbc215aa958bd59f16`.
Squash merge commit: `3ca6e53eb3b8299a80fbf5d7765e0dd7f0d0d610`.
Branch started from PR #147 squash merge commit
`a907219a2717322a6be72e141615dbeeb1edb7d8`.

Goal:

- Add a bounded sequence invariant baseline for fixed-price drop execution,
  cancellation, consumed-drop replay attempts, cancelled-drop mint attempts,
  burns, metadata edits, freeze attempts, and post-freeze mutation rejection.
- Reassert global and collection live supply, minted-ever circulation counters,
  burn counters, burn audit state, consumed/cancelled drop ID state, token
  ownership, token-to-collection mapping, freeze manifest stability, and
  final-supply tightening after each step.
- Update changelog, test inventory, project status, roadmap traceability, and
  this durable run state.
- Keep fork/testnet/live invariant evidence and auction-consistency invariants
  out of scope for this local Gate D baseline.

Initial candidate files:

- `test/StreamSupplyReplayFreezeInvariant.t.sol`
- `test/README.md`
- `docs/status.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Validation plan:

- `forge fmt test\StreamSupplyReplayFreezeInvariant.t.sol`
- `forge test --match-path test\StreamSupplyReplayFreezeInvariant.t.sol -vvv`
- `python scripts\test_release_manifest.py`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_manifest.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- Full local `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check`

Current implementation notes:

- Added `test/StreamSupplyReplayFreezeInvariant.t.sol` with a bounded handler
  that mixes valid fixed-price mints, fresh cancellations, consumed-drop
  replays, cancelled-drop mint attempts, burns, metadata edits, freeze attempts,
  and post-freeze mint/burn/token-data rejection checks.
- The invariant tracks the model state for minted-ever tokens, live tokens,
  burned tokens, consumed drop IDs, cancelled drop IDs, token ownership,
  token-to-collection mapping, burn audit state, freeze manifest hash, and
  finalized supply.
- Focused local validation passed before docs updates:
  `forge fmt test\StreamSupplyReplayFreezeInvariant.t.sol` and
  `forge test --match-path test\StreamSupplyReplayFreezeInvariant.t.sol -vvv`.
- Subagent spawning was attempted earlier in this manager run but blocked by
  the app agent thread limit, so this item continues locally.

Validation completed:

- `forge fmt test\StreamSupplyReplayFreezeInvariant.t.sol`
- `forge test --match-path test\StreamSupplyReplayFreezeInvariant.t.sol -vvv`
- `python scripts\test_release_manifest.py`
- `python scripts\test_release_checksums.py`
- `python scripts\test_changelog_check.py`
- `python scripts\generate_release_manifest.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\check_changelog.py`
- `python -m py_compile scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py scripts\test_release_checksums.py scripts\check_changelog.py scripts\test_changelog_check.py`
- `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check`

CodeRabbit follow-up addressed locally:

- CodeRabbit review `4485046635` correctly noted `_trackDrop` would silently
  stop tracking drops if future sequence bounds exceeded
  `MAX_TRACKED_DROPS`.
- Replaced the silent return with `require(trackedDropCount < MAX_TRACKED_DROPS,
  "drop tracking overflow")` so future handler expansion fails loudly instead
  of weakening invariant coverage.

Follow-up validation:

- `forge fmt test\StreamSupplyReplayFreezeInvariant.t.sol`
- `forge test --match-path test\StreamSupplyReplayFreezeInvariant.t.sol -vvv`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `git diff --check`

### PR candidate: Add local gas snapshot baseline (Queue Item 76)

Status: merged in PR #147 after CI and CodeRabbit success.
Issue: `https://github.com/6529-Collections/6529Stream/issues/146`.
PR: `https://github.com/6529-Collections/6529Stream/pull/147`.
CodeRabbit request: issue comment `4689622593`.
Final head: `407e79e899d74a71f12b07ea69421927434ef775`.
Squash merge commit: `a907219a2717322a6be72e141615dbeeb1edb7d8`.
Branch started from PR #145 squash merge commit
`9f1c2578ab12097e945c7400a2f37df83608a092`.

Goal:

- Add deterministic local gas snapshot scenarios for fixed-price mint, auction
  bid, auction settlement, curator reward claim, final on-chain `tokenURI`, and
  dependency/script reads.
- Commit the Foundry snapshot under
  `release-artifacts/baselines/v0.1.0/gas-snapshot.snap`.
- Add `make gas-snapshot` and `make gas-snapshot-check`, then wire the check
  into `make check`, Linux/Windows check wrappers, and CI.
- Include the gas snapshot baseline in release manifest/checksum evidence.
- Update docs, changelog, roadmap, test inventory, and this durable run state.
- Keep fork/testnet/mainnet gas measurements and hard public gas budgets out of
  scope for this local baseline.

Initial candidate files:

- `test/StreamGasSnapshot.t.sol`
- `test/helpers/CharacterizationTestBase.sol`
- `release-artifacts/baselines/v0.1.0/gas-snapshot.snap`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `.github/workflows/ci.yml`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `docs/tooling.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `docs/release-policy.md`
- `release-artifacts/README.md`
- `test/README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation plan:

- `forge fmt test\StreamGasSnapshot.t.sol test\helpers\CharacterizationTestBase.sol`
- `forge test --match-path test\StreamGasSnapshot.t.sol -vvv`
- `forge snapshot --match-path test\StreamGasSnapshot.t.sol --snap release-artifacts\baselines\v0.1.0\gas-snapshot.snap`
- `forge snapshot --match-path test\StreamGasSnapshot.t.sol --check release-artifacts\baselines\v0.1.0\gas-snapshot.snap`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python -m py_compile scripts\generate_release_manifest.py scripts\test_release_manifest.py`
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh`
- Full local `make check`
- PowerShell parser check and `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check`

Current implementation notes:

- Added `test/StreamGasSnapshot.t.sol` with setup gas metering paused and one
  measured call per scenario.
- Added Foundry gas metering cheatcodes to the local test VM interface.
- Added Makefile, Linux wrapper, Windows wrapper, and CI gas snapshot checks.
- Generated `release-artifacts/baselines/v0.1.0/gas-snapshot.snap` from the
  focused local test file.
- Updated release manifest generation/tests to include the gas snapshot
  baseline as a release artifact, and documented the baseline in tooling,
  release, status, blocker, test, roadmap, and changelog docs.

Validation completed:

- `forge fmt test\StreamGasSnapshot.t.sol test\helpers\CharacterizationTestBase.sol`
- `forge test --match-path test\StreamGasSnapshot.t.sol -vvv`
- `forge snapshot --match-path test\StreamGasSnapshot.t.sol --snap release-artifacts\baselines\v0.1.0\gas-snapshot.snap`
- `forge snapshot --match-path test\StreamGasSnapshot.t.sol --check release-artifacts\baselines\v0.1.0\gas-snapshot.snap`
- `python scripts\test_release_manifest.py`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_manifest.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python -m py_compile scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py scripts\test_release_checksums.py`
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh`
- PowerShell parser checks for `scripts\check.ps1` and `scripts\bootstrap-windows.ps1`
- `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check`

CodeRabbit follow-up addressed locally:

- Made `scripts/generate_release_manifest.py` derive the default gas snapshot
  baseline path from the discovered protocol version and reject explicit
  snapshot paths that name a different version directory.
- Added `docs/tooling.md` Local Checks parity for the `forge snapshot --check`
  command now wired into `make check`.
- Extended `scripts/test_release_manifest.py` to assert gas snapshot digest and
  byte size, plus dynamic default and mismatch rejection behavior.
- Regenerated `release-artifacts/latest/release-manifest.json`,
  `release-artifacts/latest/SHA256SUMS`, and
  `release-artifacts/latest/release-checksums.json`.

Follow-up validation:

- `python scripts\test_release_manifest.py`
- `python scripts\test_release_checksums.py`
- `python -m py_compile scripts\generate_release_manifest.py scripts\test_release_manifest.py`
- `forge snapshot --match-path test\StreamGasSnapshot.t.sol --check release-artifacts\baselines\v0.1.0\gas-snapshot.snap`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `git diff --check`
- `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`

Second CodeRabbit follow-up addressed locally:

- CodeRabbit review comment `3402400116` correctly noted that an explicit
  `--gas-snapshot` override with the right version directory and filename could
  still point outside the canonical release baseline tree.
- Updated `scripts/generate_release_manifest.py` to resolve both the expected
  baseline and supplied override through the repository root, then require the
  paths to match
  `release-artifacts/baselines/v<protocol-version>/gas-snapshot.snap`.
- Added `scripts/test_release_manifest.py` coverage rejecting a foreign
  `tmp/v0.1.0/gas-snapshot.snap` override.

Second follow-up validation:

- `python scripts\test_release_manifest.py`
- `python -m py_compile scripts\generate_release_manifest.py scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `git diff --check`
- `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`

### PR candidate: Add deployment ceremony evidence bundle schema (Queue Item 75)

Status: merged in PR #145 after CI and CodeRabbit success.
Branch started from PR #143 squash merge commit
`6dd5846122ebca965a0f1bcefac0386f0ab0cb60`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/144`.

Goal:

- Define a no-secret deployment ceremony evidence schema under `deployments/`.
- Add a local Anvil evidence bundle tying the deployment manifest, address book,
  ABI checksums, release checksum bundle, admin ceremony, signer setup,
  metadata-browser check, auction ceremony, emergency redeployment rehearsal,
  verification status, retained artifacts, and redaction policy together.
- Add a Python validator and unit tests that catch stale hashes, missing
  referenced files, missing sections, weak non-local evidence, invalid
  verification state, and secret-like keys.
- Wire the checker into Makefile, Linux/Windows check wrappers, and CI.
- Include ceremony evidence in release manifest and checksum coverage.
- Update docs, changelog, roadmap, release artifact docs, and this durable run
  state while keeping fork/testnet/live evidence contents explicitly out of
  scope.

Initial candidate files:

- `deployments/schema/ceremony-evidence.schema.json`
- `deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json`
- `scripts/check_ceremony_evidence.py`
- `scripts/test_ceremony_evidence.py`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `scripts/generate_release_checksums.py`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `.github/workflows/ci.yml`
- `deployments/README.md`
- `docs/deployment.md`
- `docs/tooling.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `release-artifacts/README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`

Validation plan:

- `python scripts\test_ceremony_evidence.py`
- `python scripts\check_ceremony_evidence.py`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python -m py_compile` for touched Python scripts.
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh`.
- Full local `make check`.
- PowerShell parser check and `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`.
- `git diff --check`.

Current implementation notes:

- Added `scripts/check_ceremony_evidence.py` with schema-version, environment,
  source, participant, artifact, result, verification, retained-artifact,
  redaction-policy, repo-path, SHA-256, and secret-like-key validation.
- Added `scripts/test_ceremony_evidence.py` for valid evidence, missing
  sections, invalid hashes, missing files, non-local retained-artifact
  requirements, testnet verification status, and secret-like-key rejection.
- Added `deployments/schema/ceremony-evidence.schema.json` and the local Anvil
  evidence bundle under `deployments/ceremony-evidence/`.
- Wired ceremony evidence into `make check`, Linux/Windows check wrappers, CI,
  release manifest generation/tests, and release checksum coverage.
- Updated docs, changelog, roadmap, and run-state to make the evidence format
  discoverable while preserving the remaining fork/testnet/live evidence gap.
- Addressed CodeRabbit PR #145 comments by adding the new evidence scripts to
  the fast CI `py_compile` list, aligning manual release-artifact docs with the
  `test` plus `check` sequence, clarifying non-local ceremony evidence as
  future work, removing redundant test deepcopy, and adding secret-like string
  value detection.

Validation completed so far:

- `python scripts\test_ceremony_evidence.py`
- `python scripts\check_ceremony_evidence.py`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python -m py_compile scripts\check_ceremony_evidence.py scripts\test_ceremony_evidence.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py`
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh`
- `make check`
- PowerShell parser check for `scripts\check.ps1` and
  `scripts\bootstrap-windows.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- CodeRabbit follow-up focused validation:
  - `python scripts\test_ceremony_evidence.py`
  - `python scripts\check_ceremony_evidence.py`
  - `python -m py_compile scripts\check_ceremony_evidence.py scripts\test_ceremony_evidence.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py`
  - `python scripts\generate_release_manifest.py`
  - `python scripts\generate_release_checksums.py`
  - `python scripts\generate_release_manifest.py --check`
  - `python scripts\test_release_manifest.py`
  - `python scripts\generate_release_checksums.py --check`
  - `python scripts\test_release_checksums.py`
  - `python scripts\test_changelog_check.py`
  - `python scripts\check_changelog.py`
  - `bash -n scripts/check.sh scripts/bootstrap-ec2.sh`
  - `make check`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`

### PR candidate: Add local emergency redeployment rehearsal (Queue Item 74)

Status: merged in PR #143 after CI passed and CodeRabbit resolved the
deployment-version assertion thread.
Branch `codex/emergency-redeployment-rehearsal` started from PR #141 merge
commit `1b3ad3df35fb6dedd65b2b227b1beb29feaa8b61`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/142`.

Goal:

- Add a local ADR 0007 emergency redeployment rehearsal that deploys an
  impacted historical stack and a replacement stack with a distinct deployment
  version.
- Prove old/replacement manifest hashes, EIP-712 drop domains, and core/drops/
  auction addresses differ.
- Prove both deployments complete the Safe-rooted admin ceremony and remove the
  temporary deployer admin.
- Prove the replacement stack is independently usable by minting a fixed-price
  smoke token through EIP-712 authorization and a deterministic randomizer.
- Wire the rehearsal into local/CI deployment gates and update docs, roadmap,
  changelog, release evidence, and this durable run state.
- Keep fork/testnet/live emergency evidence explicitly out of scope because this
  slice must not require secrets.

Initial candidate files:

- `script/RehearseEmergencyRedeployment.s.sol`
- `test/StreamDeploymentManifest.t.sol`
- `Makefile`
- `.github/workflows/ci.yml`
- `scripts/check.ps1`
- `scripts/check.sh`
- `docs/deployment.md`
- `docs/tooling.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `script/README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `release-artifacts/latest/release-manifest.json`

Validation plan:

- `forge fmt` for touched Solidity scripts/tests.
- Focused Forge test for the emergency redeployment evidence.
- `forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir`.
- Generated release manifest/checksum/changelog drift checks after docs updates.
- Full local `make check`.
- Bash and PowerShell wrapper syntax checks.

Current implementation notes:

- Added `script/RehearseEmergencyRedeployment.s.sol` with a local deterministic
  randomizer, double deployment ceremony, distinct deployment-version/domain/
  manifest/address assertions, Safe ownership/deployer-admin revocation checks,
  and replacement fixed-price EIP-712 mint smoke.
- Extended `test/StreamDeploymentManifest.t.sol` to assert machine-checkable
  evidence hashes, distinct old/replacement domains and contract addresses,
  signer/Safe continuity, replacement token ownership, token hash, and signer
  epoch.
- Wired the emergency redeployment ceremony into `make deploy-rehearsal`,
  Linux/Windows check wrappers, and the CI deployment rehearsal step.
- Updated deployment/tooling/status/blocker/test/script docs, changelog, and
  roadmap state to distinguish local Anvil emergency redeployment evidence from
  future fork/testnet/live emergency evidence.

Validation completed so far:

- `forge fmt script\RehearseEmergencyRedeployment.s.sol test\StreamDeploymentManifest.t.sol`
- `forge test --match-path test\StreamDeploymentManifest.t.sol -vvv`
- `forge script script\RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir`
- `python scripts\generate_release_manifest.py`
- `python scripts\generate_release_checksums.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python scripts\test_release_manifest.py`
- `python scripts\test_release_checksums.py`
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh`
- `make check`
- PowerShell parser check for `scripts\check.ps1` and `scripts\bootstrap-windows.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- CodeRabbit follow-up focused validation after adding explicit deployment
  version reuse guard:
  - `forge fmt script\RehearseEmergencyRedeployment.s.sol`
  - `forge test --match-path test\StreamDeploymentManifest.t.sol -vvv`
  - `forge script script\RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir`
  - `make check`

### PR candidate: Add dry-run auction ceremony rehearsal (Queue Item 73)

Status: merged in PR #141 after CI passed and CodeRabbit resolved all review
threads.
Branch `codex/dry-run-auction-ceremony` started from PR #139 merge commit
`e09e422a4f95fbf6948d182fcff83a25aaf88e0c`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/140`.

Goal:

- Add a local release-style auction ceremony rehearsal that builds on
  `script/RehearseDeployment.s.sol`.
- Mint an auction drop through the EIP-712 authorization path.
- Confirm custody, bid, settlement, proceeds withdrawal, final owner, final
  status, and zero remaining owed balance.
- Wire the rehearsal into local/CI deployment gates and update docs, roadmap,
  changelog, release evidence, and this durable run state.
- Keep live fork/testnet/production broadcast evidence explicitly out of scope
  because this slice must not require secrets.

Initial candidate files:

- `script/RehearseAuctionCeremony.s.sol`
- `test/StreamDeploymentManifest.t.sol`
- `Makefile`
- `.github/workflows/ci.yml`
- `scripts/check.ps1`
- `scripts/check.sh`
- `docs/deployment.md`
- `docs/tooling.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `script/README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `release-artifacts/latest/release-manifest.json`

Validation plan:

- `forge fmt` for touched Solidity scripts/tests.
- Focused Forge test for the rehearsal evidence.
- `forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir`.
- Generated release manifest/checksum/changelog drift checks after docs updates.
- Full local `make check` before opening the PR if runtime permits.

Current implementation notes:

- Added `script/RehearseAuctionCeremony.s.sol` with a local deterministic
  randomizer, auction EIP-712 authorization, active custody assertion, bid,
  with-bid settlement, poster/protocol/curator proceeds withdrawals, and
  zero-owed accounting evidence.
- Extended `test/StreamDeploymentManifest.t.sol` to assert the local auction
  ceremony evidence: chain ID, manifest hash, collection/drop/token IDs, final
  owner, highest bidder/bid, settled-with-bid status, 2/1/1 ETH proceeds split,
  and zero owed funds.
- Wired the auction ceremony into `make deploy-rehearsal`, Linux/Windows check
  wrappers, and the CI deployment rehearsal step.
- Updated deployment/tooling/status/blocker/test/script docs, changelog, and
  roadmap state to distinguish local Anvil ceremony evidence from remaining
  fork/testnet/live release evidence.
- Addressed CodeRabbit review findings by recording generated release artifacts
  in the candidate-file scope, asserting the deterministic randomizer wrote the
  expected token hash, and using ledger credits rather than gas-affected account
  balance deltas as proceeds evidence.

Validation completed:

- `forge fmt script\RehearseAuctionCeremony.s.sol test\StreamDeploymentManifest.t.sol`
- `forge test --match-path test\StreamDeploymentManifest.t.sol -vvv`
- `forge script script\RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `forge build`
- `forge test -vvv`
- `forge build --sizes --via-ir --skip test --skip script --force`
- `make check`
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh`
- PowerShell parser check for `scripts/check.ps1` and
  `scripts/bootstrap-windows.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --cached --check`
- Post-CodeRabbit fix validation:
  `forge fmt script\RehearseAuctionCeremony.s.sol test\StreamDeploymentManifest.t.sol`
- Post-CodeRabbit fix validation:
  `forge fmt --check script\RehearseAuctionCeremony.s.sol test\StreamDeploymentManifest.t.sol`
- Post-CodeRabbit fix validation:
  `forge test --match-path test\StreamDeploymentManifest.t.sol -vvv`
- Post-CodeRabbit fix validation:
  `forge script script\RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir`
- Post-CodeRabbit fix validation: `make check`
- Post-CodeRabbit fix validation: `git diff --check`

### PR candidate: Add deployment-rehearsal metadata browser coverage (Queue Item 72)

Status: merged in PR #139 after CI and CodeRabbit success.
Issue #135 selected after PR #138 merged and `main` advanced to
`9510a0f25bbdb61292644ab4ebdeba90e5d401fc`.
Branch `codex/live-fork-metadata-browser` started from that merge commit.
PR: `https://github.com/6529-Collections/6529Stream/pull/139`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/135`.

Goal:

- Add a local deployment-rehearsal metadata browser proof that is stronger than
  a committed fixture check but does not require RPC secrets.
- Deploy the local non-production stack, register a deterministic metadata
  dependency, mint through the EIP-712 drop authorization path, finalize token
  metadata inputs, extract the generated on-chain `tokenURI`, and execute the
  generated final animation in Chromium.
- Reuse the existing browser sandbox policy: deterministic dependency stub,
  unexpected-network rejection, bootstrap assertions, page/console error
  capture, and parent-frame isolation.
- Wire the unit and live rehearsal checks into Makefile, Windows/Unix wrapper
  checks, and CI.
- Update docs, roadmap, changelog, and this durable run state to distinguish
  local deployment-rehearsal proof from future fork/testnet/live production
  evidence.

Initial candidate files:

- `script/RehearseMetadataBrowser.s.sol`
- `scripts/check_metadata_browser_sandbox.py`
- `scripts/check_rehearsal_metadata_browser_sandbox.py`
- `scripts/test_rehearsal_metadata_browser_sandbox.py`
- `Makefile`
- `scripts/check.ps1`
- `scripts/check.sh`
- `.github/workflows/ci.yml`
- `docs/metadata.md`
- `docs/deployment.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `script/README.md`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation plan:

- `forge fmt script/RehearseMetadataBrowser.s.sol`
- `python -m py_compile scripts\check_metadata_browser_sandbox.py scripts\check_rehearsal_metadata_browser_sandbox.py scripts\test_rehearsal_metadata_browser_sandbox.py`
- `python scripts\test_rehearsal_metadata_browser_sandbox.py`
- `.venv-tools\Scripts\python.exe scripts\check_rehearsal_metadata_browser_sandbox.py`
- `make metadata-fixtures-check`
- Release manifest/checksum/changelog drift checks after docs and CI wiring.
- Full local `make check` before opening the PR if runtime permits.

Local validation:

- `forge fmt script/RehearseMetadataBrowser.s.sol` passed using the installed
  Foundry binary at `$HOME\.foundry\bin\forge.exe` because the current
  PowerShell session does not resolve `forge` on `PATH`.
- `forge build` passed after removing the oversized rehearsal evidence event
  and using the ABI return payload as the script/checker contract.
- `python -m py_compile scripts\check_metadata_browser_sandbox.py scripts\check_rehearsal_metadata_browser_sandbox.py scripts\test_rehearsal_metadata_browser_sandbox.py` passed.
- `python scripts\test_rehearsal_metadata_browser_sandbox.py` passed with 9
  focused tests, including direct and wrapped Forge ABI return decoding.
- `.venv-tools\Scripts\python.exe scripts\check_rehearsal_metadata_browser_sandbox.py`
  passed and validated local Anvil deployment-rehearsal metadata in Chromium.
- `make metadata-fixtures-check` passed and now exercises both committed fixture
  and local deployment-rehearsal browser sandbox checks.
- `python scripts\test_release_manifest.py`,
  `python scripts\generate_release_manifest.py --check`,
  `python scripts\test_release_checksums.py`,
  `python scripts\generate_release_checksums.py --check`, and
  `python scripts\check_changelog.py` passed after regenerating the release
  manifest/checksum bundle.
- Full `make check` passed.
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh`, PowerShell parser checks
  for `scripts/check.ps1` and `scripts/bootstrap-windows.ps1`, and
  `git diff --check` passed.

Review response validation:

- CodeRabbit review `4482738727` correctly identified that Forge JSON stdout
  should not be treated as a single JSON document. The checker now scans stdout
  for JSON object/array records and selects the record containing `returned`.
- Accepted both low-risk test nitpicks by adding an empty `tokenDataRaw`
  regression and a descriptive dynamic-import assertion message.
- `python -m py_compile scripts\check_rehearsal_metadata_browser_sandbox.py scripts\test_rehearsal_metadata_browser_sandbox.py` passed.
- `python scripts\test_rehearsal_metadata_browser_sandbox.py` passed with 11
  focused tests.
- `.venv-tools\Scripts\python.exe scripts\check_rehearsal_metadata_browser_sandbox.py`
  passed and validated local Anvil deployment-rehearsal metadata in Chromium.
- `make metadata-fixtures-check` passed with the rehearsal tests and browser
  checks.
- Full `make check` passed after the review fixes.
- `git diff --check` passed.

### PR candidate: Document dependency migration runbooks (Queue Item 71)

Status: merged in PR #138 after CodeRabbit review and CI success.
Issue #136 selected after PR #137 merged and stale umbrella issues #25, #30,
\#45, #46, #47, #48, #51, and #124 were closed with evidence comments. Branch
`codex/dependency-migration-runbook` started from `main` at PR #137 merge commit
`40ce3e31bdf4a9d8b137d4923662d5d1b5a2fa2b`.
PR: `https://github.com/6529-Collections/6529Stream/pull/138`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/136`.

Goal:

- Add a production dependency operations runbook covering proposal, review,
  packaging, registry registration, unfrozen collection repinning,
  deprecation, rollback by corrective version, frozen collection protection,
  and source-retention evidence.
- Link the runbook from metadata, deployment, release, and dependency artifact
  docs so operators can find it during release ceremonies.
- Include the runbook in the generated release manifest governance-doc evidence.
- Refresh release manifest and checksum artifacts because release docs and
  changelog evidence changed.
- Keep the PR docs/tooling scoped; no Solidity behavior changes are planned.

Initial candidate files:

- `docs/dependency-operations.md`
- `docs/metadata.md`
- `docs/deployment.md`
- `docs/release-policy.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `release-artifacts/README.md`
- `release-artifacts/dependencies/README.md`
- `scripts/generate_release_manifest.py`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `CHANGELOG.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation plan:

- `rg -n "dependency-operations|Dependency Operations|#136" docs release-artifacts ops CHANGELOG.md scripts`
- `python scripts/test_dependency_artifact_manifest.py`
- `python scripts/generate_dependency_artifact_manifest.py --check`
- `python scripts/test_release_manifest.py`
- `python scripts/generate_release_manifest.py --check`
- `python scripts/test_release_checksums.py`
- `python scripts/generate_release_checksums.py --check`
- `python scripts/check_changelog.py`
- `git diff --check`
- `make check`

Local validation:

- Link/reference grep passed for `dependency-operations`, `Dependency
  Operations`, and #136 across docs, release artifacts, ops, changelog, and
  scripts.
- Stale missing-runbook grep passed for previous production dependency runbook
  blocker language.
- `python scripts/test_dependency_artifact_manifest.py` passed.
- `python scripts/generate_dependency_artifact_manifest.py --check` passed.
- `python scripts/test_release_manifest.py` passed.
- `python scripts/generate_release_manifest.py --check` passed.
- `python scripts/test_release_checksums.py` passed.
- `python scripts/generate_release_checksums.py --check` passed.
- `python scripts/check_changelog.py` passed.
- `git diff --check` passed with the existing line-ending warning for the
  touched release-manifest generator.
- `make check` passed, including Foundry build/tests, production size,
  metadata fixture/browser-sandbox checks, release-artifact drift checks,
  changelog gate, and deployment rehearsal. Pre-existing compiler/lint warnings
  remained unchanged.

### PR candidate: Reconcile completed roadmap issues (Queue Item 70)

Status: Merged in PR #137; CI run `27393589713` passed, CodeRabbit completed
with no actionable comments on the final head, and squash merge
`40ce3e31bdf4a9d8b137d4923662d5d1b5a2fa2b` landed on `main`. Issue #134 was
closed through the PR merge. Issues #25, #30, #45, #46, #47, #48, #51, and
\#124 were closed manually with evidence comments after merge.

Original status: Issue #134 created; branch `codex/roadmap-issue-reconciliation`
started from `main` at PR #133 merge commit
`f583f7662dab2945b79a5c92d31ed74c5e227639`.
PR: `https://github.com/6529-Collections/6529Stream/pull/137`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/134`.
Follow-up issues created:
`https://github.com/6529-Collections/6529Stream/issues/135` for live/fork
metadata browser execution coverage and
`https://github.com/6529-Collections/6529Stream/issues/136` for production
dependency migration/source-retention runbooks.
CodeRabbit requested in PR comment `4687281642`.

Goal:

- Make `ops/ROADMAP.md` honest about broad issues whose original acceptance
  criteria are now satisfied by merged PR/test/docs evidence.
- Preserve true remaining work by moving it to focused follow-up issues instead
  of leaving stale umbrella blockers open.
- Record the PR #133 merge and current autonomous state before opening the next
  PR.
- Prepare post-merge closure comments for #25, #30, #45, #46, #47, #48, #51,
  and #124 if CodeRabbit and CI agree the reconciliation is clean.

Initial candidate files:

- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Validation plan:

- `rg -n "issues/(25|30|45|46|47|48|51|124|135|136)|#25|#30|#45|#46|#47|#48|#51|#124|#135|#136" ops/ROADMAP.md ops/AUTONOMOUS_RUN.md`
- `rg -n "^#|^##|^###" ops/ROADMAP.md ops/AUTONOMOUS_RUN.md`
- `git diff --check`

Local validation:

- Issue-reference grep passed and confirmed the reconciliation table plus #135
  and #136 follow-up links are present.
- Heading-order grep passed for `ops/ROADMAP.md` and
  `ops/AUTONOMOUS_RUN.md`.
- `git diff --check` passed.
- `make check` passed, including Foundry build/tests, production size,
  metadata fixture/browser-sandbox checks, release-artifact drift checks,
  changelog gate, and deployment rehearsal.

### PR candidate: Recover `StreamCore` release-floor bytecode headroom (Queue Item 69)

Status: Merged in PR #133; CI run `27393020740` passed, CodeRabbit completed
with no actionable comments on the final head, and squash merge
`f583f7662dab2945b79a5c92d31ed74c5e227639` landed on `main`.
Issue #132 closed through the PR merge.

Original status: Issue #132 created; branch `codex/streamcore-size-floor-recovery`
started from `main` at PR #131 merge commit
`3a6405d7d0cdc1d3550a8f872c6f17f3a0a147ac`.
PR: `https://github.com/6529-Collections/6529Stream/pull/133`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/132`.
Related issues: `https://github.com/6529-Collections/6529Stream/issues/115`,
`https://github.com/6529-Collections/6529Stream/issues/124`, and
`https://github.com/6529-Collections/6529Stream/issues/51`.

Goal:

- Recover the documented `StreamCore` release floor after PR #131 reduced
  EIP-170 headroom to 228 bytes.
- Preserve pending/stale/failed/final metadata behavior, unsupported lifecycle
  fallback, and final-hash override behavior.
- Prefer compiler-shaping or duplicated-helper reductions over feature changes.
- Update deterministic size evidence, release artifacts, docs, roadmap/test
  traceability, changelog, and this state file with the final measured size.

Initial candidate files:

- `smart-contracts/StreamCore.sol`
- `test/StreamMetadataGolden.t.sol`
- `test/StreamCoreCustomErrors.t.sol`
- `CHANGELOG.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `release-artifacts/latest/*`
- `deployments/address-books/*`
- `deployments/examples/*`

Validation plan:

- Measure each code candidate with
  `forge build --sizes --via-ir --skip test --skip script --force`.
- Run focused tests for touched behavior.
- Refresh deterministic release artifacts if bytecode changes.
- Run `make release-checksums`, `make release-checksums-check`,
  `make check`, Windows `scripts\check.ps1`, formatting, and whitespace checks
  before opening the PR.

Implementation notes:

- Moved collection-script and token-metadata freeze hash helpers from
  `StreamCore` into linked `StreamMetadataRenderer` functions, preserving the
  typed hash inputs and freeze manifest semantics.
- Replaced the old-randomizer lifecycle probe helper with equivalent low-level
  staticcalls so unsupported lifecycle providers still do not block migration,
  while lifecycle-aware providers whose pending-request probe fails still block
  replacement and preserve the old provider's revert data.
- Inlined final-token metadata checks, passed the known collection ID into
  token-name rendering, cached collection script storage in generative-script
  retrieval, and reused final supply in the freeze supply hash.
- Added focused `StreamRandomizerLifecycle.t.sol` regressions for unsupported
  lifecycle-provider migration and failed pending-request probes.
- CodeRabbit review `4482168726` left three nitpicks; follow-up clarified the
  inline lifecycle selector comments, documented the unsupported-lifecycle mock
  defensive revert, and asserted `CollectionRandomizerUpdated` events for both
  unsupported-provider migration steps.
- Current production size measurement:
  `forge build --sizes --via-ir --skip test --skip script --force` reports
  `StreamCore` at 24,139 runtime bytes with 437 bytes of EIP-170 headroom.

Local validation:

- `forge test --match-path test\StreamRandomizerLifecycle.t.sol -vvv`: 21
  tests passed.
- Focused metadata/freeze/burn sweep passed:
  `test\StreamRandomizerLifecycle.t.sol`, `test\StreamMetadataFreeze.t.sol`,
  `test\StreamMetadataGolden.t.sol`, and `test\StreamCoreBurn.t.sol`.
- `make release-checksums`: passed and regenerated deterministic release,
  source-verification, deployment, address-book, manifest, and checksum
  artifacts for the bytecode/source/docs changes.
- `make release-checksums-check`: passed.
- `make check`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`:
  passed.
- `forge fmt --check smart-contracts\StreamCore.sol
  smart-contracts\StreamMetadataRenderer.sol
  test\StreamRandomizerLifecycle.t.sol`: passed.
- `git diff --check`: passed.
- Post-CodeRabbit follow-up validation:
  `forge test --match-path test\StreamRandomizerLifecycle.t.sol -vvv` passed
  21 tests; `forge fmt --check smart-contracts\StreamCore.sol
  test\StreamRandomizerLifecycle.t.sol` passed; `git diff --check` passed;
  `make release-checksums` regenerated source-verification and checksum
  artifacts for the source/comment and state-file changes;
  `make release-checksums-check`, `make check`, and
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
  passed.

### PR #131: Stale and failed randomness metadata states (Queue Item 68)

Status: Issue #130 created; branch `codex/metadata-randomness-state-display`
started from `main` at PR #129 merge commit
`7ccc771017be46c9f60fb6114abaf88ca98368a5`.
PR: `https://github.com/6529-Collections/6529Stream/pull/131`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/130`.
Related issues: `https://github.com/6529-Collections/6529Stream/issues/46`,
`https://github.com/6529-Collections/6529Stream/issues/51`, and
`https://github.com/6529-Collections/6529Stream/issues/40`.
CodeRabbit requested in issue comments `4686592260` and `4686597476`.

Goal:

- Preserve `final` as the public metadata state only when `tokenToHash[tokenId]`
  is nonzero.
- Ask lifecycle-aware configured randomizers for token request state when a
  minted token is not final.
- Expose `stale` and `failed` metadata states for `Stale` and
  `FailedPostProcessing` request states.
- Keep unsupported, unavailable, or missing lifecycle data falling back to the
  existing `pending` behavior.
- Apply the same public state to `tokenMetadataState(tokenId)`, off-chain
  `tokenURI`, and schema-v1 on-chain JSON.
- Keep `animation_url` present only in final on-chain metadata.
- Add focused golden fixtures/tests, docs, roadmap/test traceability,
  changelog, and autonomous state updates.

Initial candidate files:

- `smart-contracts/StreamCore.sol`
- `test/StreamMetadataGolden.t.sol`
- `test/fixtures/metadata/`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`
- release artifacts after checksum refresh

Implementation notes:

- Added lifecycle-aware metadata state mapping in `StreamCore`:
  `Stale` maps to `stale`, `FailedPostProcessing` maps to `failed`, final token
  hashes always map to `final`, and failed/missing/malformed lifecycle lookups
  fall back to `pending`.
- Kept final off-chain token URIs as `collectionBaseURI + tokenId`; non-final
  off-chain URIs now use `pending`, `stale`, or `failed`.
- Kept final on-chain metadata as the only path that includes `animation_url`;
  pending, stale, and failed schema-v1 JSON omit final animation HTML while the
  token hash is zero.
- Added `MetadataLifecycleRandomizer` test coverage for stale/failed views,
  lookup failure fallback, and final-hash override.
- Added off-chain and on-chain golden fixtures for stale and failed states.
- Replaced the initial `try/catch` lifecycle lookup with a compact bounded
  `staticcall` so lookup failures still fall back to `pending` while limiting
  `StreamCore` bytecode growth.
- CodeRabbit review `4481745377` correctly asked for an explicit
  `supportsRandomizerLifecycle()` probe before the token state lookup; the final
  implementation gates selector-only randomizers that report unsupported back to
  `pending` and adds regression coverage.
- CodeRabbit review `4481745377` also asked for status docs to state that ADR
  0006 freeze eligibility excludes pending, stale, and failed live tokens; the
  docs now say that explicitly. The run-state `TBD` comment was stale because
  later state commits already recorded PR #131.
- Measured and rejected two local size experiments before docs/artifacts:
  replacing the burn approval string with a custom error increased Core size,
  and moving the lifecycle mapping to `StreamMetadataRenderer` reduced library
  pressure but increased `StreamCore` to 24,546 runtime bytes.
- Final measured implementation keeps the production size gate green with
  `StreamCore` at 24,348 runtime bytes and 228 bytes of EIP-170 headroom, below
  the documented 384-byte release floor; docs and roadmap now track this as
  size-budget debt before further non-trivial Core work.

Local validation:

- `forge test --match-path test\StreamMetadataGolden.t.sol -vvv`: 14 tests
  pass.
- `forge test --match-path test\StreamMetadataEvents.t.sol -vvv`: 10 tests
  pass during the rejected burn custom-error experiment; no event-test changes
  remain in the final diff.
- `forge build --sizes --via-ir --skip test --skip script --force`: passes with
  `StreamCore` at 24,348 runtime bytes and 228 bytes of EIP-170 headroom.
- `forge fmt smart-contracts\StreamCore.sol smart-contracts\StreamMetadataRenderer.sol test\StreamMetadataGolden.t.sol test\StreamMetadataEvents.t.sol`
  completed after the size experiments.
- `make release-checksums`: passes and refreshes deterministic release,
  deployment, address-book, source-verification, and checksum artifacts.
- `make release-checksums-check`: passes after artifact refresh.
- `make check`: passes with 226 Solidity tests, metadata fixture/browser
  checks, release-artifact drift checks, changelog gate, and deployment
  rehearsal.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`:
  passes with the same 226-test local gate on Windows.
- `forge fmt --check smart-contracts\StreamCore.sol test\StreamMetadataGolden.t.sol`:
  passes.
- `git diff --check`: passes.

### PR #129: Browser execution metadata sandbox checks (Queue Item 67)

Status: Merged; CI passed and CodeRabbit completed with no actionable comments
and all 5 pre-merge checks green.
Branch: `codex/metadata-browser-sandbox-checks`.
PR: `https://github.com/6529-Collections/6529Stream/pull/129`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/128`.
Umbrella issue: `https://github.com/6529-Collections/6529Stream/issues/51`.

Goal:

- Execute the committed final on-chain animation fixture in a real browser
  engine inside a documented sandbox harness.
- Stub the expected external dependency script request and fail any unexpected
  outbound request.
- Capture page errors and console errors as test failures.
- Prove the sandboxed frame cannot access the parent document.
- Pin/document the browser test dependency and wire the check into Linux,
  Windows, Makefile, and CI entry points.
- Update docs, roadmap traceability, changelog, and autonomous state.

Initial candidate files:

- `scripts/check_metadata_browser_sandbox.py`
- `scripts/test_metadata_browser_sandbox.py`
- `requirements-tools.txt`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `.github/workflows/ci.yml`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`

Implementation notes:

- Added `scripts/check_metadata_browser_sandbox.py`, which loads the committed
  final on-chain metadata fixture, decodes the final `animation_url`, launches
  Chromium through Playwright, renders the exact data URI in an
  `allow-scripts` sandboxed iframe, fulfills the single expected dependency URL
  with a deterministic stub, aborts unexpected HTTP(S) requests, captures page
  and console errors, asserts the expected hash/token bootstrap values, and
  verifies parent-document access fails with `SecurityError`.
- Added `scripts/test_metadata_browser_sandbox.py` for unit coverage of fixture
  loading, sandbox harness shape, happy-path browser result validation, duplicate
  dependency requests, unexpected outbound requests, page errors, wrong
  bootstrap values, and missing/wrong parent isolation errors without launching
  a browser.
- Pinned `playwright==1.60.0` in `requirements-tools.txt`; updated Windows and
  EC2 bootstrap scripts to install Chromium; updated `scripts/check.ps1` and
  `scripts/check.sh` to prefer `.venv-tools` Python when available.
- Wired the browser sandbox unit/check scripts into `make metadata-fixtures-check`,
  `scripts/check.ps1`, `scripts/check.sh`, and the GitHub CI metadata fixture
  safety job.
- Updated metadata docs, status/blocker docs, test README, changelog, roadmap
  traceability, and this state file to distinguish committed-fixture browser
  proof from broader future live/fork browser coverage.

Focused local validation:

- `python -m py_compile scripts\check_metadata_browser_sandbox.py scripts\test_metadata_browser_sandbox.py scripts\check_metadata_fixtures.py scripts\test_metadata_fixtures.py` passes.
- `python scripts\test_metadata_browser_sandbox.py` passes.
- `python scripts\test_metadata_fixtures.py` passes.
- `.venv-tools\Scripts\python.exe scripts\check_metadata_browser_sandbox.py`
  passes after installing pinned Playwright and Chromium.
- `.venv-tools\Scripts\python.exe scripts\check_metadata_fixtures.py` passes.
- `make metadata-fixtures-check` passes.
- `make release-checksums` regenerated release manifest/checksum artifacts for
  the new scripts/docs/tooling.
- `make release-checksums-check` passes.
- Bash syntax check for `scripts/check.sh` and `scripts/bootstrap-ec2.sh`
  passes.
- Windows PowerShell parser check for `scripts\check.ps1` and
  `scripts\bootstrap-windows.ps1` passes.
- `git diff --check` passes with expected Git CRLF conversion notices for the
  Windows scripts.
- `make check` passes.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passes.

CodeRabbit review response:

- Updated the durable run-state timestamp and active-PR evidence.
- Added docstrings across the browser sandbox checker and unit tests to satisfy
  the repository docstring coverage gate.
- Expanded `scripts/test_metadata_browser_sandbox.py` to cover console errors,
  unloaded dependency stubs, wrong script counts, wrong hash/token bootstrap
  values, wrong token-data tuples, and missing draw functions.
- Revalidated with `python -m py_compile`, the expanded 16-test browser sandbox
  unit suite, the live browser sandbox check, `make metadata-fixtures-check`,
  `make release-checksums-check`, `git diff --check`, and full `make check`.

### PR #127: Core UTF-8 enforcement headroom (Queue Item 66)

Status: Merged; CI passed and CodeRabbit completed with no actionable comments
and all 5 pre-merge checks green.
Branch: `codex/core-utf8-headroom`.
PR: `https://github.com/6529-Collections/6529Stream/pull/127`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/125`.
Umbrella issue: `https://github.com/6529-Collections/6529Stream/issues/51`.

Goal:

- Enforce strict UTF-8 for `StreamCore` production metadata inputs covered by
  existing size guards.
- Preserve size-before-UTF-8 error ordering.
- Keep valid ASCII and valid multibyte UTF-8 inputs accepted.
- Keep `StreamCore` under the production EIP-170 size gate with documented
  headroom evidence.
- Update tests, status docs, roadmap traceability, changelog, and release
  artifacts with deployable implementation evidence.

Initial candidate files:

- `smart-contracts/StreamCore.sol`
- `smart-contracts/StreamMetadataRenderer.sol`
- `test/StreamMetadataUtf8.t.sol`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`
- release artifacts after checksum refresh

Implementation notes:

- Reused the linked `StreamMetadataRenderer` library for size-aware production
  guards: strict UTF-8 byte caps, content/script URI checks, raw-attribute UTF-8
  checks, collection URI validation, generated `tokenURI` size validation,
  contract marker probes, and metadata pause checks.
- Updated `StreamCore` collection and token metadata mutation paths so
  collection text fields, collection scripts, token data, token image values,
  and token raw attributes reject invalid UTF-8 in production.
- Preserved size-before-UTF-8 ordering by routing existing byte-limit checks
  through the shared renderer guard before the UTF-8 scanner reports invalid
  sequences.
- Recovered final Core size headroom by replacing inherited `_requireMinted`
  string reverts with the compact `TokenNotMinted()` selector for Core metadata
  paths.

Local evidence:

- `forge test --match-path test/StreamMetadataUtf8.t.sol -vvv`: 12 tests pass.
- `forge test --match-path test/StreamCoreCustomErrors.t.sol -vvv`: 6 tests
  pass.
- `forge test --match-path test/StreamMetadataUriPolicy.t.sol -vvv`: 8 tests
  pass after fixing selector-preserving library reverts.
- Production size measurement after implementation: `StreamCore` 24,160 runtime
  bytes with 416 bytes of EIP-170 headroom.
- `make release-checksums`: passes and refreshes deterministic release,
  deployment, address-book, source-verification, and checksum artifacts.
- `make check`: passes.
- `scripts\check.ps1`: passes.
- `forge fmt --check` on touched Solidity/test files and `git diff --check`
  pass.

### PR #126: Dependency registry UTF-8 enforcement (Queue Item 65)

Status: Merged; CI passed and CodeRabbit posted pre-merge checks with no
actionable review threads. Merge proceeded under the autonomous maintainer rule
after CodeRabbit's commit status remained pending but no findings were present.
Branch: `codex/metadata-utf8-production`.
PR: `https://github.com/6529-Collections/6529Stream/pull/126`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/124`.
Core size-gated follow-up:
`https://github.com/6529-Collections/6529Stream/issues/125`.
Umbrella issue: `https://github.com/6529-Collections/6529Stream/issues/51`.

Goal:

- Add a shared strict UTF-8 scanner for metadata safety checks.
- Reject invalid UTF-8 dependency script chunks and provenance in
  `DependencyRegistry` with typed field errors.
- Preserve size-before-UTF-8 error ordering for oversized dependency fields.
- Keep valid ASCII and valid multibyte UTF-8 dependency metadata working.
- Record that `StreamCore` production UTF-8 enforcement remains blocked by
  EIP-170 headroom until issue #125 recovers size or accepts a split design.

Candidate files:

- `smart-contracts/StreamMetadataRenderer.sol`
- `smart-contracts/DependencyRegistry.sol`
- `test/StreamMetadataUtf8.t.sol`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`
- release artifacts after checksum refresh

Validation started at `2026-06-11 22:20 UTC`:

- `forge build --sizes --via-ir --skip test --skip script --force`
- `forge fmt --check smart-contracts\DependencyRegistry.sol smart-contracts\StreamMetadataRenderer.sol test\StreamMetadataUtf8.t.sol`
- `forge test --match-path test\StreamMetadataUtf8.t.sol -vvv`
- `forge test --match-path test\StreamDependencyRegistry.t.sol -vvv`
- `make release-checksums`
- `make check`
- `make release-manifest-check`
- `make release-checksums-check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check`
- `bash -n scripts/check.sh`

Notes:

- Initial direct `StreamCore._requireMaxBytes` UTF-8 enforcement made the
  production size gate fail at 25,755 runtime bytes, 1,179 bytes over EIP-170.
- Registry-backed and inlined Core experiments were also rejected locally
  because they increased `StreamCore` runtime size further.
- Issue #125 now tracks the required Core headroom/design work.
- The narrowed dependency-registry slice keeps `StreamCore` unchanged at 24,135
  runtime bytes with 441 bytes of EIP-170 headroom and linked
  `StreamMetadataRenderer` at 8,976 runtime bytes.
- Focused UTF-8 tests pass with 6 tests: valid ASCII/multibyte acceptance,
  invalid lead/continuation/overlong/surrogate/out-of-range/truncated
  rejection, dependency script/provenance rejection, and size-before-UTF-8
  ordering.
- `make release-checksums` refreshed release/deployment artifacts for the
  `DependencyRegistry` ABI/custom-error delta, linked renderer bytecode delta,
  docs/changelog/state updates, and new UTF-8 test file.
- Full `make check` passes after the narrowed dependency-registry
  implementation, new UTF-8 suite, docs updates, and release artifact refresh.
- Windows `scripts\check.ps1` passes on the same narrowed slice, including the
  6-test `StreamMetadataUtf8.t.sol` suite and release artifact drift checks.

Outcome:

- Merged as PR #126 on `2026-06-11 23:07 UTC`.
- Squash commit: `2865658049ca648f15048dc53862b650558e3da9`.
- Issue #125 remains open for the `StreamCore` production UTF-8 slice.

### PR #123: Production raw attribute schema enforcement (Queue Item 64)

Status: Merged; CodeRabbit whitespace-only raw attribute fix passed full local
validation and CI before merge.
Branch: `codex/metadata-attribute-schema`.
PR: `https://github.com/6529-Collections/6529Stream/pull/123`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/122`.
Umbrella issue: `https://github.com/6529-Collections/6529Stream/issues/51`.

Goal:

- Close the production raw-attribute enforcement gap left after the fixture-only
  semantic attribute checks in PR #121.
- Preserve the existing empty-fragment and comma-separated object fragment
  format used by on-chain metadata.
- Require every nonempty production raw attribute object to contain exactly
  `trait_type` and `value` keys with JSON string values.
- Reject missing keys, unexpected keys, duplicate keys, non-string values,
  invalid JSON string escapes, malformed separators, controls, unterminated
  strings, and array/object breakout attempts with `UnsafeRawAttributes`.
- Keep production invalid UTF-8 policy and full browser execution sandboxing as
  separate P1-META-006 follow-up work.

Candidate files:

- `smart-contracts/StreamMetadataRenderer.sol`
- `test/StreamMetadataEscaping.t.sol`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/abi-checksums.json`
- `release-artifacts/latest/release-artifact-manifest.json`
- `release-artifacts/latest/release-checksums.json`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/source-verification-inputs.json`
- `deployments/address-books/anvil-6529stream-v0.1.0-001.json`
- `deployments/address-books/anvil-6529stream-v0.1.0-001-broadcast.json`
- `deployments/examples/anvil-6529stream-v0.1.0-001.json`
- `deployments/examples/anvil-6529stream-v0.1.0-001-broadcast.json`

Validation started at `2026-06-11 21:16 UTC`:

- Bootstrapped pinned Foundry `v1.7.1` locally with
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1`
  after direct `forge` commands were missing from PATH.
- `forge fmt smart-contracts\StreamMetadataRenderer.sol test\StreamMetadataEscaping.t.sol`
- `forge fmt --check smart-contracts\StreamMetadataRenderer.sol test\StreamMetadataEscaping.t.sol`
- `forge test --match-path test\StreamMetadataEscaping.t.sol -vvv`
- `make release-checksums`
- `make check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check`
- `bash -n scripts/check.sh`
- `make release-manifest-check`
- `make release-checksums-check`

Notes:

- The first focused test run found that the drafted "trailing backslash" fixture
  was actually valid escaped JSON. The test was corrected to a short Unicode
  escape case, and the focused metadata suite then passed with 15 tests.
- `make release-checksums` reports `StreamCore` unchanged at 24,135 runtime
  bytes with 441 bytes of EIP-170 headroom. The linked
  `StreamMetadataRenderer` grows to 8,584 runtime bytes, and release/deployment
  artifacts were regenerated for the bytecode/docs/changelog/state delta.
- After this state update, `make release-checksums`,
  `make release-manifest-check`, and `make release-checksums-check` were rerun
  sequentially. The sequential artifact checks passed without the transient
  Foundry cache access warning produced by an earlier parallel local invocation.
- CodeRabbit found that whitespace-only nonempty raw attributes still passed
  because the parser skipped spaces before the empty-input decision. The
  follow-up keeps the true empty fragment allowed, rejects whitespace-only
  nonempty fragments, and adds regression coverage before refreshing artifacts.
- The CodeRabbit follow-up passes `forge fmt --check`, the focused
  `test/StreamMetadataEscaping.t.sol` suite with 15 tests, `make
  release-manifest-check`, `make release-checksums-check`, and
  `git diff --check`. `StreamCore` remains 24,135 runtime bytes with 441 bytes
  of headroom; linked `StreamMetadataRenderer` is now 8,591 runtime bytes with
  15,985 bytes of headroom.
- A full `make check` also passed after the CodeRabbit fix and refreshed
  artifacts.

### PR candidate: Metadata fixture UTF-8 and semantic attributes (Queue Item 63)

Status: Merged in PR #121 at `2026-06-11 21:01 UTC`.
Branch: `codex/metadata-fixture-utf8-attributes`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/121`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/119`.
Attached issue: `https://github.com/6529-Collections/6529Stream/issues/120`.

Goal:

- Harden the committed metadata fixture gate for remaining `P1-META-006`
  safety gaps that do not require production bytecode changes.
- Add focused negative tests proving invalid UTF-8 JSON/HTML data URI payloads
  fail fixture validation.
- Add semantic attribute-shape tests proving unexpected keys and non-string
  values fail fixture validation.
- Update docs, roadmap, and this state file to distinguish fixture-level
  semantic validation from the then-open production raw-attribute and browser
  execution work.
- Pin release-artifact, JavaScript, and Python text files to LF in
  `.gitattributes` so dependency artifact source hashes and generated release
  files remain deterministic on Windows and Linux checkouts.

Candidate files:

- `.gitattributes`
- `scripts/test_metadata_fixtures.py`
- `docs/metadata.md`
- `docs/status.md`
- `test/README.md`
- `release-artifacts/README.md`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `release-artifacts/latest/release-manifest.json`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`

Validation completed at `2026-06-11 20:34 UTC`:

- `python scripts\test_metadata_fixtures.py`
- `python scripts\check_metadata_fixtures.py`
- `make metadata-fixtures-check`
- `python scripts\generate_dependency_artifact_manifest.py --check`
- `python scripts\test_dependency_artifact_manifest.py`
- `python -m py_compile scripts\check_metadata_fixtures.py scripts\test_metadata_fixtures.py scripts\generate_dependency_artifact_manifest.py scripts\test_dependency_artifact_manifest.py`
- `make release-checksums`
- `make release-manifest-check`
- `make release-checksums-check`
- `python scripts\check_changelog.py`
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
- `bash -n scripts/check.sh`
- `git diff --check`

Notes:

- `StreamCore` remains at 24,135 runtime bytes with 441 bytes of EIP-170
  headroom.
- The full local gate passes with existing compiler, natspec, and lint warnings;
  no Solidity source or bytecode changes are included in this slice.

### PR #118: Add dependency artifact manifest packaging (Queue Item 62)

Status: Merged.
Branch: `codex/dependency-artifact-manifest`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/118`.
Issue: `https://github.com/6529-Collections/6529Stream/issues/117`.

Goal:

- Package dependency registry source artifacts in deterministic release files so
  future drops do not rely on provenance strings alone.
- Add a generated dependency artifact manifest under `release-artifacts/latest/`
  and make local/CI checks fail on descriptor or generated-output drift.
- Include the generated dependency artifact manifest in the top-level release
  manifest and include dependency descriptor/source files in release checksums.
- Keep this slice off the Solidity bytecode path; no contract changes are
  planned.

Candidate files:

- `release-artifacts/dependencies/`
- `release-artifacts/latest/dependency-artifact-manifest.json`
- `scripts/generate_dependency_artifact_manifest.py`
- `scripts/test_dependency_artifact_manifest.py`
- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `scripts/generate_release_checksums.py`
- `scripts/test_release_checksums.py`
- `Makefile`
- `docs/metadata.md`
- `docs/status.md`
- `release-artifacts/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`

Validation:

- `python scripts\test_dependency_artifact_manifest.py` and
  `python scripts\generate_dependency_artifact_manifest.py --check` passed.
- Release artifact, release manifest, and release checksum focused tests/checks
  passed.
- `python -m py_compile` passed for touched Python scripts.
- `make release-checksums` regenerated committed release artifacts and kept
  `StreamCore` at 24,135 runtime bytes with 441 bytes of EIP-170 headroom.
- `make check` passed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `bash -n scripts/check.sh` passed.
- `git diff --check` passed, with only known Windows line-ending warnings for
  generated/touched files such as `release-artifacts/latest/SHA256SUMS`.

### PR #116: Recover `StreamCore` bytecode headroom (Queue Item 61)

Status: Merged as PR `#116`.
Branch: `codex/recover-streamcore-headroom`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/116`.

Goal:

- Recover sustainable `StreamCore` runtime bytecode margin before further
  non-trivial Core feature work.
- Preserve public success behavior and ABI compatibility while documenting the
  intentional revert-data change from selected string reverts to typed custom
  errors.
- Set the current Core size policy in repo docs: 384 bytes is the minimum
  release floor under the production IR size gate, and 512 bytes is the warning
  threshold for future non-trivial Core work.
- Regenerate release artifacts because the `StreamCore` ABI and bytecode change.

Candidate files:

- `smart-contracts/StreamCore.sol`
- `test/StreamCoreCustomErrors.t.sol`
- `docs/status.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`
- `release-artifacts/latest/`

Validation:

- `forge test --match-contract StreamCoreCustomErrorsTest -vvv` passed with
  5 tests covering `FunctionAdminUnauthorized()`,
  `ArtistSignatureUnauthorized()`, `InvalidTokenMetadataInput()`, and
  `FinalSupplyTimeNotPassed()`, plus `setFinalSupply` rejection when collection
  data is missing.
- `forge build --sizes --via-ir --skip test --skip script --force` passed;
  final measured `StreamCore` runtime size is 24,135 bytes with 441 bytes of
  EIP-170 headroom.
- `make release-checksums` passed and regenerated release/deployment artifacts.
- `make check` passed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `forge fmt --check smart-contracts\StreamCore.sol
  test\StreamCoreCustomErrors.t.sol` passed.
- `git diff --check` passed, with only the known Windows line-ending warning
  for `release-artifacts/latest/SHA256SUMS`.

Notes:

- A separate `burn` authorization custom-error experiment increased runtime
  size by 20 bytes versus the first pass, so it was intentionally dropped.
- CodeRabbit found that `setFinalSupply` could reach final supply math for a
  created collection with missing collection data. The fix now checks the
  existing mutable collection boundary, rejects missing data with
  `CollectionDataMissing(collectionId)`, and keeps the size floor above 384
  bytes by collapsing duplicated `setCollectionData` writes through a storage
  pointer.
- The recovery is intentionally narrow: no contract state layout, external
  function signatures, event signatures, or successful-path behavior changed.

### PR #114: Collection URI production enforcement (Queue Item 60)

Status: Merged in PR #114.
Branch: `codex/metadata-collection-uri-policy`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/114`.

Goal:

- Enforce the renderer content/script URI policy for collection base URI and
  external collection library URL writes in `StreamCore` production paths.
- Preserve existing optional-field behavior: empty collection base URI and empty
  external library URL remain valid, but unsafe non-empty values revert with
  `UnsafeMetadataURI()`.
- Keep the change deployable under EIP-170. A direct policy-only implementation
  exceeded the runtime size limit, so this slice also replaces older
  security-relevant `StreamCore` string reverts with custom errors.
- Update metadata docs, roadmap, changelog, tests, release artifacts, and run
  state to make the new boundary auditable.

Candidate files:

- `smart-contracts/StreamCore.sol`
- `smart-contracts/StreamMetadataRenderer.sol`
- `test/StreamMetadataUriPolicy.t.sol`
- `test/StreamInitialization.t.sol`
- `test/StreamDependencyRegistry.t.sol`
- `test/StreamMetadataFreeze.t.sol`
- `test/StreamMetadataGolden.t.sol`
- `docs/metadata.md`
- `docs/known-blockers.md`
- `docs/status.md`
- `docs/adr/0006-metadata-freeze.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`

Validation:

- `forge build --sizes --via-ir --skip test --skip script --force` passed with
  `StreamCore` runtime size 24,348 bytes and 228 bytes of EIP-170 headroom.
- `forge test --match-path test\StreamMetadataUriPolicy.t.sol -vvv` passed.
- `forge test --match-path test\StreamMetadataFreeze.t.sol -vvv` passed.
- `forge test --match-path test\StreamMetadataGolden.t.sol -vvv` passed.
- `make release-checksums` passed and regenerated release/deployment artifacts.
- First post-doc-polish `make check` caught release-manifest checksum drift;
  reran `make release-checksums` and committed the regenerated artifacts.
- Final `make check` passed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- Targeted `forge fmt --check` passed for touched Solidity files.
- `git diff --check` passed, with only the existing Windows line-ending warning
  for `release-artifacts/latest/SHA256SUMS`.
- CodeRabbit PR #114 review found two valid issues: full collection metadata
  updates validated but did not persist `collectionBaseURI`, and direct
  high-level marker probes could bypass typed errors for EOAs or non-conforming
  contracts. The local fix persists base URI on full updates, moves a compact
  marker `staticcall` helper into `StreamMetadataRenderer` to preserve Core
  bytecode headroom, and adds focused regressions in
  `test/StreamMetadataUriPolicy.t.sol`.
- Review-fix focused validation passed:
  `forge test --match-path test\StreamMetadataUriPolicy.t.sol -vvv`,
  `forge test --match-path test\StreamMetadataFreeze.t.sol -vvv`,
  `forge test --match-path test\StreamMetadataGolden.t.sol -vvv`,
  `forge test --match-path test\StreamRandomizerLifecycle.t.sol -vvv`, and
  `forge build --sizes --via-ir --skip test --skip script --force`; after the
  fix `StreamCore` is 24,515 runtime bytes with 61 bytes of EIP-170 headroom.
- Review-fix release validation passed before this final state refresh:
  `make release-checksums`, `make check`,
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`, targeted
  `forge fmt --check`, and `git diff --check` with only the existing Windows
  line-ending warning for `release-artifacts/latest/SHA256SUMS`.
- CI run `27366884724` passed on head `857e1f9`. CodeRabbit acknowledged the
  review fixes and raised the now-small `StreamCore` EIP-170 margin as a
  near-term tracking risk; issue
  [`#115`](https://github.com/6529-Collections/6529Stream/issues/115) now tracks
  bytecode headroom recovery, and `ops/ROADMAP.md` records the release risk.
- Documentation-only bytecode-headroom follow-up validation passed:
  `make release-checksums` and `make check`; release artifacts did not drift
  from the `ops/ROADMAP.md` / `ops/AUTONOMOUS_RUN.md` edits.
- CodeRabbit's outside-diff comments were rechecked against current head and
  accepted as valid. The local follow-up rejects first-time zero collection
  supply before `reservedMaxTokensIndex` arithmetic, rejects dependency registry
  swaps to non-contract targets with `InvalidDependencyRegistryContract()`, and
  adds focused regressions in `test\StreamInitialization.t.sol` and
  `test\StreamDependencyRegistry.t.sol`.
- Outside-diff follow-up focused validation passed:
  `forge test --match-path test\StreamInitialization.t.sol -vvv`,
  `forge test --match-path test\StreamDependencyRegistry.t.sol -vvv`, and
  `forge build --sizes --via-ir --skip test --skip script --force`. Current
  `StreamCore` runtime size is 24,545 bytes with 31 bytes of EIP-170 headroom.
- Outside-diff follow-up release/full validation passed:
  `make release-checksums`, `make check`,
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`, targeted
  `forge fmt --check`, and `git diff --check` with only the known Windows
  line-ending warning for `release-artifacts/latest/SHA256SUMS`.

Notes:

- The first local queue-item 60 implementation exceeded EIP-170 by 331 bytes
  after collapsing the full collection URI check into the renderer helper.
  Replacing old `StreamCore` metadata/mint/randomizer/wiring string reverts
  with custom errors made the enforcement deployable and improved revert
  traceability.
- Remaining P1-META-006 work after this slice: semantic/structured attributes,
  invalid UTF-8 policy, full browser execution sandboxing, stale-state display
  policy, and dependency artifact/migration runbooks.

### PR candidate: Metadata token image URI policy (Queue Item 59)

Status: Merged in PR #113.
Branch: `codex/metadata-uri-policy`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/113`.

Goal:

- Define reusable renderer helpers for the current safe content/script URI
  policy rather than keeping the policy only in Python fixture checks.
- Reject unsafe required token image URI inputs in `StreamCore` before storage.
- Record that collection base URI and external animation library URL production
  enforcement exceeded the current `StreamCore` EIP-170 budget in the first
  local implementation attempt and must remain a follow-up slice unless more
  production bytecode is freed.
- Keep this slice tightly scoped to URI policy so invalid UTF-8 handling,
  semantic/structured attributes, and full browser execution sandboxing remain
  separate P1-META-006 follow-up work.
- Verify the change does not break the tight `StreamCore` EIP-170 size budget.
- Update docs, roadmap, changelog, and run-state traceability.

Candidate files:

- `smart-contracts/StreamCore.sol`
- `smart-contracts/StreamMetadataRenderer.sol`
- `test/StreamMetadataUriPolicy.t.sol`
- `docs/metadata.md`
- `docs/known-blockers.md`
- `docs/status.md`
- `docs/adr/0006-metadata-freeze.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`

Validation:

- `forge test --match-path test/StreamMetadataUriPolicy.t.sol -vvv` passed.
- `forge test --match-path test/StreamMetadataEscaping.t.sol -vvv` passed.
- `forge test --match-path test/StreamMetadataSizeLimits.t.sol -vvv` passed
  after the accepted boundary image fixture was updated to a valid exact-length
  `ipfs://` URI.
- `forge build --sizes --via-ir --skip test --skip script --force` passed with
  `StreamCore` runtime size 24,508 bytes and 68 bytes of EIP-170 headroom.
- `make release-checksums` passed and regenerated release/deployment artifacts.
- `make check` passed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- Targeted `forge fmt --check` passed for this PR's touched Solidity files.
- `git diff --check` passed, with only the existing Windows line-ending warning
  for `release-artifacts/latest/SHA256SUMS`.

Notes:

- A first local implementation also enforced collection base URI and external
  animation library URL writes, but pushed `StreamCore` over EIP-170 by 468
  bytes. The deployable scope was narrowed to token image production enforcement
  plus renderer helpers; the remaining collection/library surfaces stay queued
  for a later bytecode-saving slice.
- Broad `forge fmt --check smart-contracts` still reports pre-existing
  formatting drift in vendored/support contracts outside this PR's touched
  files; the full project check gate does not currently include that broad
  formatter target.

Outcome:

- Awaiting CI and CodeRabbit.

### PR #112: Metadata render-sandbox fixture checks (Queue Item 58)

Status: Merged in PR #112 as
`419fb1db67cd329afeea7f9c17ccd67c3b4b477c`.
Branch: `codex/metadata-render-sandbox-checks`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/112`.

Goal:

- Decode committed metadata golden fixtures and validate JSON/data-URI structure.
- Decode final on-chain animation HTML and validate wrapper/script boundaries.
- Assert current URI scheme policy for off-chain token URI fixtures, on-chain
  JSON `image`, generated `animation_url`, and generated external script source.
- Wire the fixture safety check into local and CI gates without adding runtime
  bytecode to `StreamCore`.
- Update docs, roadmap, changelog, and run-state traceability.

Candidate files:

- `scripts/check_metadata_fixtures.py`
- `scripts/test_metadata_fixtures.py`
- `Makefile`
- `.github/workflows/ci.yml`
- `scripts/check.sh`
- `scripts/check.ps1`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`
- `CHANGELOG.md`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/release-checksums.json`
- `release-artifacts/latest/SHA256SUMS`

Validation:

- `python scripts\test_metadata_fixtures.py` passes.
- `python scripts\check_metadata_fixtures.py` passes.
- `python -m py_compile scripts\check_metadata_fixtures.py scripts\test_metadata_fixtures.py` passes.
- `bash -n scripts/check.sh scripts/bootstrap-ec2.sh` passes.
- PowerShell parser validation passes for `scripts\check.ps1` and
  `scripts\bootstrap-windows.ps1`.
- `python scripts\test_changelog_check.py` and
  `python scripts\check_changelog.py` pass.
- `git diff --check` passes.
- `make release-checksums` refreshed the release manifest and checksum bundle.
- Full `make check` passes.
- Windows `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passes.

Outcome:

- CI run `27359975388` passed, CodeRabbit status was success, and the only
  actionable review thread was resolved after the empty-image regression fix.

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
  \#23 merged, because PR #23 had already updated ADR 0001 with the requested
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

Status: Merged in PR #82.
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
- CodeRabbit comment `4675512759` reported the implementation correct and
  complete for scope, then suggested low-risk extra coverage. The follow-up
  adds the pre-mint `setTokenHash` no-event regression, two-token
  `updateImagesAndAttributes` event coverage, and a short comment explaining
  the `_exists` guard.
- CodeRabbit inline review thread `PRRT_kwDOM7REis6IpTxK` / discussion
  `3392151522` correctly noted that negative-path tests could miss unexpected
  ERC-4906 emissions with different token payloads. The follow-up now asserts
  the raw `MetadataUpdate` and `BatchMetadataUpdate` topics are absent for
  mint-only, pre-mint hash storage, empty-collection metadata changes, burns,
  and post-burn hash storage.
- Added a post-burn `setTokenHash` regression proving the hash can still be
  recorded by an authorized randomizer without announcing metadata for a burned
  token.
- Added a short collection-range helper comment documenting that collection
  circulation supply is a minted-ever counter, so burns are represented by
  ERC-721 transfer events rather than ERC-4906 collection-range shrink events.

Validation:

- Focused ERC-4906 metadata event tests passed:
  `forge test --match-contract StreamMetadataEventsTest -vvv` with 9 tests.
- Full canonical local gate passed: `make check` with 210 tests, 0 failed.
- Windows wrapper passed:
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` with 210 tests,
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
- CodeRabbit rerun requested in comment `4675504591` after the state commit
  changed the PR head.
- CodeRabbit review comment `4675512759` found the implementation correct and
  complete for the stated scope; low-risk coverage suggestions were accepted
  and implemented locally.
- CodeRabbit inline review thread `PRRT_kwDOM7REis6IpTxK` / review
  `4472309839` identified the raw-topic negative-test gap; the local follow-up
  was pushed in commit `87e9634bb93681db7ffe3e9dec5bfcfd657614c5`.
- CodeRabbit latest-head comment `4675594572` confirmed all review items were
  addressed, the thread was resolved, and no concerns remained.
- GitHub Actions CI passed in run `27312549432`.
- The aggregate CodeRabbit commit status stayed pending after the clean
  latest-head review, so PR comment `4675606561` documented the autonomous
  maintainer merge decision using green CI, resolved threads, and explicit
  CodeRabbit approval evidence.
- Claude remains intentionally skipped per current user instruction; use
  CodeRabbit unless risk or future user instruction changes.

Merge:

- Squash merge commit: `944f614688ea15ec6cd7317a940978dfa9aaeeb3`.
- Merged at `2026-06-10 23:20 UTC`.
- Issue `#49` closed by PR merge.

### PR #83: Add schema-v1 metadata state outputs (Queue Item 40)

Status: Merged.
Branch: `codex/metadata-schema-state`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/83`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/46`

Goal:

- Continue P1-META-001 after the current-output golden baseline.
- Add an explicit `metadata_schema_version` field to on-chain JSON.
- Add an explicit `metadata_state` field for pending and final on-chain JSON.
- Base64-encode on-chain JSON data URIs.
- Stop pending on-chain metadata from running final generative HTML with a zero
  token hash.
- Expose public schema/state views for tests and integrators.
- Update golden fixtures, docs, roadmap, and test traceability.

Candidate files:

- `smart-contracts/StreamCore.sol`
- `test/StreamMetadataGolden.t.sol`
- `test/fixtures/metadata/onchain-pending-schema-v1-token-uri.txt`
- `test/fixtures/metadata/onchain-final-schema-v1-token-uri.txt`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Added `METADATA_SCHEMA_VERSION = "6529stream-v1"` plus public
  `metadataSchemaVersion()` and `tokenMetadataState(tokenId)` views.
- Off-chain token URI behavior remains compatibility-preserving:
  `baseURI + "pending"` before final randomness and `baseURI + tokenId` after
  final randomness.
- On-chain token URI output now uses `data:application/json;base64,`.
- Pending on-chain JSON includes `metadata_state: "pending"` and omits
  `animation_url`.
- Final on-chain JSON includes `metadata_state: "final"` and preserves the
  existing base64 HTML animation URL.
- CodeRabbit correctly noted that `bytes32(0)` is now the pending sentinel, so
  `setTokenHash` must reject zero hashes at the randomizer write boundary.
- Added the nonzero-hash guard plus a regression proving a configured
  randomizer cannot finalize a token with `bytes32(0)` and the metadata state
  remains pending after the rejected write.
- This PR intentionally leaves JSON escaping, raw-attribute validation, stale
  state display, freeze manifests, dependency immutability, and burn semantics
  to the remaining P1-META issues.

Validation so far:

- Focused metadata golden tests passed:
  `forge test --match-contract StreamMetadataGoldenTest -vvv` with 6 tests,
  0 failed, after the CodeRabbit zero-hash guard fix.
- Full canonical local gate passed: `make check` with 212 tests, 0 failed.
- Windows wrapper passed:
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` with 212 tests,
  0 failed.
- Touched-file formatting passed:
  `forge fmt --check smart-contracts\StreamCore.sol test\StreamMetadataGolden.t.sol`.
- Diff whitespace check passed: `git diff --check`.
- Markdown heading scan passed for `docs\metadata.md`, `docs\status.md`,
  `docs\known-blockers.md`, `test\README.md`, `ops\ROADMAP.md`, and
  `ops\AUTONOMOUS_RUN.md`.
- Traceability grep passed for `P1-META-001`, `metadata_schema_version`,
  `metadata_state`, `metadataSchemaVersion`, `tokenMetadataState`,
  `onchain-pending-schema-v1`, `onchain-final-schema-v1`,
  `codex/metadata-schema-state`, and `Queue Item 40`.
- Slither baseline comparison remains non-blocking and high/medium unchanged:
  `717` total findings, `4` High, `19` Medium, `92` Low, `591`
  Informational, `11` Optimization. The only metadata-schema-related row is an
  existing informational `too-many-digits` style finding.

Review requests:

- CodeRabbit was requested in issue comment `4675688299`.
- CodeRabbit review thread `PRRT_kwDOM7REis6IpsTo` requested the nonzero hash
  guard; CodeRabbit marked it addressed in commit `3dc56d6`.
- CodeRabbit comment `4675802795` confirmed the guard and regression are solid
  and suggested a clearer assertion label; the label nitpick was accepted.
- CodeRabbit comment `4675822063` verified final head `78664b0`, confirmed
  the assertion-label cleanup, and reported no concerns.
- Claude remains intentionally skipped per current user instruction; use
  CodeRabbit unless risk or future user instruction changes.

Merge:

- Squash merge commit: `be2bdbe5db792f2eac52770e7dddf49893d3d3c1`.
- Merged at `2026-06-11 00:00 UTC`.
- Issue `#46` remains open because freeze, burn, and future schema-migration
  state coverage remain in the P1 metadata track.

### PR #84: Add collection freeze manifests and guards (Queue Item 41)

Status: Merged.
Branch: `codex/metadata-freeze-manifest`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/84`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/47`
- This PR references issue `#47` but should not close it yet. Issue `#47`
  includes dependency content immutability acceptance criteria that remain
  intentionally split into `P1-META-003` / issue `#48`.

Goal:

- Implement the first P1-META-002 target-state slice after schema-v1 and
  ERC-4906 support.
- Store and expose a deterministic collection freeze manifest hash.
- Emit a stable `CollectionFrozen` event with collection ID, manifest hash,
  schema version, and admin.
- Require freeze eligibility to include ended mint window, final supply
  boundary, and terminal randomness for every live minted token.
- Finalize collection supply at freeze so post-freeze `setFinalSupply` cannot
  mutate collection metadata promises.
- Guard current `StreamCore` metadata-significant mutation paths after freeze,
  including collection metadata, metadata mode, token metadata inputs,
  randomizer changes, dependency-registry swaps, final-supply changes, and
  post-freeze token-hash writes for live tokens.
- Add focused freeze-boundary tests and update metadata docs, roadmap/test
  traceability, status docs, and this run state.

Out of scope:

- Immutable dependency version records and registry-level provenance remain
  `P1-META-003`.
- Burn metadata and post-burn callback semantics remain `P1-META-005`.
- JSON/HTML escaping, raw attribute validation, size limits, and render sandbox
  tests remain `P1-META-006`.
- Replacing magic collection update indexes remains a later metadata authority
  cleanup.

Candidate files:

- `smart-contracts/StreamCore.sol`
- `smart-contracts/IStreamCore.sol`
- `test/StreamMetadataFreeze.t.sol`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- Added `METADATA_FREEZE_MANIFEST_TYPEHASH` plus typed component hashes for
  collection state, supply state, integration state, collection script chunks,
  collection display fields, and live token metadata records.
- CodeRabbit follow-up replaced freeze-time live-token scans with tracked
  per-collection pending metadata counts and a live-token metadata accumulator
  maintained by mint, burn, token-hash, token-data, image, and attribute writes.
- CodeRabbit second follow-up now guards post-freeze burns and rejects pre-mint
  token-hash writes outside the target collection's reserved token range.
- Added `collectionFreezeManifestHash(collectionId)` and
  `previewCollectionFreezeManifestHash(collectionId)` views.
- `freezeCollection` now requires created collection data, ended mint window,
  elapsed final-supply delay, and nonzero final metadata hashes for every live
  minted token.
- `freezeCollection` finalizes collection supply to minted-ever count, tightens
  the reserved max token ID, stores the manifest hash, increments the frozen
  collection counter, and emits `CollectionFrozen`.
- Current `StreamCore` metadata-significant paths now fail after freeze:
  minting into the collection, randomizer changes, token-hash writes,
  artist signatures, final supply changes, and dependency registry swaps while
  any collection is frozen. Existing metadata setters already carried freeze
  guards and now have target-state coverage.
- Docs and roadmap explicitly keep immutable dependency version records,
  registry provenance, burn semantics, and escaping out of this PR.

Validation so far:

- Focused freeze tests passed:
  `forge test --match-contract StreamMetadataFreezeTest -vvv` with 7 tests,
  0 failed.
- Full canonical local gate passed: `make check` with the new freeze suite
  included.
- Windows wrapper passed:
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`.
- Touched-file formatting passed:
  `forge fmt --check smart-contracts\StreamCore.sol test\StreamMetadataFreeze.t.sol`.
- Diff whitespace check passed: `git diff --check`.
- Markdown heading scan passed for `docs\metadata.md`, `docs\status.md`,
  `docs\known-blockers.md`, `test\README.md`, `ops\ROADMAP.md`, and
  `ops\AUTONOMOUS_RUN.md`.
- Traceability grep passed for `P1-META-002`, `CollectionFrozen`,
  `collectionFreezeManifestHash`, `METADATA_FREEZE_MANIFEST_TYPEHASH`,
  `_LIVE_TOKEN_METADATA_AGGREGATE_TYPEHASH`, `StreamMetadataFreeze`,
  `codex/metadata-freeze-manifest`, `Queue Item 41`, PR `#84`, and
  `FrozenCollectionDependencyRegistry`.
- Slither baseline comparison remains non-blocking and high/medium unchanged:
  `718` total findings, `4` High, `19` Medium, `93` Low, `591`
  Informational, `11` Optimization. The first Slither run found one new
  test-only `unused-return` medium row in `StreamMetadataFreeze.t.sol`; the test
  now asserts the full tuple and the rerun returned to the `4/19` high/medium
  baseline.
- Second CodeRabbit follow-up validation passed after the burn/range guard patch:
  focused freeze tests now cover 7 cases, full `make check` passed, Windows
  wrapper passed, touched-file formatting passed, diff whitespace passed, and
  Slither remained `718` total findings with high/medium unchanged at `4/19`.

Merge:

- Squash merge commit: `72779ca8b4ce1977e8693c35acb46d724228cfa9`.
- Merged at `2026-06-11 01:03 UTC`.
- Issue `#47` remains open because dependency version records/provenance,
  burn metadata semantics, and escaping/sandbox hardening remain in the P1
  metadata track.

### PR #85: Add dependency version immutability (Queue Item 42)

Status: Merged.
Branch: `codex/dependency-version-immutability`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/85`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/48`

Goal:

- Implement the first P1-META-003 target-state slice after collection freeze
  manifests and guards.
- Add immutable dependency version records with content hashes, provenance,
  creation metadata, and deprecation state.
- Preserve compatibility for existing registry callers by keeping latest-version
  convenience views.
- Pin each collection to a dependency key, version, and content hash so later
  registry updates cannot silently alter existing collection output.
- Include dependency version in the collection freeze manifest hash and expose
  collection dependency pinning views/events.
- Add focused dependency registry, pinning, and frozen-output stability tests.
- Update metadata docs, blocker/status docs, roadmap/test traceability, and this
  durable run state.

Out of scope:

- P0-META-001 segment-boundary script composition remains already covered by
  typed chunk/content hash tests and should not be reopened unless the new
  dependency APIs regress those protections.
- Registry migration tooling for pre-existing deployed mainnet collections
  remains deployment/operations work.
- Dependency source packaging beyond provenance strings and content hashes
  remains future release-manifest work.

Candidate files:

- `smart-contracts/DependencyRegistry.sol`
- `smart-contracts/IDependencyRegistry.sol`
- `smart-contracts/StreamCore.sol`
- `smart-contracts/IStreamCore.sol`
- `test/StreamDependencyRegistry.t.sol`
- `test/StreamMetadataEncoding.t.sol`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- `DependencyRegistry.addDependency` now creates the next immutable dependency
  version instead of replacing the existing script for that key.
- Added `addDependencyWithProvenance`, `deprecateDependencyVersion`, full
  version-record views, narrow provenance/creator/creation/deprecation views,
  and versioned script/chunk/content-hash views.
- `addDependencyScriptIndex` now derives a new version from the latest version
  with one chunk replaced and leaves previous versions readable.
- Latest-version helper views remain for existing callers that do not yet pass a
  version explicitly.
- `StreamCore` now pins each collection to a dependency key, dependency version,
  dependency content hash, and registry address at creation and on full
  `updateCollectionInfo` repins.
- `retrieveDependencyScript` and `retrieveDependencyScriptContentHash` now use
  the collection pin, so later registry versions do not silently alter existing
  collection output.
- Collection freeze manifests now include the pinned dependency version and
  pinned dependency content hash.
- Added `DependencyVersionPinned` and `collectionDependencyVersionState` for
  release/indexer traceability.
- Updated the P0-META-001 segment-boundary characterization to assert pinned
  content stays stable after a newer registry version and only changes after an
  explicit collection repin.
- Updated metadata docs, known blockers, status, test README, and roadmap
  traceability for the implemented P1-META-003 slice.
- Slither initially reported the new test log helpers as three extra
  `uninitialized-local` findings; the helpers now initialize their `found`
  flags explicitly so the high/medium baseline is unchanged.
- Slither also mapped the provenance-only creation timestamp to the
  version-existence helper; that helper now carries a narrow `timestamp`
  suppression because the timestamp is not used for authorization, randomness,
  or ordering.
- CodeRabbit correctly identified that a nonzero dependency key with no
  registered version could otherwise pin version zero and the empty-script
  content hash. `StreamCore` now preserves `bytes32(0)` as the explicit
  no-dependency sentinel while rejecting nonzero unknown dependency keys with
  `UnknownDependency(key)`.
- The duplicated test helper for explicit dependency repinning moved into
  `StreamFixture`, and focused coverage now includes both explicit
  no-dependency pins and nonzero unknown-key rejection.
- CodeRabbit's latest-head follow-up identified a second-order zero-key drift:
  a real registry version under `bytes32(0)` could change the no-dependency
  sentinel. `DependencyRegistry` now reserves the zero key for sentinel use, and
  `StreamCore` skips the registry latest-version lookup when pinning
  `bytes32(0)`.
- CodeRabbit then identified that dependency pins also need to record the
  registry address, not only the version and content hash. `StreamCore` now
  stores the registry address in each collection pin, uses that pinned registry
  for dependency script retrieval and freeze manifests, emits it in
  `DependencyVersionPinned`, and proves a global registry swap cannot alter
  already-pinned collection output until an explicit repin.

Local validation:

- `forge build` passed after the contract/interface edits.
- Focused dependency version tests passed:
  `forge test --match-contract StreamDependencyRegistryTest -vvv` with 10 tests,
  0 failed.
- Adjacent metadata tests passed:
  `forge test --match-contract StreamMetadataEncodingTest -vvv` with 3 tests,
  0 failed.
- Adjacent freeze tests passed:
  `forge test --match-contract StreamMetadataFreezeTest -vvv` with 7 tests,
  0 failed.
- Full canonical gate passed: `make check`.
- Windows canonical gate passed:
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`.
- Touched-file formatting passed:
  `forge fmt --check smart-contracts\DependencyRegistry.sol
  smart-contracts\IDependencyRegistry.sol smart-contracts\StreamCore.sol
  smart-contracts\IStreamCore.sol test\StreamDependencyRegistry.t.sol
  test\StreamMetadataEncoding.t.sol`.
- Whitespace check passed: `git diff --check`.
- Markdown heading scan and traceability grep passed for roadmap/docs/test
  references.
- Slither comparison completed with accepted nonzero exit: `718` total
  findings; high/medium unchanged at `4/19`; selected critical detectors remain
  zero for `arbitrary-send-eth`, `reentrancy-eth`, `weak-prng`,
  `encode-packed-collision`, and `uninitialized-state`.
- CodeRabbit review-fix validation passed after the unknown-key guard and helper
  dedupe: focused dependency, metadata encoding, and freeze tests passed; full
  `make check`, Windows wrapper, touched-file formatting, and whitespace checks
  passed; Slither remained `718` total findings with high/medium unchanged at
  `4/19`.
- Second CodeRabbit sentinel-drift validation passed after adding the zero-key
  reservation and no-dependency latest-lookup bypass: focused dependency,
  metadata encoding, and freeze tests passed; full `make check`, Windows
  wrapper, touched-file formatting, whitespace, heading scan, traceability grep,
  and Slither comparison passed; Slither remained `718` total findings with
  high/medium unchanged at `4/19`.
- Third CodeRabbit registry-address validation passed after pinning the registry
  address: focused dependency tests passed with 10 tests including the
  registry-swap regression, adjacent metadata encoding/freeze suites passed,
  full `make check`, Windows wrapper, touched-file formatting, whitespace,
  heading scan, traceability grep, and Slither comparison passed; Slither
  remained `718` total findings with high/medium unchanged at `4/19`.
- Final CodeRabbit follow-up validation passed after centralizing dependency
  hash/rendering helpers in `test/helpers/TestHashingUtils.sol` and refreshing
  the autonomous run timestamp: focused dependency and adjacent metadata/freeze
  suites passed, full `make check`, Windows wrapper, formatting, whitespace,
  and duplicate-helper grep all passed.

Merge:

- Squash merge commit: `49f92048837dea0f15b1d0767b3710b690212d45`.
- Merged at `2026-06-11 03:00 UTC`.
- GitHub Actions CI run `27320421786` passed on final head
  `1ec5147f6a79d819cc2b3c373d670e3186d96713`.
- CodeRabbit review threads were resolved or outdated; the final aggregate
  `CodeRabbit` context remained pending with no target URL after explicit
  review/resume commands, so the merge used a documented stale-status
  maintainer decision.

### PR candidate: Add burn metadata semantics (Queue Item 43)

Status: Merged in PR #86.
Branch: `codex/burn-metadata-semantics`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/86`.
Initial implementation commit: `e0a71d3c423f87f8c0abd800f03f5e49deb180ad`.
Merge commit: `d637d372cf55b5b844697e2b4baabe265a9c8c9f`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/50`

Goal:

- Implement the P1-META-005 burn semantics slice accepted by ADR 0006.
- Keep ERC-721 semantics: burned tokens have no owner and `tokenURI` remains
  unavailable.
- Emit a protocol burn event with collection ID, token ID, operator, and owner
  for indexers.
- Retain concise burned-token audit state for collection ID, owner, operator,
  burn block/time, current token hash, and post-burn randomness recording.
- Let valid VRF/arRNG fulfillments for already-burned pending tokens record
  randomness for audit only, including after collection freeze, without
  resurrecting ownership, making `tokenURI` available, or emitting ERC-4906
  metadata update events.
- Update metadata docs, blocker/status docs, roadmap/test traceability, and this
  durable run state.

Out of scope:

- Serving burned-token metadata through `tokenURI`; ADR 0006 rejected that for
  this release track.
- Metadata escaping, raw-attribute validation, size limits, and render sandbox
  tests remain P1-META-006.
- General deployment manifests and event-topic artifact generation remain
  ADR 0007 / Gate E-G work.

Candidate files:

- `smart-contracts/StreamCore.sol`
- `smart-contracts/IStreamCore.sol`
- `smart-contracts/StreamRandomizerLifecycle.sol`
- `smart-contracts/RandomizerVRF.sol`
- `smart-contracts/RandomizerRNG.sol`
- `test/StreamCoreBurn.t.sol`
- `test/mocks/MockRandomizerCore.sol`
- `docs/metadata.md`
- `docs/status.md`
- `docs/known-blockers.md`
- `test/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation notes:

- `StreamCore.burn` now stores retained burn audit state and emits
  `TokenBurned(collectionId, tokenId, operator, owner)` in addition to the
  standard ERC-721 transfer-to-zero event.
- `StreamCore._mintProcessing` now rejects remint attempts for previously
  burned token IDs with `BurnedTokenRemintNotAllowed(tokenId)`.
- `StreamCore.isTokenBurned(tokenId)` and
  `StreamCore.burnedTokenAuditState(tokenId)` expose burned-token audit state
  without making `tokenURI` available.
- `setTokenHash` still rejects live and pre-mint token-hash writes after freeze,
  but allows hash recording for an already-burned token because that path updates
  audit state only and does not change the live-token freeze manifest.
- `StreamRandomizerLifecycle` now emits
  `BurnedTokenRandomnessRecorded(requestId, collectionId, tokenId, provider,
  randomizerEpoch, derivedSeed, rawOutputHash)` when an adapter successfully
  records randomness for a burned token.
- VRF and arRNG adapters emit the burn-audit event on both initial fulfillment
  and deterministic retry success when the core reports that the token is
  burned.
- `StreamCoreBurn.t.sol` covers burn event/audit state, unavailable `ownerOf`,
  `tokenURI`, and `tokenMetadataState`, retained token hash/collection mapping,
  remint rejection for previously burned token IDs, no ERC-4906 burn noise, VRF
  post-burn fulfillment after freeze with a stable freeze manifest, and arRNG
  post-burn fulfillment parity.

Local validation:

- Focused burn semantics tests passed:
  `forge test --match-contract StreamCoreBurnTest -vvv` with 4 tests, 0 failed.
- Adjacent metadata/randomizer suites passed:
  `forge test --match-contract "Stream(RandomizerLifecycle|RandomizerRetry|MetadataEvents|MetadataFreeze|MetadataGolden|CoreBurn)Test" -vvv`
  with 55 tests, 0 failed.
- `forge build` passed through `make check`.
- `make check` passed with the full Forge suite.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with the
  full Forge suite on Windows.
- Touched-file formatting passed:
  `forge fmt --check smart-contracts\StreamCore.sol smart-contracts\IStreamCore.sol smart-contracts\StreamRandomizerLifecycle.sol smart-contracts\RandomizerVRF.sol smart-contracts\RandomizerRNG.sol test\mocks\MockRandomizerCore.sol test\StreamCoreBurn.t.sol`.
- `git diff --check` passed.
- Heading and traceability scans passed across roadmap, durable state, metadata
  docs, status docs, ADRs, touched contracts, and burn tests.
- Slither comparison passed after cleanup:
  `718` total findings with high/medium unchanged at `4/19`.

Merge:

- PR #86 merged on 2026-06-11 after CI succeeded on head
  `37c361ac8251d973094cac0827787fe3dcfdb61d`, CodeRabbit reported no
  actionable comments on the follow-up review, and the remint thread was
  resolved by CodeRabbit.

### PR candidate: Add metadata escaping and render-safety baseline (Queue Item 44)

Status: Merged in PR #87.
Branch: `codex/metadata-escaping-safety`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/87`.
Initial implementation commit: `d9a4a1af3bf3f56bf5e913f2db4b9ba070b924df`.
CodeRabbit review request comment: `4677178780`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/51`

Goal:

- Implement the first P1-META-006 metadata safety slice accepted by ADR 0006.
- Escape JSON string fields emitted by on-chain metadata so quotes,
  backslashes, brackets, and control characters cannot break JSON structure.
- Add parser/golden tests for hostile collection and token metadata inputs.
- Document render safety and executable generated HTML risk.
- Update roadmap/test traceability and this durable run state.

Initial scope notes:

- Prioritize deterministic JSON escaping and generated metadata parser tests.
- Keep size-limit enforcement conservative until exact blast radius is inspected;
  if enforcement is too broad for one PR, document the accepted risk and leave a
  narrower issue-ready follow-up.
- Do not open a second PR until PR #86 is already merged and main is synced.

Implemented locally:

- Added `StreamCore._escapeJsonString` and applied it to on-chain metadata
  string fields: `name`, `description`, `image`, and `animation_url`.
- Added `StreamCore.UnsafeRawAttributes` and a structural raw-attribute guard
  in `updateImagesAndAttributes` that rejects literal control characters,
  unterminated strings, unbalanced delimiters, top-level literal/trailing-comma
  fragments, and unquoted array/object breakout attempts while preserving
  brackets inside quoted JSON strings.
- Added `test/StreamMetadataEscaping.t.sol` with a test-only base64 decoder so
  schema-v1 `tokenURI` JSON can be decoded, parsed through Foundry's JSON
  parser, and compared against expected escaped output.
- Updated metadata/status/blocker docs, ADR 0006, test README, and roadmap test
  traceability to mark the JSON/attribute-guard slice as partial and keep
  generated HTML/JavaScript escaping, URI policy, invalid UTF-8 policy, size
  limits, and render-sandbox tests as remaining P1-META-006 work.

Validation so far:

- `$env:Path="$HOME\.foundry\bin;$env:Path"; forge test --match-path test/StreamMetadataEscaping.t.sol -vvv`
  passed with 6 tests.
- `$env:Path="$HOME\.foundry\bin;$env:Path"; forge fmt smart-contracts\StreamCore.sol test\helpers\CharacterizationTestBase.sol test\StreamMetadataEscaping.t.sol`
  applied the required formatting.
- `$env:Path="$HOME\.foundry\bin;$env:Path"; forge test --match-path 'test/StreamMetadata*.t.sol' -vvv`
  passed with 31 metadata tests.
- `$env:Path="$HOME\.foundry\bin;$env:Path"; make check` passed with the full
  Foundry build/test gate.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed with the
  Windows contributor gate, including the 6-test metadata escaping suite.
- `$env:Path="$HOME\.foundry\bin;$PWD\.venv-tools\Scripts;$env:Path"; slither . --config-file slither.config.json --foundry-compile-all`
  produced the known non-zero baseline of 718 findings with high/medium counts
  unchanged at `4/19`.
- `forge fmt --check` on touched Solidity files, `git diff --check`, heading
  scans, and P1-META-006 traceability greps pass.
- CodeRabbit comment `4677192409` reported the implementation correct and
  well-scoped, with only non-blocking suggestions to add empty-attributes and
  multi-object positive-path tests. Those two tests now pass in the focused
  8-test `StreamMetadataEscapingTest` suite, full `make check`, Windows wrapper,
  touched-file formatting, whitespace, and Slither baseline comparison.
- CodeRabbit inline comment `3393290836` correctly flagged that the raw
  attribute parser tracked nesting depth but not container type. The local fix
  adds a compact container-kind bitset, rejects mismatched `{]` and `[}`
  delimiters, and refreshes the focused 9-test metadata escaping suite, full
  `make check`, Windows wrapper, touched-file formatting, whitespace, and
  Slither baseline comparison.

Merge:

- PR #87 merged on 2026-06-11 after CI succeeded on final head
  `1c50f7a0d4703c2712e714789f7d32d3543f490d`, CodeRabbit reported no
  actionable comments for the state-only follow-up, and the only visible review
  thread was resolved by CodeRabbit.

### PR #88: Add animation HTML wrapper safety (Queue Item 45)

Status: Merged.
Branch: `codex/metadata-animation-safety`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/88`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/51`

Goal:

- Continue the remaining P1-META-006 metadata safety work after PR #87.
- Harden the generated animation HTML wrapper so metadata inputs cannot break
  out of the intended `<script src>` or wrapper `<script>` elements.
- Escape dependency-script content when it is embedded into the generated
  JavaScript string.
- Prevent hostile `tokenData` from closing the generated JavaScript array and
  injecting arbitrary wrapper code before parsing.
- Add focused tests that decode the final `animation_url` HTML and assert the
  wrapper remains structurally intact for hostile inputs.
- Update metadata docs, ADR 0006, roadmap/test traceability, and this durable
  state file.

Initial scope notes:

- Collection scripts remain executable artist/operator code by design; this PR
  protects the protocol wrapper boundary rather than claiming sandboxed artist
  JavaScript.
- Size limits, URI allowlists, semantic attribute schema validation, invalid
  UTF-8 policy, and browser-level render-sandbox automation remain future
  P1-META-006 slices unless a small local change falls naturally out of this
  work.
- Issue #51 was reopened after PR #87 because #87 was only the first slice and
  intentionally left HTML/JavaScript, size, URI, and sandbox requirements open.

Implementation:

- Escaped the generated animation wrapper's `collectionLibrary` value before
  placing it in the quoted `<script src>` attribute, including the C0 control
  range and DEL after CodeRabbit noted the browser URL-parser edge case.
- Escaped `tokenData` and dependency script content before embedding them in
  generated single-quoted JavaScript strings.
- Changed generated `tokenData` construction from raw JavaScript array source
  to `tokenDataRaw` plus `JSON.parse("[" + tokenDataRaw + "]")`, so hostile
  token data cannot execute before parsing.
- Neutralized literal case-insensitive `</script` sequences in the generated
  wrapper script body so stored collection/dependency/token fields cannot
  create extra raw closing tags.
- Added decoded final `animation_url` HTML assertions for hostile library,
  tokenData, dependency, and collection-script inputs.
- Updated metadata docs, status/blocker docs, ADR 0006, test README, roadmap
  traceability, and the schema-v1 golden fixture.

Validation:

- `forge test --match-contract StreamMetadataEscapingTest -vvv` passed with 10
  tests.
- `forge test --match-path 'test/StreamMetadata*.t.sol' -vvv` passed with 35
  metadata tests.
- `make check` passed.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `forge fmt --check smart-contracts\StreamCore.sol
  test\StreamMetadataEscaping.t.sol test\StreamInitialization.t.sol
  test\helpers\TestHashingUtils.sol` passed.
- `git diff --check` passed.
- Slither baseline comparison remained unchanged at 718 total findings: High 4,
  Medium 19, Low 93, Informational 591, Optimization 11.
- `forge build --sizes` still fails because `StreamCore` is over EIP-170 at
  35,696 runtime bytes with a -11,120 byte runtime margin. This is an existing
  release/deployment blocker and is recorded for the roadmap, but the canonical
  local check for this slice remains green.

Merge:

- PR #88 merged on 2026-06-11 after CI passed on final head
  `e4302ff88fe5f90f74fde31ab91e7cdaf546758c`, the actionable CodeRabbit
  control-character note was fixed, no review threads remained open, and the
  stale aggregate CodeRabbit status context was documented as non-blocking.

### PR #90: Reduce `StreamCore` deployment size (Queue Item 46)

Status: Merged.
Branch: `codex/streamcore-size-reduction`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/90`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/89`

Goal:

- Turn the repeated `forge build --sizes` failure into a tracked deployment
  blocker instead of letting it hide behind metadata work.
- Reduce `StreamCore` runtime bytecode without changing the public metadata
  behavior that PRs #81-#88 just locked with golden and escaping tests.
- Prefer low-risk extraction of pure metadata rendering/escaping helpers into a
  linked library before considering larger architectural splits.
- Keep issue #51 open for the remaining metadata policy work; this queue item
  is about deployment viability and contract-size headroom.

Initial scope notes:

- Current `main` evidence after PR #88: `StreamCore` runtime bytecode is
  35,696 bytes, which is 11,120 bytes over the EIP-170 runtime limit.
- `forge build --sizes --via-ir` did not complete within the initial local
  timeout, so optimizer-mode changes are not treated as a proven fix.
- If this first extraction slice does not get below EIP-170 by itself, the PR
  should still document the exact reduction, remaining gap, and next split
  candidates.

Implementation:

- Moved pure on-chain metadata rendering, animation wrapper rendering, JSON
  escaping, HTML attribute escaping, JavaScript string escaping, closing-script
  neutralization, and raw-attribute structural validation into
  `StreamMetadataRenderer`.
- Removed optional `ERC721Enumerable` inheritance from `StreamCore`, preserved
  a live `totalSupply()` view with explicit mint/burn accounting, and added a
  regression that `supportsInterface(0x780e9d63)` is false while ERC-4906 stays
  true.
- Added a production-only size gate to `make check`, Windows/Linux check
  scripts, and CI: `forge build --sizes --via-ir --skip test --skip script --force`.
- Documented that the generic all-artifact `forge build --sizes` remains a
  diagnostic because test-only invariant handlers can exceed initcode limits;
  production deployability is measured by the skip-test IR gate.

Current local size evidence:

- `forge build --sizes --via-ir --skip test --skip script --force` passes.
- `StreamCore` runtime size: 23,139 bytes.
- `StreamCore` EIP-170 runtime headroom: 1,437 bytes.
- `StreamMetadataRenderer` runtime size: 6,843 bytes after the CodeRabbit escape
  fix.

Validation completed at `2026-06-11 06:13 UTC`:

- `make check` passed locally after adding the production size gate.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `$env:Path="$HOME\.foundry\bin;$env:Path"; forge fmt --check
  smart-contracts\StreamCore.sol smart-contracts\StreamMetadataRenderer.sol
  test\StreamMetadataEvents.t.sol` passed.
- `git diff --check` passed.
- `forge build --sizes --via-ir --skip test --skip script --force` passed and reports
  `StreamCore` at `23,139` runtime bytes with `1,437` bytes of runtime
  headroom; `StreamMetadataRenderer` reports `6,843` runtime bytes.
- Slither baseline comparison ran through `.venv-tools\Scripts\slither.exe`
  with Foundry on `PATH`; it returned the expected non-zero baseline exit with
  `717` total findings, High `4`, Medium `19`, Low `93`, Informational `590`,
  Optimization `11`, and target detector counts unchanged:
  `arbitrary-send-eth=0`, `reentrancy-eth=0`, `weak-prng=0`,
  `uninitialized-state=0`, `encode-packed-collision=0`.
- Stale helper grep found no references to the temporary helper-library
  experiments that were folded back into `StreamCore`.

CodeRabbit response completed locally at `2026-06-11 06:31 UTC`:

- Fixed CodeRabbit's renderer-library finding by escaping public
  `schemaVersion` and `metadataState` inputs before JSON assembly.
- Added `StreamMetadataEscapingTest.testRendererEscapesSchemaAndStateFields` to
  lock the library-level behavior.
- Fixed CodeRabbit's roadmap traceability finding by adding the `93 Low`
  Slither count to the static-analysis row and correcting the appendix impact
  table to `Low=93`, `Informational=590`.
- Validation after the review fixes:
  - `forge fmt --check smart-contracts\StreamMetadataRenderer.sol
    test\StreamMetadataEscaping.t.sol` passed.
  - `forge test --match-contract 'StreamMetadata(Escaping|Golden|Events)Test'
    -vvv` passed with 26 tests.
  - `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
  - `git diff --check` passed.
  - `forge build --sizes --via-ir --skip test --skip script --force` passed with
    `StreamCore` still at `23,139` runtime bytes and `1,437` bytes of runtime
    headroom; `StreamMetadataRenderer` is now `6,843` runtime bytes.
  - Slither baseline comparison remained unchanged:
    `slither_exit=-1`, `total=717`, `high=4`, `medium=19`, `low=93`,
    `informational=590`, `optimization=11`, `arbitrary-send-eth=0`,
    `reentrancy-eth=0`, `weak-prng=0`, `uninitialized-state=0`,
    `encode-packed-collision=0`.

Merge:

- PR #90 merged on `2026-06-11 06:37 UTC` as
  `36d993a946aad298b920c19fcbc26485b220b6e4` after CI passed on final
  head `a6db76f68c0fb7bb6ebeabafdff53583ee488b53`, CodeRabbit status was
  success, and both visible CodeRabbit review threads were resolved.

### PR candidate: Add deployment rehearsal baseline (Queue Item 47)

Status: Merged in PR #92.
Branch: `codex/deployment-rehearsal`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/92`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/91`

Goal:

- Start Gate E with an executable local deployment rehearsal instead of
  leaving deployment as documentation-only future work.
- Add a manifest schema/example that follows ADR 0007 and can become the
  release artifact shape for later testnet/fork/broadcast deployments.
- Keep production secrets out of the repo by using deterministic local
  placeholder addresses only.
- Add tests that prove the rehearsal deploys and wires the current stack,
  transfers Ownable control to the configured Safe placeholder, revokes the
  temporary deployer admin, and parses manifest JSON artifacts.

Initial scope:

- `script/RehearseDeployment.s.sol`
- `test/StreamDeploymentManifest.t.sol`
- `deployments/README.md`
- `deployments/schema/deployment-manifest.schema.json`
- `deployments/examples/anvil-6529stream-v0.1.0-001.json`
- `docs/deployment.md`
- `foundry.toml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `README.md`
- `docs/status.md`
- `docs/tooling.md`
- `script/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Open follow-up boundaries:

- Fork/testnet broadcast and verification are not implemented in this slice.
- Live production manifest generation from live broadcast outputs remains
  future Gate E work.
- Release checksum automation, dry-run signed fixed-price drops, dry-run
  auction settlement, and emergency redeployment rehearsal remain open.

Implementation:

- Added `script/RehearseDeployment.s.sol` with an explicit local deployer
  placeholder, Safe placeholder, pause guardian, emergency recipient, signer,
  payout, delegation, VRF coordinator, and arRNG controller config.
- The rehearsal deploys `StreamAdmins`, `DependencyRegistry`, `StreamCore`,
  `StreamCuratorsPool`, `StreamMinter`, `StreamDrops`, `StreamAuctions`,
  `NextGenRandomizerVRF`, and `NextGenRandomizerRNG`.
- The rehearsal wires core/minter/drops/auction references, registers signer
  lifecycle targets, creates a sample dependency and collection, assigns the
  VRF randomizer, sets mint phases, revokes the temporary deployer global admin,
  and transfers Ownable control for `StreamAdmins` and `StreamCore` to the Safe
  placeholder.
- Added deployment manifest schema/example files under `deployments/`; the
  local example now enumerates every contract deployed by the rehearsal stack
  and keeps ABI/bytecode checksums as explicit `TBD` placeholders until real
  broadcast artifacts exist.
- Added `docs/deployment.md`, refreshed `script/README.md`, and linked the
  rehearsal from README, tooling, status, roadmap, and the test matrix.
- Added `StreamDeploymentManifest.t.sol` to prove deployment wiring, ceremony
  state, temporary admin revocation, manifest JSON parsing, and randomizer
  contract status.
- Added the deployment rehearsal to `make check`, Linux/Windows check scripts,
  and CI. The production size gate now skips both `test` and `script` artifacts
  so non-production script bytecode does not pollute EIP-170/EIP-3860 evidence.

Validation completed at `2026-06-11 07:14 UTC`:

- `forge test --match-contract StreamDeploymentManifestTest -vvv` passed with
  2 tests.
- `forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir`
  passed.
- `make check` passed, including build, full test suite, production size gate,
  and deployment rehearsal.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `forge fmt --check script\RehearseDeployment.s.sol
  test\StreamDeploymentManifest.t.sol` passed.
- `git diff --check` passed.
- `forge build --sizes --via-ir --skip test --skip script --force` passed;
  `StreamCore` remains 23,139 runtime bytes with 1,437 bytes of EIP-170
  headroom, and `StreamMetadataRenderer` remains 6,843 runtime bytes.

Merge:

- PR #92 merged on `2026-06-11 07:38 UTC` as
  `eeefda163c2b727a9e3fba3922a220d184babf6c` after CI passed on final
  head `7b1381a78898a50c8d82dda6cafc8361381cc5f7`, CodeRabbit status was
  success, and the visible CodeRabbit review thread was resolved.

### PR candidate: Generate release artifact catalog (Queue Item 48)

Status: Merged.
Branch: `codex/release-artifact-catalog`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/94`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/93`

Goal:

- Start the Gate G machine-readable release artifact baseline without requiring
  live RPC credentials or deployment keys.
- Generate deterministic ABI checksum, bytecode checksum, interface ID, and
  event topic catalog JSON from Foundry build output.
- Wire drift detection into `make check`, Linux/Windows wrappers, and CI so ABI
  or event-surface changes cannot silently desynchronize release metadata.
- Feed generated ABI/bytecode hashes back into the local deployment manifest
  example and deployment docs.

Initial scope:

- `scripts/generate_release_artifacts.py`
- `scripts/test_release_artifacts.py`
- `release-artifacts/contracts.json`
- `release-artifacts/latest/*.json`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `README.md`
- `docs/tooling.md`
- `docs/deployment.md`
- `deployments/README.md`
- `deployments/examples/anvil-6529stream-v0.1.0-001.json`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Open follow-up boundaries:

- Live fork/testnet broadcast manifests and verified deployed bytecode remain
  Gate E follow-up work.
- ABI diffing against a previous release, signed tags, signed checksums, and
  source provenance attestations remain later Gate G release discipline.
- `StreamCore` linked-library bytecode hashes are explicitly marked as
  `unlinked_artifact_object` until a broadcast or verification artifact provides
  final linked deployed bytecode.

Implementation draft:

- Added a stdlib-only Python release artifact generator that reads Foundry
  artifacts and emits stable JSON under `release-artifacts/latest/`.
- The generator resolves `cast` from `PATH` or `~/.foundry/bin`, uses
  `cast sig-event` for Ethereum event topics, and uses Foundry
  `methodIdentifiers` for function selectors.
- Standard ERC interface IDs are configurable so ERC-721, ERC-2981, and
  ERC-4906 use advertised standard IDs while retaining the raw computed selector
  XOR for auditability.
- Added focused Python tests for ABI hashing, bytecode hashing, event topic
  generation, configured interface IDs, and drift detection.
- Added release artifact checks to `make check`, Linux/Windows wrappers, and CI.
- Updated deployment docs and the local example manifest to reference generated
  ABI and bytecode hashes plus the event topic catalog path.

Validation completed at `2026-06-11 08:12 UTC`:

- `python scripts\test_release_artifacts.py` passed.
- `python scripts\generate_release_artifacts.py --check` passed against the
  production `via-ir` build artifacts.
- `python -m py_compile scripts\generate_release_artifacts.py
  scripts\test_release_artifacts.py` passed.
- JSON parsing passed for the generated release artifacts and deployment
  example.
- `bash -n scripts/check.sh` passed.
- PowerShell parser validation for `scripts\check.ps1` passed.
- `make check` passed, including build, full Foundry tests, production size
  build, release-artifact drift check, and deployment rehearsal.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `git diff --check` passed.

Merge:

- PR #94 merged on `2026-06-11 08:24 UTC` as
  `d89ac51576af1922e2e7559f6c94c1f10a5de487` after GitHub Actions CI run
  `27333506619` passed on head
  `9d20bc9bb19fe8a158342ef181e7d1a66e4a8f8b`.
- CodeRabbit was requested twice and generated the PR summary, but its commit
  status remained pending with no review submissions or review threads after an
  extended wait. Per the autonomous operating rules, the PR was merged under a
  documented maintainer decision because CI was green, the PR was mergeable,
  and there were no actionable CodeRabbit findings to address.

### PR candidate: Generate and check deployment manifests (Queue Item 49)

Status: Merged in PR #96.
Branch: `codex/deployment-manifest-generator`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/96`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/95`

Goal:

- Replace the hand-maintained local Anvil deployment manifest example with a
  generated artifact built from committed manifest inputs.
- Fill contract ABI hashes and runtime bytecode hashes from the deterministic
  release artifact baseline.
- Add a deterministic manifest checksum without creating a self-referential
  checksum loop.
- Wire manifest drift detection into `make check`, Linux/Windows wrappers, and
  CI.
- Keep fork/testnet broadcast parsing, signed checksums, address books, and
  verified live bytecode replacement as follow-up Gate E/G work.

Initial scope:

- `scripts/generate_deployment_manifest.py`
- `scripts/test_deployment_manifest.py`
- `deployments/config/anvil-6529stream-v0.1.0-001.json`
- `deployments/examples/anvil-6529stream-v0.1.0-001.json`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `docs/tooling.md`
- `docs/deployment.md`
- `docs/status.md`
- `deployments/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation draft:

- Added a stdlib-only deployment manifest generator with `--check` drift mode.
- Added a committed Anvil manifest input config and regenerated the local
  example manifest with a deterministic `manifest_sha256`.
- Added focused Python tests for checksum behavior, hash injection, drift
  detection, and contract-set validation.
- Wired deployment manifest tests/checks into `make check`, Linux/Windows
  wrappers, and CI.
- Documented the checksum normalization rule: hash the canonical JSON manifest
  after setting `release_artifacts.manifest_sha256` to `sha256:` plus 64 zeroes.

Validation completed at `2026-06-11 08:47 UTC`:

- `python scripts\test_deployment_manifest.py` passed.
- `python scripts\generate_deployment_manifest.py --check` passed.
- `python scripts\test_release_artifacts.py` passed.
- `python scripts\generate_release_artifacts.py --check` passed.
- `python -m py_compile scripts\generate_release_artifacts.py
  scripts\test_release_artifacts.py scripts\generate_deployment_manifest.py
  scripts\test_deployment_manifest.py` passed.
- JSON parsing passed for the deployment manifest config, generated example, and
  schema.
- `bash -n scripts/check.sh` passed.
- PowerShell parser validation for `scripts\check.ps1` passed.
- `make check` passed, including build, full Foundry tests, production size
  build, release-artifact drift check, deployment-manifest drift check, and
  deployment rehearsal.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `git diff --check` passed.

Merge evidence:

- PR #96 merged on `2026-06-11 08:58 UTC` as
  `3d317f760de5cd2d009dd749a76551b28264c24e` after GitHub Actions CI run
  `27335241255` passed on head
  `578df3e6326fe145a16dde0109b75c0fd7581ca1`.
- CodeRabbit generated the PR release notes and left no review submissions or
  review threads, but its aggregate status remained pending. Per the autonomous
  operating rules, the PR was merged under a documented maintainer decision
  because CI was green, the PR was mergeable, and there were no actionable
  CodeRabbit findings to address.

### PR candidate: Add ABI compatibility checks (Queue Item 50)

Status: Merged in PR #98.
Branch: `codex/abi-compatibility-checks`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/98`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/97`

Goal:

- Commit an explicit production contract ABI surface baseline.
- Compare current Foundry ABI output against the baseline in local and CI gates.
- Fail on removed or changed functions, events, custom errors, constructors,
  fallback, or receive entries.
- Report additive ABI entries as compatible for the first release baseline.
- Document how maintainers refresh the baseline only when a release surface
  change is intentional.

Initial scope:

- `scripts/check_abi_compatibility.py`
- `scripts/test_abi_compatibility.py`
- `release-artifacts/baselines/v0.1.0/abi-surface.json`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `README.md`
- `docs/tooling.md`
- `docs/status.md`
- `release-artifacts/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation draft:

- Added a stdlib-only ABI compatibility checker with generation and `--check`
  modes.
- Generated the first committed production ABI surface baseline from the
  production `via-ir` Foundry artifacts.
- Added focused Python tests for identical, additive, removed, changed,
  removed-contract, and check-mode drift behavior.
- Wired ABI compatibility tests/checks into `make check`, Linux/Windows
  wrappers, and CI.
- Updated contributor/release docs and roadmap traceability.

Validation completed at `2026-06-11 09:15 UTC`:

- `python scripts\test_abi_compatibility.py` passed.
- `python scripts\check_abi_compatibility.py --check` passed.
- `python -m py_compile scripts\generate_release_artifacts.py
  scripts\test_release_artifacts.py scripts\check_abi_compatibility.py
  scripts\test_abi_compatibility.py scripts\generate_deployment_manifest.py
  scripts\test_deployment_manifest.py` passed.
- `bash -n scripts/check.sh` passed.
- PowerShell parser validation for `scripts\check.ps1` passed.
- JSON parsing passed for `release-artifacts/baselines/v0.1.0/abi-surface.json`
  plus the existing release artifact config and ABI checksum baseline.
- `make check` passed, including build, full Foundry tests, production size
  build, release-artifact drift check, ABI compatibility check, deployment
  manifest drift check, and deployment rehearsal.
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed.
- `git diff --check` passed; Git printed only the existing line-ending
  normalization warning for `scripts/check.ps1`.

Merge evidence:

- PR #98 merged on `2026-06-11 09:25 UTC` as
  `5646761344b5387f280aa928a158e4a6ac1e9711` after GitHub Actions CI run
  `27336811054` passed on head
  `a9abd0e8d2aba272b494a811f9368e19a2cda83b`.
- CodeRabbit was explicitly requested and acknowledged the review command, then
  injected release notes into the PR body. No review submissions or review
  threads appeared, and its aggregate status remained pending. Per the
  autonomous operating rules, the PR was merged under a documented maintainer
  decision because CI was green, the PR was mergeable, and there were no
  actionable CodeRabbit findings to address.

### PR candidate: Generate deployment address books (Queue Item 51)

Status: Merged.
Branch: `codex/address-book-generator`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/100`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/99`

Goal:

- Generate compact address-book JSON artifacts from committed deployment
  manifests.
- Include release/network metadata, source manifest path, manifest checksum,
  contract addresses, source paths, ABI hashes, runtime bytecode hashes, and
  verification status.
- Reject invalid addresses, duplicate deployed addresses, and missing required
  contract metadata.
- Wire address-book drift checks into `make check`, Linux/Windows wrappers, and
  CI.
- Document how address books differ from full deployment manifests.

Initial scope:

- `scripts/generate_address_books.py`
- `scripts/test_address_books.py`
- `deployments/address-books/anvil-6529stream-v0.1.0-001.json`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `README.md`
- `docs/tooling.md`
- `docs/status.md`
- `docs/deployment.md`
- `deployments/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation draft:

- Added a stdlib-only address-book generator that projects committed
  deployment manifests into compact integration artifacts.
- Added the generated local Anvil address book at
  `deployments/address-books/anvil-6529stream-v0.1.0-001.json`.
- Validated manifest schema, exact release contract set, nonzero 20-byte
  addresses, duplicate deployed addresses, ABI/runtime bytecode hashes,
  verification status, source manifest checksum, and strict `source_dirty`
  typing.
- Added focused tests for deterministic generation, drift detection, missing
  output directories, duplicate addresses, invalid addresses, invalid
  `source_dirty`, invalid chain IDs, invalid lifecycle state, invalid git
  commit hashes, invalid verification status, invalid hash format, missing
  contract metadata, missing release contracts, and unknown contracts.
- Added `deployments/schema/address-book.schema.json`, deterministic lowercase
  address normalization, `sha256:` hash-format validation, and verification
  status enum validation while addressing CodeRabbit review.
- Tightened address-book manifest validation to reject boolean integers,
  nonpositive chain IDs, invalid lifecycle states, and malformed git commit
  hashes.
- Wired address-book tests and `--check` drift detection into `make check`,
  `scripts/check.sh`, `scripts/check.ps1`, and GitHub Actions.
- Updated README, tooling, deployment, status, deployment artifact, roadmap,
  and run-state documentation to distinguish address books from full deployment
  manifests.

Local validation:

- `python scripts\test_address_books.py`
- `python scripts\generate_address_books.py --check`
- `python -m py_compile scripts\generate_release_artifacts.py scripts\test_release_artifacts.py scripts\check_abi_compatibility.py scripts\test_abi_compatibility.py scripts\generate_deployment_manifest.py scripts\test_deployment_manifest.py scripts\generate_address_books.py scripts\test_address_books.py`
- `bash -n scripts/check.sh`
- PowerShell parser validation for `scripts\check.ps1`
- Per-file JSON parsing for the generated address book, deployment manifest,
  address-book schema, and ABI checksums
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
- `git diff --check` reported only the known `scripts/check.ps1` line-ending
  warning.

Merge evidence:

- PR #100 merged on `2026-06-11 10:15 UTC` as
  `ad6deea8b6ba33e90703da1d7bd105f29eb7a24f` after GitHub Actions CI run
  `27339627582` passed on head
  `ef5f5e6e1c5841f2fd3a63281b2c1e065808812f`.
- CodeRabbit final re-check comment `4679472288` stated there were no
  remaining open findings and the implementation was ready to merge.
- The only CodeRabbit inline review thread was resolved. CodeRabbit's aggregate
  commit status remained stale/pending with no target URL, matching prior
  stale-status behavior, so merge decision comment `4679490149` documented the
  autonomous maintainer decision before merge.
- Claude was intentionally not requested per current user instruction.

### PR candidate: Add signable release checksum bundle (Queue Item 52)

Status: Merged.
Branch: `codex/release-checksum-bundle`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/102`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/101`

Goal:

- Generate a deterministic `SHA256SUMS`-style file over committed release and
  deployment artifacts.
- Generate a machine-readable checksum manifest with schema, generator,
  covered paths, output path, text-checksum hash, and per-file `sha256:`
  entries.
- Exclude generated checksum outputs from their own covered set to avoid
  self-referential hashes.
- Wire checksum-bundle tests and `--check` drift detection into `make check`,
  Linux/Windows wrappers, and CI.
- Document that the checksum bundle is signable release material; detached
  signatures and signed tags remain future release-ceremony work.

Initial scope:

- `scripts/generate_release_checksums.py`
- `scripts/test_release_checksums.py`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `README.md`
- `docs/tooling.md`
- `docs/status.md`
- `docs/deployment.md`
- `deployments/README.md`
- `release-artifacts/README.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation draft:

- Added a stdlib-only release-checksum generator with write and `--check`
  modes.
- Covers `release-artifacts/contracts.json`, `release-artifacts/latest/`,
  `release-artifacts/baselines/`, `deployments/config/`,
  `deployments/examples/`, `deployments/address-books/`, and
  `deployments/schema/`.
- Writes sorted `release-artifacts/latest/SHA256SUMS` entries and
  `release-artifacts/latest/release-checksums.json`.
- Verifies committed checksum entries against current files before comparing
  regenerated outputs so deleted covered files and hash drift are reported
  directly, and still reports those details if the regenerated covered set is
  empty.
- Added focused tests for generation, check-mode success, hash drift, deleted
  covered files, missing generated outputs, missing covered roots, output
  ordering, empty covered roots, and generated-output self-reference exclusion.
- CodeRabbit review fix expands `release-artifacts/README.md` to show the full
  release, deployment-manifest, address-book, and checksum refresh/check
  sequence so checksum regeneration does not run over stale deployment-derived
  artifacts.
- CodeRabbit review fix also rejects parent-directory segments in committed
  `SHA256SUMS` paths and adds focused parser coverage.

Local validation:

- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_release_artifacts.py`
- `python scripts\generate_release_artifacts.py --check`
- `python -m py_compile scripts\generate_release_artifacts.py scripts\test_release_artifacts.py scripts\check_abi_compatibility.py scripts\test_abi_compatibility.py scripts\generate_deployment_manifest.py scripts\test_deployment_manifest.py scripts\generate_address_books.py scripts\test_address_books.py scripts\generate_release_checksums.py scripts\test_release_checksums.py`
- `bash -n scripts/check.sh`
- PowerShell parser validation for `scripts\check.ps1`
- JSON parse and line-format validation for
  `release-artifacts\latest\release-checksums.json` and
  `release-artifacts\latest\SHA256SUMS`
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
- `rg` traceability check for `P1-RELEASE-004`, `generate_release_checksums`,
  `SHA256SUMS`, and release-signature boundary wording
- `git diff --check` reported only line-ending warnings for touched scripts.
- Final rerun after the empty-covered-set edge-case fix: `make check` and
  `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` both passed
  with the 7-case checksum suite.
- CodeRabbit review-fix rerun: `python scripts\test_release_checksums.py`
  passed with 8 tests, `python scripts\generate_release_checksums.py --check`
  passed, `python scripts\test_release_artifacts.py` passed, `make check`
  passed, `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passed,
  `python -m py_compile scripts\generate_release_checksums.py
  scripts\test_release_checksums.py` passed, and `git diff --check` reported
  only known line-ending warnings for touched Python files.

Merge evidence:

- Merged as PR #102 on `2026-06-11 11:09 UTC`.
- Merge commit: `de10363c8aae72755decb50a3ffabee224be4536`.
- Final head before merge: `a81b4feacde241e2093b21b1b4eeaf8fead9caa7`.
- CI run `27342290072` passed.
- CodeRabbit latest-head review finished with no actionable comments, aggregate
  status `success`, and no open review threads.
- Issue #101 auto-closed completed.

### PR candidate: Add release change approval policy and changelog gate (Queue Item 53)

Status: Merged.
Branch: `codex/release-change-policy`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/104`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/103`

Goal:

- Document release, ABI, metadata schema, deployment manifest, authorization,
  role/permission, and artifact change approval rules.
- Add a `CHANGELOG.md` with an `Unreleased` section and release-impact
  categories.
- Add a stdlib-only changelog gate that requires a non-placeholder
  `Unreleased` entry when release-impacting paths change.
- Wire the gate into `make check`, Linux/Windows wrappers, and CI.
- Update PR template, tooling/status docs, roadmap, and run-state traceability.

Initial scope:

- `CHANGELOG.md`
- `docs/release-policy.md`
- `scripts/check_changelog.py`
- `scripts/test_changelog_check.py`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `README.md`
- `docs/tooling.md`
- `docs/status.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation summary:

- Added `CHANGELOG.md` with an `Unreleased` section and initial local baseline
  entry.
- Added `docs/release-policy.md` covering version surfaces,
  release-impacting paths, breaking-change definition, ABI/artifact approval,
  changelog gate behavior, and release checklist.
- Added `scripts/check_changelog.py` plus focused stdlib tests in
  `scripts/test_changelog_check.py`.
- Wired changelog tests/checks into `make check`, Linux and Windows check
  wrappers, and CI.
- Updated the PR template, README, tooling docs, status docs, roadmap, and
  traceability matrix to make release-impact approval visible to contributors
  and maintainers.

Validation:

- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python -m py_compile scripts\check_changelog.py scripts\test_changelog_check.py`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts/check.ps1` and
  `scripts/bootstrap-windows.ps1`
- `rg -n "^#|^##|^###" ops\ROADMAP.md docs\release-policy.md CHANGELOG.md`
- `git diff --check`
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`
- Review-fix validation repeated source-verification tests/check, release
  manifest tests/check, release checksum tests/check, Python compile, `git diff
  --check`, `make check`, and the Windows wrapper.

Review response:

- Accepted CodeRabbit inline comment on placeholder bypasses: placeholder
  detection now rejects prefix variants such as `TODO: fill later`,
  `TBD - pending`, `n/a`, `_none_`, and placeholder-prefixed bullets.
- Accepted CodeRabbit PR-template wording nit: release notes checklist now
  names the required `## Unreleased` section and non-placeholder bullet.
- Review-fix validation passed with changelog tests/check, Python compile,
  shell/PowerShell syntax, and whitespace checks.

Merge evidence:

- Merged as PR #104 on `2026-06-11 11:52 UTC`.
- Merge commit: `012bea914262c0b56601fc5824f7175d7a8218f1`.
- Final head before merge: `172aaf2244162ff9b19cb580ec7f0b85f9102ac9`.
- CI run `27344538408` passed.
- CodeRabbit latest-head review finished with no actionable comments, aggregate
  status `success`, and the prior thread resolved/outdated.
- Issue #103 auto-closed completed.

### PR #106: Generate machine-readable release manifest (Queue Item 54)

Status: Merged.
Branch: `codex/release-manifest`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/106`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/105`

Goal:

- Generate `release-artifacts/latest/release-manifest.json` as the
  deterministic top-level release index for Gate G.
- Tie release artifact catalog outputs, ABI compatibility baseline, deployment
  configs/manifests, address books, deployment schemas, changelog, governance
  docs, and unavailable release-ceremony status together.
- Wire manifest tests and drift checks into `make check`, Linux/Windows
  wrappers, and CI before the release checksum gate.
- Keep the release checksum bundle authoritative for final file digests while
  documenting the release-manifest/checksum-bundle self-reference policy.

Initial scope:

- `scripts/generate_release_manifest.py`
- `scripts/test_release_manifest.py`
- `scripts/test_release_checksums.py`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `CHANGELOG.md`
- `README.md`
- `release-artifacts/README.md`
- `docs/tooling.md`
- `docs/deployment.md`
- `docs/release-policy.md`
- `docs/status.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation summary:

- Added a stdlib-only release manifest generator with deterministic output,
  required JSON schema-version checks, release/deployment metadata extraction,
  governance-doc hashing, and explicit unavailable release-ceremony statuses.
- Added focused generator tests covering deterministic writes, check-mode drift,
  missing required artifacts, required schema versions, and the checksum-bundle
  self-reference policy.
- Extended the release-checksum test baseline so
  `release-artifacts/latest/release-manifest.json` is included in the signable
  checksum bundle.
- Wired manifest tests/checks into local make targets, Linux and Windows check
  wrappers, and CI before release-checksum validation.
- Taught the release-artifact catalog drift check to ignore downstream Gate G
  outputs in the same directory, including `release-manifest.json`,
  `SHA256SUMS`, and `release-checksums.json`, with regression coverage.
- Updated docs, roadmap, and run-state traceability to make the manifest a
  first-class Gate G artifact while leaving detached signatures, signed tags,
  production address books, and verified live addresses as future work.

Validation:

- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_release_artifacts.py`
- `python scripts\generate_release_artifacts.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python -m py_compile scripts\generate_release_artifacts.py scripts\test_release_artifacts.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py scripts\test_release_checksums.py scripts\check_changelog.py scripts\test_changelog_check.py`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts/check.ps1` and
  `scripts/bootstrap-windows.ps1`
- `git diff --check`
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`

Review response:

- Accepted CodeRabbit nitpick on `scripts/test_release_manifest.py`: the test
  fixture JSON helper now uses `ensure_ascii=False` to match the generator's
  serialization policy.
- Review-fix validation passed with manifest tests/check, changelog check,
  Python compile, and whitespace check.

Merge evidence:

- Merged as PR #106 on `2026-06-11 12:38 UTC`.
- Merge commit: `30bbf4baabd689bf6243c5a8ec41051aff02060f`.
- Final head before merge: `7af47ba56d09498d46dbea3278740b5edc456084`.
- CI run `27347108379` passed.
- CodeRabbit latest-head status was `success`; no review threads were open.
- Claude was not requested per the current CodeRabbit-only user instruction.
- Issue #105 auto-closed completed.

### PR candidate: Generate source verification inputs (Queue Item 55)

Status: Merged.
Branch: `codex/source-verification-inputs`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/108`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/107`

Goal:

- Generate `release-artifacts/latest/source-verification-inputs.json` as a
  deterministic Gate G artifact for retained verification inputs.
- Tie production contract source hashes, Foundry artifact paths, ABI hashes,
  bytecode hashes, compiler settings, constructor ABI, linked-bytecode status,
  and verification command templates together for reviewers.
- Wire source-verification tests and drift checks into `make check`,
  Linux/Windows wrappers, and CI before the top-level release manifest gate.
- Keep live explorer verification, production broadcast manifests, detached
  signatures, and signed tags as separate release-ceremony work.

Initial scope:

- `scripts/generate_source_verification_inputs.py`
- `scripts/test_source_verification_inputs.py`
- `release-artifacts/latest/source-verification-inputs.json`
- `release-artifacts/latest/release-manifest.json`
- `release-artifacts/latest/SHA256SUMS`
- `release-artifacts/latest/release-checksums.json`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/check.sh`
- `scripts/check.ps1`
- `CHANGELOG.md`
- `README.md`
- `release-artifacts/README.md`
- `docs/deployment.md`
- `docs/release-policy.md`
- `docs/status.md`
- `docs/tooling.md`
- `ops/ROADMAP.md`
- `ops/AUTONOMOUS_RUN.md`

Implementation summary:

- Added `scripts/generate_source_verification_inputs.py`, a stdlib-only
  generator that builds `release-artifacts/latest/source-verification-inputs.json`
  from production contract config, Foundry artifacts, Solidity source files,
  compiler settings, and ABI/bytecode checksum outputs.
- The generated bundle records production contract source hashes, Solidity
  metadata source hashes, compiler versions, optimizer/via-IR settings,
  constructor ABI, bytecode/linking status, link references, and
  `forge verify-contract` command templates without claiming live explorer
  verification before broadcast artifacts exist.
- Added `scripts/test_source_verification_inputs.py` covering deterministic
  generation, check-mode drift, missing source and artifact failures,
  linked-bytecode reporting, constructor ABI retention, verification command
  templates, and ABI checksum mismatch failures.
- Taught the release-artifact catalog check to ignore this downstream Gate G
  output, and added release-manifest coverage so source-verification inputs are
  listed in `release-artifacts/latest/release-manifest.json`.
- Wired source-verification tests/checks into `make check`, `scripts/check.sh`,
  `scripts/check.ps1`, and CI before release manifest and checksum validation.
- Regenerated the source-verification artifact, release manifest, and release
  checksum bundle.
- Updated README, release-artifact docs, tooling docs, deployment docs, release
  policy, project status, changelog, roadmap, and run-state traceability.

Review response:

- Accepted CodeRabbit's library-placeholder finding: verification command
  templates now deduplicate linked libraries by `(source, library)` while
  retaining distinct creation/runtime link-reference details in the generated
  artifact.
- Added regression coverage for creation and runtime bytecode referencing the
  same library at different positions, proving the verification command keeps a
  single `--libraries` placeholder.
- Regenerated `release-artifacts/latest/source-verification-inputs.json`, the
  release manifest, and the checksum bundle after the generator fix.

Validation:

- `python scripts\test_source_verification_inputs.py`
- `python scripts\generate_source_verification_inputs.py --check`
- `python scripts\test_release_artifacts.py`
- `python scripts\generate_release_artifacts.py --check`
- `python scripts\test_release_manifest.py`
- `python scripts\generate_release_manifest.py --check`
- `python scripts\test_release_checksums.py`
- `python scripts\generate_release_checksums.py --check`
- `python scripts\test_changelog_check.py`
- `python scripts\check_changelog.py`
- `python -m py_compile scripts\generate_release_artifacts.py scripts\test_release_artifacts.py scripts\generate_source_verification_inputs.py scripts\test_source_verification_inputs.py scripts\generate_release_manifest.py scripts\test_release_manifest.py scripts\generate_release_checksums.py scripts\test_release_checksums.py scripts\check_changelog.py scripts\test_changelog_check.py`
- `bash -n scripts/check.sh`
- PowerShell parser check for `scripts/check.ps1` and
  `scripts/bootstrap-windows.ps1`
- `git diff --check`
- `make check`
- `powershell -ExecutionPolicy Bypass -File scripts\check.ps1`

Merge evidence:

- Merged as PR #108 on `2026-06-11 13:29 UTC`.
- Squash merge commit: `98696bf2953b93aeade4265a3c8a35201589b2ef`.
- Final head before merge: `fa43b1c9951d853ee076ded06c3f40277bbf4e8c`.
- CI run `27349988458` passed.
- CodeRabbit latest-head status was `success`; the only review thread was
  resolved/outdated by CodeRabbit after the duplicate library-placeholder fix.
- Claude was not requested per the current CodeRabbit-only user instruction.
- Issue #107 auto-closed completed.

### PR candidate: Add Foundry broadcast manifest ingestion (Queue Item 56)

Status: Merged as PR #110; CI and local `make check` passed on the review-fix
code head, CodeRabbit resolved the secret-key normalization thread, the
state-only head placeholder fix was accepted, and issue #109 closed completed.
Branch: `codex/broadcast-manifest-ingestion`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/110`.
Review-fix code head SHA: `29412bd342c8c3676265599b33e4eaab8caa2e9b`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/109`

Goal:

- Add deterministic, offline ingestion for sanitized Foundry
  `broadcast/.../run-latest.json` output.
- Validate broadcast chain ID, deployment transaction names, contract
  addresses, transaction hashes, receipt success, duplicate deployments,
  missing deployments, and unexpected deployments.
- Produce or validate committed manifest-input evidence that can feed the
  existing deployment manifest, address-book, release-manifest, and checksum
  pipeline without requiring live network access in CI.
- Keep live fork/testnet broadcasting, explorer submission, private keys, RPC
  URLs, detached signatures, and signed tags out of this PR.

Initial scope:

- `scripts/generate_broadcast_manifest_input.py`
- `scripts/test_broadcast_manifest_input.py`
- sanitized fixture/config output under `deployments/`
- deployment/release docs and roadmap/run-state traceability
- local/CI check wiring if the output is deterministic

Implementation so far:

- Added a strict offline generator for sanitized Foundry `run-latest.json`
  output.
- Added a committed sanitized Anvil broadcast fixture under
  `deployments/broadcasts/`.
- Generated a broadcast-derived deployment-manifest input, deployment manifest,
  and address book.
- Added the broadcast fixture and generated outputs to the release manifest and
  checksum bundle.
- Wired local, Windows, Makefile, and CI checks for the broadcast input plus the
  broadcast-derived deployment manifest.
- Updated deployment, tooling, status, release policy, changelog, roadmap, and
  durable run-state docs.

Validation status:

- Focused broadcast manifest-input tests/check pass locally.
- Deployment-manifest tests/check pass for the default and broadcast-derived
  configs.
- Address-book tests/check, release-manifest tests/check,
  release-checksum tests/check, changelog tests/check, Python compile,
  Bash syntax, PowerShell syntax, `git diff --check`, full `make check`, and
  Windows `scripts\check.ps1` pass locally.
- CI validation passed before merge.
- CodeRabbit-response validation passed:
  `python scripts\test_broadcast_manifest_input.py` and
  `python scripts\generate_broadcast_manifest_input.py --check`.

### PR #111: Add metadata size limits (Queue Item 57)

Status: Merged.
Branch: `codex/metadata-size-limits`.
Pull request: `https://github.com/6529-Collections/6529Stream/pull/111`.
Related issue:

- `https://github.com/6529-Collections/6529Stream/issues/51`

Goal:

- Continue P1-META-006 by enforcing numeric byte caps on metadata inputs and
  generated metadata output without bundling the remaining URI policy, semantic
  attribute schema, invalid UTF-8 policy, or browser render-sandbox work.
- Keep the PR deployable under the production via-IR EIP-170 size gate.
- Refresh ABI/bytecode release artifacts and docs because the contract ABI gains
  public limit constants and structured custom errors.

Initial scope:

- `smart-contracts/StreamCore.sol`
- `smart-contracts/DependencyRegistry.sol`
- `test/StreamMetadataSizeLimits.t.sol`
- metadata/status/blocker docs, roadmap/test/run-state traceability,
  changelog, and generated release/deployment artifacts

Implementation so far:

- Added `MetadataFieldTooLarge(field, actual, maximum)` and
  `DependencyFieldTooLarge(field, actual, maximum)` custom errors.
- Added public byte-limit constants for collection text fields, collection
  script chunks/counts, token data, token image, token raw attributes,
  generated `tokenURI`, dependency script chunks/counts, and dependency
  provenance.
- Enforced limits at collection creation/update, token mint/data/image/attribute
  mutation, generated `tokenURI`, and dependency version creation/update paths.
- Added boundary and oversized-input tests for Core metadata inputs, generated
  output, and dependency registry metadata.
- Regenerated release artifacts, deployment manifests, address books, source
  verification inputs, release manifest, and checksum bundle after the ABI and
  bytecode changes.

Validation status:

- `forge test --match-contract StreamMetadataSizeLimitsTest -vvv` passes.
- `forge test --match-contract StreamMetadataEscapingTest -vvv` passes.
- `forge test --match-contract StreamDependencyRegistryTest -vvv` passes.
- `forge build --sizes --via-ir --skip test --skip script --force` passes with
  `StreamCore` at 24,461 runtime bytes and 115 bytes of EIP-170 headroom.
- `make release-checksums` passes and regenerates deterministic artifacts.
- Full `make check` passes.
- Windows `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` passes.
- `git diff --check` passes.
- Touched-file formatting passes:
  `forge fmt --check smart-contracts\StreamCore.sol smart-contracts\DependencyRegistry.sol test\StreamMetadataSizeLimits.t.sol`.
- Full `forge fmt --check smart-contracts` still fails on existing legacy
  formatting outside this PR and remains tracked as a broader repo cleanup.
- GitHub CI run `27356813758` passed.
- CodeRabbit review finished with no actionable comments and success status.

Outcome:

- Merged as PR #111 on `2026-06-11 15:19 UTC`.
- Squash commit: `f844457a2f48fc31f34c187cef72f2083cfe6b70`.
- Issue #51 remains open for URI policy, invalid UTF-8 policy, semantic or
  structured attributes, and browser/render-sandbox checks.

## Decision Log

| Time UTC | Decision | Rationale |
| --- | --- | --- |
| 2026-06-13 14:20 | Address PR #240 CodeRabbit provenance review | PR candidate: Harden release evidence tracker label drift checks (Queue Item 114). Status: PR #240 open at `https://github.com/6529-Collections/6529Stream/pull/240`; branch `codex/release-evidence-label-drift`; branch started from PR #238 squash merge commit `3c738f51c8fa2cf623fda1f3d1fe5284db946d99`. Prior queue transition: Queue Item 113 merged in PR #238 as squash commit `3c738f51c8fa2cf623fda1f3d1fe5284db946d99`; PR #238 final implementation head was `d56f7d2405fd0c52fdf2320a0f167253aceb4bf7`. Completed local validation: label checker tests/check, body-sync tests/check, release-readiness tests/check, release-manifest tests/check, release-checksum tests/check, changelog gate, Bash syntax, PowerShell parser syntax, heading scan, whitespace check, and live GitHub label snapshot audit. PR #240 CI run `27469086354` passed on head `5a33b9fc08d0e58f8bb43b143e7d450739c148d4`; CodeRabbit requested roadmap provenance and decision-log traceability fixes. |
| 2026-06-13 08:44 | Open PR #208 and request CodeRabbit | State-only merge reconciliation PR opened against `main`, linked `Closes #206`, pushed head `097ac7506820359388bb76eba11778021d5edfe2`, and requested CodeRabbit review in comment `4698031592`; Claude intentionally skipped per current user instruction |
| 2026-06-13 08:41 | Finish Queue Item 106 local validation | Durable run state and roadmap metadata now record PR #205 final merge/CI/CodeRabbit evidence, issue #203 completion, issue #206 active reconciliation scope, issue #207 as the next no-secret packet-index target, heading scan, traceability grep, and whitespace checks |
| 2026-06-13 08:37 | Create issues #206 and #207, start Queue Item 106 | PR #205 merged cleanly, so issue #206 tracks state reconciliation while issue #207 becomes the next no-secret Gate G implementation slice for a release evidence packet index/checker |
| 2026-06-13 08:34 | Merge PR #205 | Production-release blocker report merged as `bc0384a7b77b582d954d861b2545ab2fc818d860`; final head `df5ef8342340e842725347aada48ca2ebf81a879` passed CI run `27461633469`, CodeRabbit status was success with the row-order thread resolved, and issue #203 closed completed |
| 2026-06-13 08:26 | Address CodeRabbit PR #205 review | Grouped production blocker rows by shared status order before requirement ID, added a mixed-status regression, regenerated report/manifest/checksum artifacts, and reran focused validation |
| 2026-06-13 08:14 | Open PR #205 and request CodeRabbit | Production-release blocker report PR opened against `main`, linked `Closes #203`, pushed head `dac4e220efa7e116269b6aea07c61fae52eef335`, and requested CodeRabbit review in comment `4697968574`; Claude intentionally skipped per current user instruction |
| 2026-06-13 08:11 | Finish Queue Item 105 local validation | Production-release blocker report, generator tests, manifest/checksum refresh, docs, roadmap, changelog, focused gates, heading scan, whitespace check, full `make check`, and the Windows PowerShell wrapper all pass locally without changing readiness claims |
| 2026-06-13 07:33 | Open PR #204 and request CodeRabbit | State-only production-template merge reconciliation PR opened against `main`, linked `Closes #202`, pushed head `d84d0ea119131dcaee899c25a6af6ab3b5f06297`, and requested CodeRabbit review in comment `4697878038`; Claude intentionally skipped per current user instruction |
| 2026-06-13 07:31 | Finish Queue Item 104 local validation | Focused release-readiness, public-beta evidence, non-local evidence, blocker-report, release-manifest, checksum, changelog, traceability, heading, and whitespace checks all pass for the docs-only reconciliation |
| 2026-06-13 07:30 | Create issues #202 and #203, start Queue Item 104 | PR #201 merged cleanly, so issue #202 tracks state reconciliation while issue #203 becomes the next no-secret Gate G implementation slice for a production-release blocker report |
| 2026-06-13 07:26 | Merge PR #201 | Production-release evidence templates merged as `02ce230500cb016e45b67c8dbd6710c08cadc000`; final head `a47870ddeee096e8f9d3212fe1579d56e3163c23` passed CI run `27460093022`, CodeRabbit status was success with no actionable comments, and issue #199 closed completed |
| 2026-06-13 07:14 | Open PR #201 and request CodeRabbit | Production-release evidence template PR opened against `main`, linked `Closes #199`, pushed head `f16075b6cb0c78cfa7c38d609019684e28559112`, and requested CodeRabbit review in comment `4697838014`; Claude intentionally skipped per current user instruction |
| 2026-06-13 07:11 | Finish Queue Item 103 local validation | Production-release evidence templates, checker/test coverage, manifest/checksum refresh, docs, roadmap, changelog, focused gates, heading scan, whitespace check, full `make check`, and the Windows PowerShell wrapper all pass locally without changing readiness claims |
| 2026-06-13 06:51 | Start Queue Item 103 | PR #200 merged cleanly, so issue #199 is now the active no-secret Gate G support slice for per-requirement production-release evidence templates without readiness claims |
| 2026-06-13 06:49 | Merge PR #200 | Public-beta template merge-state reconciliation merged as `728eb7161c80f6b3690de45caf11fd3c9e01e277`; final head `98b0a807a698a96748f312e0531a86991693a8c3` passed CI run `27459177572`, CodeRabbit status was success, and issue #198 closed completed |
| 2026-06-13 06:31 | Open PR #200 | Public-beta template merge-state reconciliation PR opened against `main`, linked `Closes #198`, and will use CodeRabbit-only review per current user instruction |
| 2026-06-13 06:26 | Create issue #198 and select Queue Item 102 | PR #197 merged cleanly, so the durable state needs to record its final CI/CodeRabbit/merge evidence before the next autonomous implementation slice |
| 2026-06-13 06:26 | Create issue #199 and queue production-release templates | With public-beta templates merged and all production-release evidence rows still missing, the next no-secret Gate G support slice is per-requirement production-release evidence templates |
| 2026-06-13 06:13 | Address CodeRabbit PR #197 review | Fixed the public-beta workflow order, recursive template discovery, and manifest metadata filtering for nested evidence JSON, added a fixture sidecar regression, regenerated release manifest/checksums, and reran focused validation |
| 2026-06-13 06:01 | Open PR #197 | Per-requirement public-beta evidence template PR opened against `main`, linked `Closes #195`, and will use CodeRabbit-only review per current user instruction |
| 2026-06-13 05:58 | Finish Queue Item 101 local validation | Focused template/checker/manifest/checksum checks, release-readiness, changelog, heading scan, whitespace check, full `make check`, and the Windows PowerShell wrapper all pass locally before PR creation |
| 2026-06-13 05:39 | Implement Queue Item 101 local draft | Added per-requirement public-beta evidence templates, checker/test coverage, nested non-local evidence manifest coverage, docs, changelog, regenerated release artifacts, and durable run-state updates without changing readiness claims |
| 2026-06-13 05:37 | Start Queue Item 101 | PR #196 merged cleanly, so issue #195 is now the active public-safe template slice for future non-local public-beta evidence collection |
| 2026-06-13 05:23 | Merge PR #196 | Public-beta blocker report state reconciliation merged as `99b0845e81c0b81bb9105c1d35970a92b47b22a0`; final head `7db6a5c24a15848926dd91c778303169fea5b274` passed CI run `27457583246`, CodeRabbit status was success with no actionable comments, and issue #194 closed completed |
| 2026-06-13 05:16 | Open PR #196 | State-only reconciliation PR opened against `main`, linked `Closes #194`, and will use CodeRabbit-only review per current user instruction |
| 2026-06-13 05:12 | Create issue #195 and select Queue Item 101 | After the blocker report merged, the next public-safe Gate G support slice is per-requirement public-beta evidence templates that guide later non-local evidence collection without secrets or readiness claims |
| 2026-06-13 05:09 | Create issue #194 and start Queue Item 100 | State reconciliation is needed to record PR #193 final CI, CodeRabbit, squash merge, and issue closure before starting the next implementation PR |
| 2026-06-13 05:07 | Merge PR #193 | Public-beta blocker report merged as `69df0c1af4e63080a9c4a822e167f0284d349c74`; final head `61ed7e8bc259c4daa4ac3adaeb746b96904dcbda` passed CI run `27457209173`, CodeRabbit status was success with no actionable comments after the metadata nitpick fix, and issue #191 closed completed |
| 2026-06-13 04:43 | Open PR #193 and request CodeRabbit | Public-beta blocker report PR opened against `main`, linked `Closes #191`, and CodeRabbit review requested in comment `4697524739`; Claude intentionally skipped per current user instruction |
| 2026-06-13 04:40 | Finish Queue Item 99 local validation | Focused public-beta blocker/report tests, release manifest/checksum checks, release-readiness, changelog, heading/syntax/whitespace checks, full `make check`, and the Windows PowerShell wrapper all pass locally |
| 2026-06-13 04:22 | Implement Queue Item 99 local draft | Added a deterministic no-secret public-beta blocker report generated from `public-beta-evidence.json`, wired local/CI drift checks, release manifest/checksum coverage, docs, changelog, roadmap, and run-state updates without changing readiness claims |
| 2026-06-13 04:02 | Merge PR #192 and start Queue Item 99 | State reconciliation merged as `b222e7ef1d0a4525b00a66a9fa90b957ccdac3bd`; issue #191 is now the active no-secret public-beta evidence blocker-report slice |
| 2026-06-13 03:58 | Open PR #192 | State-only reconciliation PR opened against `main`, linked `Closes #190`, and will use CodeRabbit-only review per current user instruction |
| 2026-06-13 03:53 | Create issues #190 and #191 | PR #189 merged cleanly, no open issues remained, so issue #190 tracks state reconciliation and issue #191 tracks the next no-secret public-beta evidence blocker-report slice |
| 2026-06-13 03:51 | Merge PR #189 | Signer custody readiness evidence merged as `ae87028d7471c35faa0bc3a3555583e24be50d4d`; final head `e0c64d91cfbcfabea7b7b89d8b1d61521c8487fa` passed CI run `27455567547`, CodeRabbit status was success, all visible review threads were resolved, and issue #187 closed completed |
| 2026-06-13 03:34 | Address CodeRabbit PR #189 review | Initial PR #189 CI run `27454880369` passed on head `0b49933d8f5c8474d23d7e4b8ce9a2c7f192c21e`; CodeRabbit requested stricter string/review timestamp validation, structured ERC-1271 rationale, fuller incident-response artifact links, public-beta wording, and unambiguous roadmap CI status |
| 2026-06-13 03:12 | Open PR #189 | Branch `codex/signer-custody-readiness-evidence` opened against `main`, linked `Closes #187`, and CodeRabbit review requested via comment `4697279178` |
| 2026-06-13 03:06 | Complete Queue Item 97 local validation | Signer custody readiness schema/template/checker/tests/docs are wired through local and CI gates, release manifest/checksum coverage, and readiness/audit/incident docs; focused evidence checks, `git diff --check`, `make check`, and `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` pass locally |
| 2026-06-13 02:45 | Start Queue Item 97 local draft | PR #188 merged cleanly as `3601a0b174f1f972d0b7daa284c19aab29a2373c`; issue #187 is the next no-secret Gate G/Gate C support slice for signer custody readiness schema/template/checker/docs without private keys or signer-service secrets |
| 2026-06-13 02:10 | Address CodeRabbit PR #188 rationale review | Reword the Queue Item 97 selection rationale to acknowledge that issue #186 was already open for reconciliation when signer custody/readiness evidence was chosen as the next implementation slice |
| 2026-06-13 02:06 | Open PR #188 | State-only reconciliation PR opened against `main`, linked `Closes #186`, and will use CodeRabbit-only review per current user instruction |
| 2026-06-13 02:02 | Create issue #187 and select Queue Item 97 | After #183 closed, issue #186 was open only for state reconciliation; signer custody/readiness evidence is the next no-secret blocker slice after payload generation and signing evidence |
| 2026-06-13 02:01 | Create issue #186 and start Queue Item 96 | PR #185 merged cleanly, so state must record final CI/CodeRabbit evidence and refresh the roadmap before the next implementation branch starts |
| 2026-06-13 02:00 | Merge PR #185 | Drop authorization signing evidence merged as `fd453a652d228c3e43002aca27f72e1d86cd53d9`; final head `fa1a6e949558dc7178564da179d576047ac428a9` passed CI run `27453065590`, CodeRabbit status was success, visible review threads were resolved, and issue #183 closed completed |
| 2026-06-13 01:44 | Address remaining CodeRabbit PR #185 findings | Replace stale roadmap status language, remove unsupported external-review phrasing, align numeric evidence validation with schema minimums, add focused regressions, and clarify tooling/incident-response docs before pushing the next review-response commit |
| 2026-06-13 01:37 | Address CodeRabbit PR #185 minor findings | Added the secret-regex maintainer note, evidence/template review-status regression, and `seed_phrase` fixture alignment; focused evidence and release-manifest checks pass |
| 2026-06-13 01:32 | Request CodeRabbit PR #185 review | CodeRabbit review requested in issue comment `4696975873`; Claude intentionally skipped per current user instruction |
| 2026-06-13 01:32 | Open PR #185 | Drop authorization signing evidence schema/checker PR opened against `main`, linked `Closes #183`, and included local validation transcript |
| 2026-06-13 01:29 | Finish local Queue Item 95 validation | Drop authorization signing evidence schema/template/checker/tests, release manifest/checksum coverage, docs checkers, changelog gate, `git diff --check`, full `make check`, and the Windows PowerShell wrapper pass locally; PR creation is next |
| 2026-06-13 01:07 | Start Queue Item 95 on issue #183 | PR #184 merged cleanly, issue #182 closed completed, and the next no-secret Gate G/Gate C support slice is the retained drop authorization signing evidence schema/checker |
| 2026-06-13 00:53 | Merge PR #184 | State-only reconciliation merged as `1a6b0691165c6f21b31a16c2ef4cd1d3456d34a9`; final head `964eabe1e5a959d699f10ebf7f13c446e9838d5d` passed CI run `27451124264`, CodeRabbit reported no actionable comments, and issue #182 closed completed |
| 2026-06-13 00:37 | Request CodeRabbit PR #184 review | CodeRabbit review requested in issue comment `4696769792`; Claude intentionally skipped per current user instruction |
| 2026-06-13 00:36 | Open PR #184 | State-only reconciliation PR opened against `main`, linked `Closes #182`, and prepared for CodeRabbit-only review per the current user instruction |
| 2026-06-13 00:34 | Create issue #183 and select Queue Item 95 | After PR #181 added no-secret unsigned payload generation, the next safe Gate G/Gate C support slice is a no-secret drop authorization signing evidence schema/checker for retained reviewed signing ceremonies without private keys, live chain access, or production-readiness claims |
| 2026-06-13 00:32 | Create issue #182 and select Queue Item 94 | PR #181 merged with CI run `27450665978` and CodeRabbit success on head `423988b440272f564f924df5b402a50eeaa10ef8`; the durable autonomous state needed a state-only reconciliation before starting the next implementation PR |
| 2026-06-13 00:29 | Merge PR #181 | Drop authorization payload generator tooling merged as `97800f4570740c7aefd88e407cb78e47ee5e80db`; final head `423988b440272f564f924df5b402a50eeaa10ef8` passed CI run `27450665978`, CodeRabbit status was success with no final actionable comments, and issue #180 closed completed |
| 2026-06-12 22:20 | Start Queue Item 92 on issue #177 | PR #178 merged cleanly, issue #176 closed completed, and the next highest-impact blocker is the no-secret drop authorization signing examples and fixtures target already captured in issue #177 |
| 2026-06-12 22:18 | Merge PR #178 | State-only incident-response reconciliation merged as `0122e670889df63f5359b7add2ac7f68b1ed9a31`; CodeRabbit completed with no actionable comments, Foundry smoke passed CI run `27445968474`, and issue #176 closed completed |
| 2026-06-12 22:10 | Open PR #178 and request CodeRabbit | State-only incident-response reconciliation PR opened against `main`, linked `Closes #176`, requested CodeRabbit in comment `4695830022`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 22:07 | Create issues #176 and #177 and select Queue Item 91 | After PR #175 merged and issue #173 closed completed, the durable state and roadmap verification metadata needed a state-only reconciliation before implementing the next no-secret drop-authorization signing examples and fixtures target |
| 2026-06-12 22:05 | Merge PR #175 | Protocol incident-response runbook merged as `4be2808e9e6f654143794d4db29f455eabff3a70`; final head `574804b6421c5658001839d483dd5a24dcbb2ad8` passed CI run `27445423380`, CodeRabbit status was success with the visible thread resolved, and issue #173 closed completed |
| 2026-06-12 21:41 | Open PR #175 and request CodeRabbit | Incident-response runbook PR opened against `main`, linked `Closes #173`, pushed head `0a0a49be0ab2adc3b1141389a52d1e8523865945`, requested CodeRabbit in comment `4695671204`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 21:38 | Prepare Queue Item 90 for PR | Incident-response runbook, docs checker, CI/wrapper wiring, release manifest/checksum refresh, docs links, roadmap/changelog updates, focused checks, `git diff --check`, and `make check` all pass locally |
| 2026-06-12 21:13 | Start Queue Item 90 | PR #174 merged, issue #172 closed completed, and issue #173 is the next active no-secret Gate E/G docs and operations slice |
| 2026-06-12 21:12 | Merge PR #174 | Non-local evidence schema merge reconciliation merged as `074ac3eb510ccafa593812677e6c26cbed4171b1`; final head `55b7dc716c5bfdd9e003d5b068f24ba7dfb5eddd` passed CI run `27442981046`, CodeRabbit status was success with no actionable comments, and issue #172 closed completed |
| 2026-06-12 21:03 | Open PR #174 and request CodeRabbit | State-only reconciliation PR opened against `main`, linked `Closes #172`, requested CodeRabbit in comment `4695446245`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 20:59 | Create issue #173 and select Queue Item 90 | After PR #171 merged and the state-only reconciliation issue #172 was opened, the next no-secret Gate E/G gap is a protocol incident-response runbook covering stuck auctions, failed randomness, bad Merkle roots, bad metadata/dependency configuration, signer compromise, and release artifact/evidence mistakes |
| 2026-06-12 20:57 | Create issue #172 and select Queue Item 89 | PR #171 merged with CI run `27442075849` and CodeRabbit success on head `7050e0ea474c507126c4d2e11744e8b61fd3ab52`; the durable run state and roadmap verification metadata needed a state-only reconciliation before the next implementation PR |
| 2026-06-12 20:56 | Merge PR #171 | Non-local release evidence metadata schema/checker merged as `6a5a2f96b8196c2387eda3ed3187cbde2616f9cb`; final head `7050e0ea474c507126c4d2e11744e8b61fd3ab52` passed CI run `27442075849`, CodeRabbit status was success with no actionable comments, and issue #170 closed completed |
| 2026-06-12 20:13 | Create issue #170 and select Queue Item 88 | PR #169 merged with CI run `27439897232` and CodeRabbit success on head `93917b20672e25b7edb9eb56dc22e11b9b3e7ecc`; no open issues remained, and the next no-secret Gate E/G gap is a machine-checkable metadata schema/checker for future non-local release evidence |
| 2026-06-12 20:10 | Merge PR #169 | Non-local release evidence intake runbook merged as `1d55df3bfb59ef30b833f751e60b3f77801ae860`; CI passed on run `27439897232`, CodeRabbit status was success, all visible review threads were resolved, and issue #168 closed completed |
| 2026-06-12 20:01 | Address PR #169 CodeRabbit review | Expanded the non-local evidence gate to production broadcast/address-book rows, added reviewed runbook metadata enforcement for complete public-beta evidence requirements, clarified checksum-backed signing wording, treated the runbook as a maintained manifest input, regenerated release artifacts, and reran focused gates plus `make check` |
| 2026-06-12 19:42 | Fix PR #169 CI hygiene failure | GitHub Actions run `27438712570` failed repository hygiene on an extra blank line at EOF in `docs/non-local-release-evidence.md`; trimmed the EOF, regenerated release manifest/checksum artifacts, and reran focused whitespace/readiness/manifest/checksum/changelog validation |
| 2026-06-12 19:39 | Open PR #169 and request CodeRabbit | Non-local release evidence intake PR opened against `main`, linked `Closes #168`, requested CodeRabbit in comment `4694642716`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 19:36 | Run full local gate for Queue Item 87 | `make check` passed after the focused checks; only existing Foundry warning noise appeared, and no unexpected tracked artifacts changed |
| 2026-06-12 19:29 | Finish local Queue Item 87 validation | Non-local evidence runbook docs/checker updates, release-manifest governance-doc coverage, regenerated manifest/checksum artifacts, public-beta evidence, changelog, Python compile, heading scan, and whitespace checks all pass locally |
| 2026-06-12 19:20 | Implement Queue Item 87 local draft | Added the non-local release evidence runbook, wired it into release-readiness, public-beta evidence, release policy, tooling, release-manifest governance docs, roadmap, changelog, and autonomous run state before regenerating release evidence |
| 2026-06-12 19:18 | Create issue #168 and select Queue Item 87 | PR #167 merged, issue #166 closed completed, and Gate E/G still needed an operator-facing no-secret intake runbook for future fork/testnet/live, audit, explorer, gas, invariant, signature, and signed-tag evidence |
| 2026-06-12 19:16 | Merge PR #167 | Gate G roadmap reconciliation merged as `e11dc44ee5eb33f95fede07d6a4045d44d4faa87`; final head `820eb1ac09cbfe1bb2347a60986f50e8ef8455c0` passed CI run `27437060820`, CodeRabbit status was `success`, and issue #166 closed completed |
| 2026-06-12 19:06 | Address CodeRabbit PR #167 review | Moved completed issues #162 and #164 from Gate G `Blocking issues` into `Evidence`, leaving only live Gate G blockers in the blocker paragraph; focused heading, whitespace, release-readiness, public-beta evidence, release-manifest, and release-checksum checks pass locally |
| 2026-06-12 19:02 | Mark PR #167 merge-ready | GitHub Actions CI run `27436411351` passed on head `d2a83ce73d3889a67f0405fa8a79a7d2d7f8ce41`, CodeRabbit status was `success`, and CodeRabbit comment `4694328674` found no blocking issues |
| 2026-06-12 18:54 | Open PR #167 | Gate G roadmap reconciliation PR opened against `main`; CodeRabbit will be requested after the PR-number state update is pushed, and Claude remains intentionally skipped per current user instruction |
| 2026-06-12 18:52 | Finish local Queue Item 86 validation | Roadmap/run-state reconciliation is limited to `ops/ROADMAP.md` and `ops/AUTONOMOUS_RUN.md`; heading scan, whitespace check, release-readiness check, public-beta evidence check, release-manifest check, and release-checksum check pass locally |
| 2026-06-12 18:50 | Create issue #166 and select Queue Item 86 | PR #165 merged, issue #164 closed completed, no open 6529Stream issues remained, and the roadmap/run-state needed a state-only reconciliation so Gate G no longer treats the public-beta evidence manifest as pending |
| 2026-06-12 18:47 | Merge PR #165 | Public-beta evidence status manifest merged as `5e9a6c9f5afb569151b74b2095ef180cbbcfe884`; final head `54af773ccbf8c73c6d880a7713932039249053a5` passed CI run `27435644265`, CodeRabbit status was `success`, and issue #164 closed completed |
| 2026-06-12 18:38 | Mark PR #165 merge-ready | GitHub Actions CI run `27435205011` passed on head `7aba4c7cd61d8a8dbe2611b324d4c2a073327faa`, CodeRabbit status was `success`, and all visible CodeRabbit review threads were resolved |
| 2026-06-12 18:28 | Address second CodeRabbit PR #165 review | Fixed the valid custom `--release-artifacts-dir` path bug, made ISO risk-acceptance dates parse as real dates, documented the date format, added schema minItems drift coverage, added custom release-artifact directory manifest coverage, updated checksum/governance-doc coverage docs, regenerated release evidence, and passed focused validation |
| 2026-06-12 18:13 | Address CodeRabbit PR #165 review | Accepted the pre-merge docstring recommendation plus the low-risk ISO date, schema-count note, and secret-key false-positive hardening suggestions; focused public-beta, release-manifest, release-artifact, readiness, audit-package, checksum, and py_compile validation pass locally |
| 2026-06-12 18:10 | Open PR #165 and request CodeRabbit | Public-beta evidence status PR opened against `main`, linked `Closes #164`, requested CodeRabbit in comment `4693993623`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 18:05 | Finish local Queue Item 85 validation | Public-beta evidence checker/tests, release-artifact downstream handling, release-manifest/checksum drift checks, py_compile, wrapper syntax, heading scan, `git diff --check`, full `make check`, and Windows `scripts\check.ps1` all pass locally with only existing Foundry and line-ending warning noise |
| 2026-06-12 17:47 | Fix Queue Item 85 artifact-generator integration | Full `make check` exposed that `release-artifacts/latest/public-beta-evidence.json` was correctly tracked by release manifest/checksum tooling but still looked unexpected to the lower-level ABI/event/interface artifact generator, so it is now classified as a downstream release file and covered by the generator test |
| 2026-06-12 17:25 | Create issue #164 and select Queue Item 85 | PR #163 merged, no open 6529Stream issues remained, and the next Gate G gap is a no-secret public-beta evidence status manifest so fork/testnet/live, audit, signature, signed tag, address, broadcast, explorer, and post-audit blockers become machine-checkable |
| 2026-06-12 17:22 | Merge PR #163 | Release-readiness dashboard merged as `cb01f4668cfad068d6df6e556da3baf03fc23575`; final CI run `27431237322` passed, CodeRabbit status was success with no unresolved review threads, and issue #162 closed completed |
| 2026-06-12 17:13 | Address CodeRabbit PR #163 docstring warning | Added concise docstrings to the new checker/test functions after CodeRabbit's pre-merge summary flagged docstring coverage; focused release-readiness, py_compile, changelog, and whitespace validation pass locally |
| 2026-06-12 17:04 | Address CodeRabbit PR #163 review | Accepted the two low-risk coverage suggestions by adding missing-document and custom `--release-readiness` path tests; focused release-readiness, py_compile, changelog, and whitespace validation pass locally |
| 2026-06-12 16:59 | Open PR #163 and request CodeRabbit | Release-readiness dashboard PR opened against `main`, linked `Closes #162`, requested CodeRabbit in comment `4693404700`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 16:56 | Finish local Queue Item 84 validation | Release-readiness checker/tests, audit-package checks, release manifest/checksum regeneration and check modes, Python compilation, changelog gate, Unix and PowerShell syntax checks, heading scan, `git diff --check`, full `make check`, and Windows `scripts\check.ps1` all pass locally with only existing Foundry and line-ending warning noise |
| 2026-06-12 16:34 | Implement Queue Item 84 local draft | Added the release-readiness dashboard, checker/tests, local/CI gate wiring, release-manifest coverage, docs, roadmap, changelog, and run-state updates for issue #162 without Solidity behavior changes |
| 2026-06-12 16:23 | Create issue #162 and select Queue Item 84 | PR #161 merged, no open issues remained, and Gate G still needed a checked release-readiness dashboard that distinguishes local baseline evidence from public-beta and production-release blockers |
| 2026-06-12 16:22 | Merge PR #161 | Architecture/threat-model docs merged as `0bddc2c93157e328c40b88b9c98e0fa7195b5acd`; final CI run `27428125013` passed, CodeRabbit status was success, issue #160 closed completed, and local `main` was fast-forwarded |
| 2026-06-12 16:05 | Address remaining CodeRabbit PR #161 roadmap thread | Updated the roadmap verification metadata CI row to refer to PR #161; the separate committed-doc path thread was already fixed in `b5d531d` |
| 2026-06-12 16:01 | Address CodeRabbit PR #161 review | Accepted the low-risk review suggestions: add ADR evidence for `StreamMinter`, clarify `arRNG`, anchor deployment ceremony wording, precompute per-document links, anchor committed-doc tests to the script path, add reciprocal-link rejection tests, regenerate release evidence, and pass focused architecture/audit/manifest/checksum/changelog/syntax/whitespace validation |
| 2026-06-12 15:54 | Open PR #161 and request CodeRabbit | Architecture/threat-model PR opened against `main`, linked `Closes #160`, requested CodeRabbit in comment `4692872990`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 15:52 | Finish local Queue Item 83 validation | Architecture/threat-model checker/tests, updated audit package checks, release manifest/checksum/changelog gates, Python compilation, Unix and PowerShell syntax checks, heading scan, `git diff --check`, full `make check`, and Windows `scripts\check.ps1` all pass locally with only existing Foundry and line-ending warning noise |
| 2026-06-12 15:36 | Start Queue Item 83 | Created issue #160 and selected the Gate F architecture/threat-model gap because the audit package index exists but still needs checked system and trust-boundary docs for external auditors |
| 2026-06-12 15:22 | Merge PR #159 | External audit package index merged as `e2e9fcfdf0ef73e058244d4262f4d50137eefd3a`; CI run `27424703232` passed, CodeRabbit final status was success, and issue #158 closed completed |
| 2026-06-12 15:05 | Address PR #159 CodeRabbit review | Accepted the minor review suggestions: aggregate missing-link failures, guard the missing-link test mutation, clarify generate-vs-check docs, use `ValueError` for validation errors, regenerate release evidence, and pass focused audit/manifest/checksum/changelog/syntax/whitespace validation |
| 2026-06-12 14:59 | Open PR #159 and request CodeRabbit | Audit package index PR opened against `main`, linked `Closes #158`, requested CodeRabbit in comment `4692444134`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 14:58 | Finish local Queue Item 82 validation | Audit package checker/tests, release manifest/checksum/changelog gates, Python compilation, Unix and PowerShell syntax checks, heading scan, `git diff --check`, full `make check`, and Windows `scripts\check.ps1` all pass locally with only existing Foundry and line-ending warning noise |
| 2026-06-12 14:36 | Start Queue Item 82 | Created issue #158 and selected the Gate F external audit package index because no open issues remained and Gate F still lacked a single auditor-facing package tying scope, ADRs, invariants, Slither, deployment/release evidence, blockers, and security reporting together |
| 2026-06-12 14:33 | Merge PR #157 | Release signature evidence baseline merged as `ed5f3b17cec879d74f765cbd457a9b0fbe809cad`; CI run `27421639645` passed, CodeRabbit status was green, issue #156 closed completed, and local `main` was fast-forwarded |
| 2026-06-12 14:18 | Address PR #157 CodeRabbit findings | Enforced exact evidence object keys, validated release-signature evidence before manifest indexing, retained the validated payload in the release manifest, added schema/signature evidence to checksum coverage, regenerated release artifacts, and passed focused release-signature, manifest, and checksum tests locally |
| 2026-06-12 14:10 | Address PR #157 CI hygiene failure | GitHub CI run `27420702347` failed `git diff --check` on an extra blank line at EOF in `docs/release-signatures.md`; trimmed the EOF, regenerated release manifest/checksum evidence, and reran focused release-signature, manifest, checksum, Python compile, Bash syntax, and whitespace checks locally |
| 2026-06-12 14:03 | Open PR #157 and request CodeRabbit | Release signature evidence baseline PR opened against `main`, linked `Closes #156`, requested CodeRabbit in comment `4691996355`, and intentionally skipped Claude per current user instruction |
| 2026-06-12 13:18 | Request CodeRabbit PR #155 review | CodeRabbit review requested in issue comment `4691619335`; Claude intentionally skipped per current user instruction |
| 2026-06-12 13:17 | Open PR #155 | Randomizer operations evidence PR opened against `main`, linked `Closes #154`, and includes local validation transcript; CodeRabbit review will be requested after this concrete PR state is pushed |
| 2026-06-12 13:13 | Finish local Queue Item 80 validation | Focused randomizer-operations tests/checker, release manifest/checksum/changelog drift checks, Python compilation, Unix check-wrapper syntax, `git diff --check`, full `make check`, and Windows `scripts\check.ps1` all pass locally with only existing Foundry warning noise |
| 2026-06-12 12:54 | Implement Queue Item 80 local draft | Added randomizer operations schema, local Anvil evidence, validator/tests, gate wiring, release manifest/checksum coverage, and docs/run-state updates for issue #154 without Solidity behavior changes or live provider secrets |
| 2026-06-12 12:42 | Create issue #154 and select Queue Item 80 | PR #153 merged as `551185c6399d79c74321d2e4fb128cbb29c4a8e7`; no open GitHub issues remained, and the next no-secret Gate E/Gate G gap is checkable randomizer provider/funding/lifecycle evidence for future fork/testnet/live ceremonies |
| 2026-06-12 12:40 | Merge PR #153 | Request-level randomizer reserve lifecycle tests merged as `551185c6399d79c74321d2e4fb128cbb29c4a8e7`; final head `9f35d7667e69d25cb8025cc1d2e879fcc270db28` had CI run `27415896020` and CodeRabbit green with no unresolved review threads, and issue #152 closed completed |
| 2026-06-12 12:32 | Open PR #153 and request CodeRabbit | Pushed `codex/randomizer-reserve-lifecycle-tests`, opened https://github.com/6529-Collections/6529Stream/pull/153 against `main`, linked `Closes #152`, requested CodeRabbit in comment `4691282971`, and intentionally skipped Claude per user instruction |
| 2026-06-12 12:29 | Finish local Queue Item 79 validation | Focused randomizer-payment, emergency-withdrawal, payment-invariant, randomizer-lifecycle, and randomizer-retry Forge tests pass; release manifest/checksum/changelog drift checks pass; full `make check`, Windows `scripts\check.ps1`, and `git diff --check` pass locally with only existing warning noise |
| 2026-06-12 12:11 | Implement Queue Item 79 local draft | Added focused `StreamRandomizerPayments.t.sol` coverage for request-cost spending, multiple pending arRNG requests, fulfilled/stale/failed/retried request states, forced ETH, and unauthorized emergency-withdrawal reserve preservation; focused formatting and Forge tests pass locally |
| 2026-06-12 12:05 | Create issue #152 and select Queue Item 79 | PR #151 merged as `e7de312e9a74cee5bd9d47edb7bd974421bee17b` and no open GitHub issues remained, so the next no-secret Gate D gap is the roadmap's previously deferred request-level randomizer reserve lifecycle accounting |
| 2026-06-12 12:02 | Merge PR #151 | Auction consistency invariant baseline merged as `e7de312e9a74cee5bd9d47edb7bd974421bee17b`; final head `2c161ebb709423080519453b3259c35b0f847489` had CI run `27413957701` and CodeRabbit green after the assertion-helper nitpick, with no unresolved review threads, and issue #150 closed completed |
| 2026-06-12 11:52 | Address CodeRabbit PR #151 nitpick | Accepted CodeRabbit's balance-coverage assertion consistency nitpick by adding a reusable `Assertions.assertGte` helper and using it in the auction invariant; focused formatting/test and whitespace checks pass locally |
| 2026-06-12 11:40 | Open PR #151 and request CodeRabbit | Auction consistency invariant baseline pushed to `codex/auction-consistency-invariants`, opened as https://github.com/6529-Collections/6529Stream/pull/151 against `main`, linked `Closes #150`, requested CodeRabbit in comment `4690918785`, and intentionally skipped Claude per user instruction |
| 2026-06-12 11:16 | Create issue #150 and select Queue Item 78 | PR #149 merged as `3ca6e53eb3b8299a80fbf5d7765e0dd7f0d0d610` and no open GitHub issues remained, so the next local Gate D gap is broader auction-consistency invariant coverage before fork/testnet/live evidence |
| 2026-06-12 11:15 | Merge PR #149 | Supply/replay/freeze invariant baseline merged as `3ca6e53eb3b8299a80fbf5d7765e0dd7f0d0d610`; final head `ed6bd87f50877fdf711f14fbc215aa958bd59f16` had CI run `27411884632` and CodeRabbit green, no review threads, and issue #148 closed completed |
| 2026-06-12 11:06 | Validate CodeRabbit PR #149 response | Focused invariant formatting/test, release manifest/checksum drift checks, and whitespace checks pass after the drop-tracking overflow guard |
| 2026-06-12 11:05 | Address CodeRabbit PR #149 nitpick | Accepted CodeRabbit review `4485046635` by making drop tracking capacity fail loudly instead of silently weakening future invariant coverage |
| 2026-06-12 10:56 | Open PR #149 and request CodeRabbit | Pushed `codex/supply-replay-freeze-invariants`, opened https://github.com/6529-Collections/6529Stream/pull/149 against `main`, linked `Closes #148`, requested CodeRabbit in comment `4690503803`, and intentionally skipped Claude per user instruction |
| 2026-06-12 10:54 | Finish local Queue Item 77 validation | Focused supply/replay/freeze invariant fuzzing, release manifest/checksum/changelog drift checks, full `make check`, Windows `scripts\check.ps1`, and `git diff --check` pass locally with only existing repo warnings |
| 2026-06-12 10:36 | Implement Queue Item 77 local draft | Added a bounded supply/replay/freeze invariant test file covering mixed fixed-price mints, cancellations, replay attempts, burns, metadata edits, freeze attempts, and post-freeze guards; focused formatting and Forge test validation passed before docs/release evidence updates |
| 2026-06-12 10:28 | Create issue #148 and select Queue Item 77 | PR #147 merged and no open GitHub issues remained, so the next Gate D gap is a local supply/replay/freeze invariant baseline before broader fork/testnet/live and auction-consistency evidence |
| 2026-06-12 10:27 | Merge PR #147 | Local gas snapshot baseline merged as `a907219a2717322a6be72e141615dbeeb1edb7d8`; final head `407e79e899d74a71f12b07ea69421927434ef775` had CI and CodeRabbit green, and issue #146 closed completed |
| 2026-06-12 10:16 | Address CodeRabbit PR #147 canonical path review | Tightened `--gas-snapshot` override validation so only the canonical release baseline path under `release-artifacts/baselines/v<protocol-version>/gas-snapshot.snap` is accepted, added a foreign-path regression, and reran focused checks, full `make check`, Windows wrapper, and whitespace checks successfully |
| 2026-06-12 09:54 | Address CodeRabbit PR #147 review | Accepted the version-aware gas snapshot manifest fix, tooling docs parity fix, and manifest-test digest/size nitpick; regenerated release evidence and reran focused checks, full `make check`, Windows wrapper, and whitespace checks successfully |
| 2026-06-12 09:29 | Open PR #147 and request CodeRabbit | Pushed `codex/local-gas-snapshot-baseline`, opened https://github.com/6529-Collections/6529Stream/pull/147 against `main`, linked `Closes #146`, requested CodeRabbit in comment `4689622593`, and intentionally skipped Claude per user instruction |
| 2026-06-12 09:26 | Finish local Queue Item 76 validation | Focused gas snapshot test and snapshot regeneration/check pass, release manifest/checksum/changelog drift checks pass, full `make check` and Windows `scripts\check.ps1` pass, and `git diff --check` is clean aside from normal line-ending notices |
| 2026-06-12 09:08 | Select Queue Item 76 | PR #145 merged as `9f1c2578ab12097e945c7400a2f37df83608a092` and issue #144 closed completed; no open GitHub issues remained, so issue #146 now scopes the next no-secret Gate D/G gap as a committed local gas snapshot baseline |
| 2026-06-12 08:44 | Address CodeRabbit PR #145 review | Accepted the two actionable comments and two low-cost nitpicks: CI py_compile now covers ceremony scripts, tooling docs include the test step, non-local ceremony evidence is scoped as future work, secret-like value detection has a regression, release artifacts were regenerated, and focused/full local gates plus the Windows wrapper pass |
| 2026-06-12 08:16 | Open PR #145 and request CodeRabbit | Pushed `codex/ceremony-evidence-schema`, opened https://github.com/6529-Collections/6529Stream/pull/145 against `main`, linked `Closes #144`, requested CodeRabbit in comment `4689045122`, and intentionally skipped Claude per user instruction |
| 2026-06-12 08:13 | Finish local Queue Item 75 validation | Focused ceremony evidence/release/changelog checks, py_compile, Bash syntax check, full `make check`, PowerShell parser check, and Windows wrapper all pass locally; CI and CodeRabbit remain pending until PR creation |
| 2026-06-12 07:51 | Implement Queue Item 75 local draft | Added ceremony evidence schema, local Anvil bundle, validator/tests, local/CI gate wiring, release manifest/checksum coverage, docs, roadmap, changelog, and run-state updates; focused ceremony evidence and release-manifest tests pass so far |
| 2026-06-12 07:39 | Create issue #144 and select Queue Item 75 | PR #143 merged and issue #142 closed completed; the next Gate E/G gap is retained deployment ceremony evidence format because live ceremonies need a no-secret evidence bundle before fork/testnet/production contents can be collected |
| 2026-06-12 07:34 | Merge PR #143 | Local emergency redeployment rehearsal merged as `6dd5846122ebca965a0f1bcefac0386f0ab0cb60`; CI run `27401454911` passed, CodeRabbit resolved the deployment-version assertion thread after commit `ed2a536806259f0ce25daddd9339dcd4cb90d762`, and issue #142 closed completed |
| 2026-06-12 06:09 | Open PR #141 and request CodeRabbit | Pushed `codex/dry-run-auction-ceremony`, opened https://github.com/6529-Collections/6529Stream/pull/141 against `main`, linked `Closes #140`, requested CodeRabbit in comment `4687976396`, and intentionally skipped Claude per user instruction |
| 2026-06-12 05:54 | Implement Queue Item 73 local draft | Added the local auction ceremony rehearsal script, focused deployment-manifest coverage, local/CI gate wiring, docs/roadmap/changelog/state updates, and validated the focused test plus standalone rehearsal script |
| 2026-06-12 05:41 | Select Queue Item 73 | PR #139 merged as `e09e422a4f95fbf6948d182fcff83a25aaf88e0c`, issue #135 closed completed, no open 6529Stream issue remained for the next Gate E local ceremony gap, and issue #140 now scopes the dry-run auction ceremony rehearsal |
| 2026-06-12 05:38 | Merge PR #139 | CI run `27396771559` passed, CodeRabbit status was success with no actionable comments on final head `13f90451bc471bbda9c7522a3c4f4b08f6cfb173`, the prior review thread was resolved, Claude was intentionally not requested per user instruction, and issue #135 closed completed |
| 2026-06-12 05:32 | Address CodeRabbit PR #139 review | Hardened Forge stdout parsing for noisy or multi-record JSON output, added empty `tokenDataRaw` coverage and import assertion diagnostics, and reran py_compile, focused tests, live rehearsal check, metadata fixture gate, full `make check`, and whitespace validation |
| 2026-06-12 05:16 | Open PR #139 and request CodeRabbit | Pushed `codex/live-fork-metadata-browser`, opened https://github.com/6529-Collections/6529Stream/pull/139 against `main`, linked `Closes #135`, requested CodeRabbit in comment `4687690174`, and intentionally skipped Claude per user instruction |
| 2026-06-12 05:13 | Validate Queue Item 72 locally | Focused Python rehearsal tests, live Forge-to-Chromium rehearsal check, metadata fixture gate, release manifest/checksum/changelog drift checks, full `make check`, Bash/PowerShell syntax checks, and whitespace checks pass; generated release manifest/checksum artifacts were refreshed |
| 2026-06-12 05:00 | Implement Queue Item 72 local draft | Added `RehearseMetadataBrowser.s.sol`, a return-payload-driven rehearsal browser checker, local/CI gate wiring, docs/roadmap/run-state/changelog updates, and release evidence refreshes for issue #135 |
| 2026-06-12 04:45 | Select Queue Item 72 | PR #138 merged as `9510a0f25bbdb61292644ab4ebdeba90e5d401fc`; issue #135 accepts fork or deployment-rehearsal generated metadata browser proof, and local Anvil rehearsal evidence can ship without RPC secrets |
| 2026-06-12 03:17 | Request CodeRabbit PR #133 review | CodeRabbit review requested in PR comment `4687004505`; Claude intentionally skipped per current user instruction |
| 2026-06-12 03:16 | Open PR #133 for Queue Item 69 | Pushed `codex/streamcore-size-floor-recovery`, opened https://github.com/6529-Collections/6529Stream/pull/133 against `main`, linked `Closes #132`, and will use CI plus CodeRabbit review only per user instruction |
| 2026-06-12 02:15 | Select Queue Item 69 | PR #131 merged as `3a6405d7d0cdc1d3550a8f872c6f17f3a0a147ac`; issue #132 scopes the next slice as recovering `StreamCore` from 24,348 runtime bytes / 228 bytes EIP-170 headroom back to the documented 384-byte release floor before further non-trivial Core work |
| 2026-06-12 02:00 | Address CodeRabbit PR #131 review | Accepted CodeRabbit's lifecycle-support finding by probing `supportsRandomizerLifecycle()` before token-state lookup, added unsupported-lifecycle pending fallback coverage, clarified ADR 0006 freeze eligibility docs for pending/stale/failed live tokens, refreshed release artifacts, and reran focused metadata tests, production size build, release checksum checks, full `make check`, Windows wrapper, formatting, and whitespace checks |
| 2026-06-12 01:45 | Request CodeRabbit PR #131 review | CodeRabbit review requested in issue comments `4686592260` and `4686597476`; Claude intentionally skipped per current user instruction |
| 2026-06-12 01:42 | Open PR #131 for Queue Item 68 | Pushed `codex/metadata-randomness-state-display`, opened https://github.com/6529-Collections/6529Stream/pull/131 against `main`, linked `Closes #130`, and will use CI plus CodeRabbit review only per user instruction |
| 2026-06-12 01:38 | Finish local Queue Item 68 validation | Focused metadata golden tests, production size build, release checksum generation/checking, full `make check`, Windows `scripts\check.ps1`, touched-file formatting, and whitespace checks pass; `StreamCore` remains EIP-170 compliant at 24,348 runtime bytes with 228 bytes of headroom, and the internal 384-byte headroom shortfall is documented as size-budget debt |
| 2026-06-12 01:23 | Implement Queue Item 68 local draft | Exposed lifecycle-aware `stale` and `failed` metadata states across `tokenMetadataState`, off-chain token URIs, and schema-v1 on-chain JSON; added stale/failed golden fixtures and tests; used a compact bounded `staticcall` fallback after rejecting two size-worse experiments |
| 2026-06-12 00:59 | Select Queue Item 68 | PR #129 merged as `7ccc771017be46c9f60fb6114abaf88ca98368a5`; issue #130 now scopes the next Gate D slice as stale/failed randomness metadata state display across views, off-chain URI fallback, on-chain schema-v1 JSON, fixtures, docs, and traceability |
| 2026-06-12 00:56 | Merge PR #129 | CI run `27387173347` passed on final head `a8567b8edcfd1d2a2a2d0fbb30e877265cc31e3d`, CodeRabbit reported no actionable comments and all 5 pre-merge checks passed, Claude was not triggered per user instruction, issue #128 closed completed, and PR #129 squash-merged as `7ccc771017be46c9f60fb6114abaf88ca98368a5` |
| 2026-06-12 00:48 | Address CodeRabbit PR #129 review | Updated active PR run-state evidence, added docstrings for the new browser sandbox scripts, expanded sandbox validation unit coverage to 16 tests, and reran `py_compile`, focused tests, live browser check, metadata fixture gate, release checksum drift check, `git diff --check`, and full `make check` |
| 2026-06-12 00:32 | Open PR #129 for Queue Item 67 | Pushed `codex/metadata-browser-sandbox-checks`, opened https://github.com/6529-Collections/6529Stream/pull/129 against `main`, linked `Closes #128`, and will use CI plus CodeRabbit review only per user instruction |
| 2026-06-12 00:30 | Validate Queue Item 67 locally | Full `make check`, Windows `scripts\check.ps1`, metadata fixture/browser gates, release checksum checks, Bash/PowerShell syntax checks, py-compile checks, and whitespace checks pass; generated release manifest/checksum artifacts were refreshed |
| 2026-06-12 00:18 | Implement Queue Item 67 local draft | Added pinned Playwright/Chromium browser sandbox tooling for the committed final metadata fixture, wired local/CI gates, updated docs/roadmap/state, and confirmed focused script tests plus the live browser check pass locally |
| 2026-06-12 00:07 | Start Queue Item 67 | PR #127 merged as `bed60c80c8ee5ac01a14e6e173b5f82d55396148`; issue #128 scopes the next P1-META-006 slice as a real browser execution sandbox check for committed animation metadata |
| 2026-06-12 00:04 | Merge PR #127 | CI passed, CodeRabbit completed with no actionable comments and 5/5 pre-merge checks, Claude was not triggered per user instruction, and PR #127 squash-merged as `bed60c80c8ee5ac01a14e6e173b5f82d55396148` |
| 2026-06-11 23:54 | Open PR #127 for Queue Item 66 | Pushed `codex/core-utf8-headroom`, opened https://github.com/6529-Collections/6529Stream/pull/127 against `main`, linked it with `Closes #125`, and will use CI plus CodeRabbit review only per user instruction |
| 2026-06-11 23:50 | Validate Queue Item 66 locally | Focused UTF-8/custom-error/URI-policy tests, release checksum regeneration, full `make check`, Windows `scripts\check.ps1`, touched-file `forge fmt --check`, and `git diff --check` pass; `StreamCore` remains 24,160 runtime bytes with 416 bytes of EIP-170 headroom |
| 2026-06-11 23:46 | Fix selector-preserving renderer helper reverts | Full test coverage caught that reverting from offset `0x1c` returned the wrong selector for `bytes4` values already positioned for calldata; reverting from `0x00` restores the existing `Invalid*Contract()` and `MetadataMutationPaused()` typed selectors without changing Core size |
| 2026-06-11 23:31 | Validate focused Queue Item 66 tests | The Core UTF-8 path now passes `forge test --match-path test/StreamMetadataUtf8.t.sol -vvv` with 12 tests and `forge test --match-path test/StreamCoreCustomErrors.t.sol -vvv` with 6 tests before the full local gate |
| 2026-06-11 23:24 | Recover Core UTF-8 size path | Renderer-linked metadata guard consolidation plus the compact `TokenNotMinted()` selector keeps `StreamCore` deployable at 24,160 runtime bytes with 416 bytes of EIP-170 headroom while restoring production invalid UTF-8 rejection for Core metadata writes |
| 2026-06-11 23:08 | Start Queue Item 66 | PR #126 merged as `2865658049ca648f15048dc53862b650558e3da9`; local `main` is synced, branch `codex/core-utf8-headroom` starts issue #125, and the first step is measuring bytecode-safe `StreamCore` UTF-8 enforcement paths |
| 2026-06-11 23:07 | Merge PR #126 | CI passed, CodeRabbit posted walkthrough/pre-merge checks with no actionable review threads, Claude was not triggered per user instruction, and a stuck pending CodeRabbit status was documented before squash merge |
| 2026-06-11 22:56 | Open PR #126 for Queue Item 65 | Pushed `codex/metadata-utf8-production`, opened https://github.com/6529-Collections/6529Stream/pull/126 against `main`, and linked it as part of issue #124 with Core enforcement split to issue #125 |
| 2026-06-11 22:50 | Validate Queue Item 65 locally | Focused UTF-8 and dependency-registry tests, full `make check`, Windows `scripts\check.ps1`, release manifest/checksum drift checks, Bash syntax, and whitespace checks pass; this PR remains a dependency-registry slice with Core enforcement tracked in issue #125 |
| 2026-06-11 22:45 | Run full Queue Item 65 local gate | `make check` passes after dependency registry UTF-8 enforcement, release artifact refresh, and the new UTF-8 suite; `StreamCore` remains 24,135 runtime bytes with 441 bytes of EIP-170 headroom |
| 2026-06-11 22:42 | Refresh Queue Item 65 release artifacts | `make release-checksums` passes after the dependency registry UTF-8 code/docs/state updates; production size gate remains green with `StreamCore` at 24,135 runtime bytes and `StreamMetadataRenderer` at 8,976 runtime bytes |
| 2026-06-11 22:38 | Implement Queue Item 65 local draft | Added a strict UTF-8 scanner in `StreamMetadataRenderer`, enforced it for `DependencyRegistry` dependency script/provenance writes, added `StreamMetadataUtf8.t.sol`, and updated docs/roadmap/changelog/state while keeping `StreamCore` unchanged |
| 2026-06-11 22:34 | Create issue #125 for Core UTF-8 size blocker | Direct, registry-backed, and inlined `StreamCore` UTF-8 enforcement experiments exceeded the EIP-170 production size gate, so issue #125 now tracks recovering size headroom or accepting a split design before Core-level invalid UTF-8 rejection |
| 2026-06-11 22:29 | Narrow Queue Item 65 scope | Production UTF-8 enforcement for `DependencyRegistry` fits and passes the production size gate; `StreamCore` remains 24,135 runtime bytes with 441 bytes of headroom, while direct Core enforcement measured 25,755 bytes and failed |
| 2026-06-11 22:12 | Start Queue Item 65 | PR #123 merged and main was synced; issue #124 starts production invalid UTF-8 work on branch `codex/metadata-utf8-production`, with CodeRabbit-only review per user instruction |
| 2026-06-11 22:05 | Merge PR #123 | Production raw-attribute schema enforcement merged as `b4c33bfa7315373191056728d48e0d48715b6532`; CI and CodeRabbit were clean, issue #122 closed, and local main fast-forwarded before selecting the next P1-META-006 slice |
| 2026-06-11 22:00 | Run full local gate after PR #123 review fix | `make check` passes after rejecting whitespace-only raw attributes and refreshing release artifacts, so the final push will carry both focused regression proof and the repository-wide gate |
| 2026-06-11 21:55 | Validate CodeRabbit PR #123 whitespace-only fix | Focused metadata tests pass with the new whitespace-only regression, release manifest/checksum checks pass after artifact refresh, `git diff --check` is clean, and `StreamCore` stays at 24,135 bytes with 441 bytes of EIP-170 headroom |
| 2026-06-11 21:51 | Accept CodeRabbit PR #123 whitespace-only finding | Whitespace-only raw attributes are nonempty and should not satisfy the production schema; keep only the zero-length fragment as the allowed empty case, add regression coverage, and refresh release artifacts |
| 2026-06-11 21:42 | Open PR #123 for Queue Item 64 | Pushed `codex/metadata-attribute-schema`, opened https://github.com/6529-Collections/6529Stream/pull/123 against `main`, and will request CodeRabbit after this durable state update is regenerated into the release artifacts and pushed |
| 2026-06-11 21:34 | Rerun artifact checks sequentially | The release-manifest and release-checksum targets both pass after the state update when run one at a time, avoiding the earlier parallel Foundry cache warning |
| 2026-06-11 21:31 | Validate Queue Item 64 locally | Focused metadata escaping tests, full `make check`, Windows `scripts\check.ps1`, release manifest/checksum checks, bash syntax, and whitespace checks pass; final artifact checks will be rerun sequentially after this covered state-file update |
| 2026-06-11 21:22 | Regenerate release artifacts for Queue Item 64 | Production raw-attribute parser changes alter linked `StreamMetadataRenderer` bytecode and docs/changelog hashes; `make release-checksums` refreshed ABI/source-verification/deployment/address-book/release checksum artifacts while `StreamCore` stayed at 24,135 bytes with 441 bytes of headroom |
| 2026-06-11 21:16 | Start Queue Item 64 | PR #121 merged cleanly, leaving production raw-attribute enforcement, production invalid UTF-8 policy, and browser execution sandboxing as the remaining P1-META-006 work; issue #122 scopes production raw attributes as the next smallest safe Solidity slice |
| 2026-06-11 21:16 | Bootstrap local Foundry | Direct `forge` commands were missing from PATH in this shell, so the pinned `scripts\bootstrap-windows.ps1` setup was run before Solidity validation |
| 2026-06-11 21:04 | Create issue #122 | The broad P1-META-006 issue #51 should remain open, but production raw-attribute schema enforcement deserves an issue-sized PR with exact tests and acceptance criteria |
| 2026-06-11 21:01 | Merge PR #121 | CI passed, CodeRabbit re-reviewed latest head `98094a5` and marked it good to merge, and the only visible review thread was resolved/outdated |
| 2026-06-11 20:50 | Address PR #121 CodeRabbit comments | Accepted the still-valid explicit `None` check for malformed fixture URI helpers and the roadmap wording for production raw-attribute enforcement; the stale release-manifest finding was already fixed in `ea90b91`, and artifacts will be regenerated again after this state update |
| 2026-06-11 20:43 | Fix PR #121 release-manifest CI drift | CI correctly found that the post-open `ops/AUTONOMOUS_RUN.md` state commit changed a release-manifest-covered input; update state first, regenerate release manifest/checksums, then push without further covered-file edits |
| 2026-06-11 20:39 | Open PR #121 and request CodeRabbit | Metadata fixture UTF-8/attribute safety PR opened at `https://github.com/6529-Collections/6529Stream/pull/121` on head `f6cc831b8837af1582d8828955da7c8d6e816cc6`; CodeRabbit review requested in issue comment `4684855824`, and Claude remains skipped per current user instruction |
| 2026-06-11 20:34 | Validate Queue Item 63 locally | Metadata fixture UTF-8/attribute regressions, dependency artifact LF drift check, release manifest/checksum checks, changelog gate, full `make check`, Windows wrapper, `py_compile`, bash syntax, and whitespace checks all pass; `StreamCore` remains 24,135 runtime bytes with 441 bytes of EIP-170 headroom |
| 2026-06-11 20:21 | Attach issue #120 to Queue Item 63 | Full `make check` found that Windows `core.autocrlf=true` changed packaged dependency `.js` bytes and made `dependency-artifact-manifest.json` drift; `.gitattributes` must pin `.js`/`.py` line endings before the metadata fixture PR can be considered cross-platform clean |
| 2026-06-11 20:13 | Select Queue Item 63 | PR #118 merged cleanly, and the next remaining `P1-META-006` gap that avoids the tight `StreamCore` bytecode budget is fixture-level invalid UTF-8 and semantic attribute-shape regression coverage tracked in issue #119 |
| 2026-06-11 20:11 | Merge PR #118 | Dependency artifact manifest packaging merged as `97ea7aecd0f6dc3614d0087528c25856b9f94594`; CI and CodeRabbit were green with no actionable review comments, and issue #117 closed completed |
| 2026-06-11 20:01 | Open PR #118 for Queue Item 62 | Pushed `codex/dependency-artifact-manifest`, opened https://github.com/6529-Collections/6529Stream/pull/118, and requested CodeRabbit review |
| 2026-06-11 19:59 | Validate Queue Item 62 locally | Dependency artifact generator tests/check with `.dependency.json` descriptors, release manifest/checksum checks, Python compile, full `make check`, Windows `scripts\check.ps1`, bash syntax, and whitespace checks all pass; `StreamCore` remains 24,135 runtime bytes with 441 bytes of EIP-170 headroom, and `git diff --check` reports only known Windows line-ending warnings |
| 2026-06-11 19:34 | Create issue #117 and start Queue Item 62 | No open issue covered dependency artifact manifest packaging, so issue #117 now tracks deterministic dependency descriptors, generated release manifest coverage, checksum coverage, and local/CI drift checks on branch `codex/dependency-artifact-manifest` |
| 2026-06-11 19:31 | Merge PR #116 | StreamCore bytecode headroom recovery merged as `a6d9271443d73a29290ec8eddc4908eae7aa8b32`; CI run `27371917056` passed on final head `fc12bc6ec019d7bd8f4f31ee1e807f056fcf4207`, the CodeRabbit state-thread fix was resolved, and issue #115 closed completed |
| 2026-06-11 19:17 | Validate PR #116 review fix locally | `make release-checksums`, `make check`, Windows `scripts\check.ps1`, targeted `forge fmt --check`, and `git diff --check` pass after the CodeRabbit fix; `git diff --check` reports only the known Windows line-ending warning on `release-artifacts/latest/SHA256SUMS` |
| 2026-06-11 19:09 | Address CodeRabbit PR #116 finding | `setFinalSupply` now rejects created collections with missing collection data before final supply math, the focused suite passes with 5 tests, and the production size gate measures `StreamCore` at 24,135 runtime bytes with 441 bytes of EIP-170 headroom |
| 2026-06-11 18:51 | Open PR #116 | `StreamCore` bytecode headroom recovery PR published at `https://github.com/6529-Collections/6529Stream/pull/116`; state-only follow-up records the PR URL before requesting CodeRabbit on the final head |
| 2026-06-11 18:48 | Validate Queue Item 61 locally | Focused custom-error regressions, production size gate, regenerated release artifacts, full `make check`, Windows wrapper, targeted formatting, and whitespace checks all pass; the final review-fix pass records `StreamCore` at 24,135 runtime bytes with 441 bytes of EIP-170 headroom |
| 2026-06-11 18:39 | Set interim `StreamCore` size policy | The local P1-SIZE-001 pass established a repo policy of 384 bytes as the minimum release floor and 512 bytes as the warning threshold for future non-trivial Core work; final review-fix measurement is 24,135 runtime bytes with 441 bytes of EIP-170 headroom |
| 2026-06-11 18:37 | Drop burn custom-error experiment | Replacing the `burn` owner/approval string revert with a custom error increased `StreamCore` runtime by 20 bytes versus the narrower pass, so the change was abandoned before documentation and tests |
| 2026-06-11 18:22 | Validate PR #114 outside-diff follow-up locally | Focused regressions, production size gate, regenerated release artifacts, full `make check`, Windows wrapper, targeted formatting, and whitespace checks all pass; `StreamCore` remains deployable at 24,545 bytes with 31 bytes of EIP-170 headroom |
| 2026-06-11 18:15 | Accept CodeRabbit PR #114 outside-diff findings | The zero-supply path still reverted via arithmetic panic on first initialization, and dependency registry swaps still accepted EOAs or zero addresses; both are fixed locally with typed errors/regressions while keeping `StreamCore` deployable at 24,545 bytes and 31 bytes of EIP-170 headroom |
| 2026-06-11 18:00 | Track PR #114 bytecode headroom risk | CodeRabbit correctly highlighted that `StreamCore` has only 61 bytes of EIP-170 margin after the review fix, so issue #115 and the roadmap now track recovering sustainable Core headroom before further non-trivial Core feature work |
| 2026-06-11 17:52 | Validate PR #114 CodeRabbit fixes | Focused metadata/randomizer lifecycle regressions, the EIP-170 size gate, release artifact regeneration, full `make check`, Windows wrapper, formatting, and whitespace gates passed after persisting full-update base URIs and hardening marker probes |
| 2026-06-11 17:44 | Accept CodeRabbit PR #114 findings | The base URI persistence finding was a real storage bug, and the marker-probe finding was valid for invalid targets; moving the low-level marker probe into `StreamMetadataRenderer` keeps `StreamCore` deployable with 61 bytes of EIP-170 headroom while preserving typed errors |
| 2026-06-11 17:21 | Request CodeRabbit on PR #114 | CodeRabbit review requested in issue comment `4683145207`; Claude intentionally skipped per current user instruction |
| 2026-06-11 17:20 | Open PR #114 | Collection metadata URI policy PR published at `https://github.com/6529-Collections/6529Stream/pull/114`; this state-only follow-up records the PR URL before requesting CodeRabbit on the final head |
| 2026-06-11 17:17 | Validate Queue Item 60 locally | Collection URI policy tests, metadata freeze/golden regressions, release artifact regeneration, full `make check`, Windows `scripts\check.ps1`, touched-file formatting, whitespace validation, and the production size gate pass; final validation regenerated release artifacts after a docs checksum drift and `StreamCore` is 24,348 runtime bytes with 228 bytes of EIP-170 headroom |
| 2026-06-11 16:55 | Use custom-error cleanup to keep queue item 60 deployable | Direct collection base/library URI enforcement exceeded EIP-170; replacing old `StreamCore` string reverts on metadata, mint, randomizer, and wiring paths made production enforcement fit and improved revert traceability |
| 2026-06-11 16:47 | Start Queue Item 60 | PR #113 intentionally left collection base URI and external library URL production enforcement as follow-up because the first attempt exceeded EIP-170; this is the next highest-value P1-META-006 slice |
| 2026-06-11 16:45 | Merge PR #113 | CI run `27362208606` passed, CodeRabbit status was success with no actionable comments, no review threads remained, and PR #113 merged as `ae5fcee4639de8d51f8fe380e0c72606090da137` |
| 2026-06-11 15:58 | Validate PR #112 CodeRabbit response locally | Focused metadata fixture tests/check, Python compile, full `make check`, Windows `scripts\check.ps1`, and whitespace validation pass after the empty-image guard |
| 2026-06-11 15:55 | Address CodeRabbit PR #112 review locally | Accepted the empty metadata image finding by making required metadata `image` URIs nonempty and adding a hostile fixture regression; skipped the optional off-chain final `/final` suffix suggestion because the committed final fixture is intentionally content-addressed as `ipfs://base/10000000000` |
| 2026-06-11 15:42 | Open PR #112 and request CodeRabbit | Metadata fixture safety PR published at `https://github.com/6529-Collections/6529Stream/pull/112`; head is `d2f270b254d1e3a7b115817c62f2acf0a40efec9`; CodeRabbit review requested in issue comment `4682324523`; Claude intentionally skipped per current user instruction |
| 2026-06-11 15:40 | Validate Queue Item 58 locally | Metadata fixture tests/check, Python compile, shell/PowerShell syntax, changelog gate, whitespace check, release checksum regeneration, full `make check`, and Windows wrapper all pass; production bytecode is unchanged with `StreamCore` still at 24,461 runtime bytes |
| 2026-06-11 15:20 | Start Queue Item 58 | Next P1-META-006 slice is metadata render-sandbox fixture validation because it adds local/CI safety evidence for committed metadata outputs without consuming the remaining `StreamCore` bytecode headroom |
| 2026-06-11 15:19 | Merge PR #111 | CI run `27356813758` passed, CodeRabbit status was success with no actionable comments, no review threads remained, and PR #111 merged as `f844457a2f48fc31f34c187cef72f2083cfe6b70`; issue #51 remains open for the rest of P1-META-006 |
| 2026-06-11 15:08 | Open PR #111 and request CodeRabbit | Metadata size-limit PR published at `https://github.com/6529-Collections/6529Stream/pull/111`; CodeRabbit review requested in issue comment `4682019145`; Claude intentionally skipped per current user instruction |
| 2026-06-11 15:06 | Validate Queue Item 57 locally | Focused metadata/dependency tests, full `make check`, Windows wrapper, production size gate, release artifact generation/checks, touched-file formatting, and whitespace validation pass; full smart-contract formatting still fails on existing untouched legacy files |
| 2026-06-11 14:53 | Start Queue Item 57 | Issue #51 remains open for P1-META-006; numeric metadata size limits are a deterministic, high-value slice after PR #87/#88 and can ship without deciding the remaining URI/schema/UTF-8/browser sandbox policies |
| 2026-06-11 14:51 | Enforce generated response cap at `tokenURI` boundary | A separate generated-animation URI cap made `StreamCore` exceed EIP-170; enforcing the generated `tokenURI` cap preserves the external response limit while keeping production bytecode deployable |
| 2026-06-11 14:49 | Trim `StreamCore` size before docs/artifact work | Initial size-limit implementation exceeded EIP-170 by 123 bytes; removing redundant generated-animation measurement brought `StreamCore` to 24,461 runtime bytes with 115 bytes of headroom |
| 2026-06-11 14:46 | Merge PR #110 | CI passed, CodeRabbit status and review threads were clean after the state-placeholder fix, PR #110 merged as `d248502263a1c8cd7d4b415750d4cfd5e78f2e0a`, and issue #109 closed completed |
| 2026-06-11 14:30 | Address CodeRabbit PR #110 state-log nitpick locally | Replaced the non-deterministic head placeholder with concrete review-fix code head `29412bd342c8c3676265599b33e4eaab8caa2e9b`; this follow-up is state-only and exists to keep the durable run log auditable |
| 2026-06-11 14:23 | Address CodeRabbit PR #110 finding locally | Accepted the secret-key normalization finding; forbidden-key checks now lowercase and strip non-alphanumerics before comparison, regression tests cover mixed-case and separator variants, and focused generator tests/check pass |
| 2026-06-11 14:10 | Open PR #110 | Broadcast-manifest ingestion PR published at `https://github.com/6529-Collections/6529Stream/pull/110`; state-only follow-up will push the PR URL before requesting CodeRabbit on the final head |
| 2026-06-11 14:06 | Validate Queue Item 56 locally | Focused broadcast ingestion tests/check, deployment manifest checks for both configs, address-book/release-manifest/release-checksum/changelog tests and checks, Python compile, shell/PowerShell syntax, whitespace check, full `make check`, and Windows wrapper all pass on the final parser-adjusted code |
| 2026-06-11 13:55 | Implement Queue Item 56 local draft | Added sanitized Foundry broadcast ingestion, generated broadcast-derived deployment config/manifest/address book, wired release manifest/checksum coverage and local/CI gates, and updated docs/roadmap/run-state traceability |
| 2026-06-11 13:32 | Start Queue Item 56 | Issue #109 tracks deterministic Foundry broadcast-manifest ingestion; branch `codex/broadcast-manifest-ingestion` starts from merged PR #108 and scopes to offline sanitized broadcast evidence |
| 2026-06-11 13:29 | Merge PR #108 | Source verification inputs merged as `98696bf2953b93aeade4265a3c8a35201589b2ef`; CI run `27349988458` passed, CodeRabbit latest-head status was success, the review thread was resolved/outdated, and issue #107 closed completed |
| 2026-06-11 13:23 | Validate CodeRabbit PR #108 fix locally | Source-verification regression, drift checks, manifest/checksum checks, Python compile, whitespace check, full `make check`, and Windows wrapper all pass after deduplicating library placeholders |
| 2026-06-11 13:17 | Address CodeRabbit PR #108 finding locally | Accepted the duplicate-library-placeholder review finding, added regression coverage for different creation/runtime link offsets, regenerated source-verification and release checksum artifacts, and prepared for focused/full validation before pushing |
| 2026-06-11 13:04 | Open PR #108 and request CodeRabbit | Source verification input PR published at `https://github.com/6529-Collections/6529Stream/pull/108`; CodeRabbit review requested in issue comment `4680853110`; Claude intentionally skipped per current user instruction |
| 2026-06-11 13:02 | Validate Queue Item 55 locally | Source-verification tests/check, release-artifact ownership regression, release manifest/checksum checks, changelog checks, Python compile, shell/PowerShell syntax, whitespace, full `make check`, and Windows wrapper all pass |
| 2026-06-11 12:52 | Implement source verification bundle | Added generator, tests, tracked artifact, release-manifest/checksum integration, local/CI gate wiring, docs, roadmap, changelog, and durable state updates |
| 2026-06-11 12:41 | Start Queue Item 55 | Issue #107 tracks deterministic source verification input retention; branch `codex/source-verification-inputs` starts from merged PR #106 and scopes to generated verification inputs plus local/CI drift checks |
| 2026-06-11 12:40 | Create source verification issue #107 | No open issue covered retained source verification inputs, so a focused P1 release issue keeps the Gate G PR auditable |
| 2026-06-11 12:38 | Merge PR #106 | Release manifest merged as `30bbf4baabd689bf6243c5a8ec41051aff02060f`; CI run `27347108379` passed, CodeRabbit latest-head status was success, no review threads remained, and issue #105 closed completed |
| 2026-06-11 12:34 | Validate PR #106 review fix locally | Manifest tests/check, changelog check, Python compile, and whitespace check pass after accepting the CodeRabbit consistency nitpick |
| 2026-06-11 12:33 | Address CodeRabbit PR #106 nitpick locally | Accepted the consistency suggestion for `scripts/test_release_manifest.py`; focused validation will run before pushing the review fix |
| 2026-06-11 12:20 | Open PR #106 | Release manifest PR published at `https://github.com/6529-Collections/6529Stream/pull/106`; this state-only follow-up records the PR URL before requesting CodeRabbit on the final head |
| 2026-06-11 12:18 | Validate Queue Item 54 locally | Release manifest tests/check, release checksum tests/check, release artifact ownership-regression tests/check, changelog tests/check, Python compile, shell/PowerShell syntax, whitespace check, full `make check`, and Windows wrapper all pass |
| 2026-06-11 12:06 | Start Queue Item 54 | Issue #105 tracks the machine-readable release manifest gap; branch `codex/release-manifest` starts from merged PR #104 and scopes to deterministic manifest generation plus local/CI drift checks |
| 2026-06-11 11:54 | Create release manifest issue #105 | No open issue covered the top-level release manifest, so a focused P1 release issue keeps the Gate G PR auditable |
| 2026-06-11 11:52 | Merge PR #104 | Release change policy/changelog gate merged as `012bea914262c0b56601fc5824f7175d7a8218f1`; CI run `27344538408` passed, CodeRabbit latest-head review finished with no actionable comments/status success, the prior thread was resolved/outdated, and issue #103 closed completed |
| 2026-06-11 11:46 | Address CodeRabbit PR #104 review locally | Accepted the placeholder-bypass finding and PR-template wording nit; focused changelog tests/check, Python compile, shell/PowerShell syntax, and whitespace checks pass |
| 2026-06-11 11:34 | Open PR #104 | Release change policy/changelog gate PR published at `https://github.com/6529-Collections/6529Stream/pull/104`; a state-only follow-up records the PR URL before requesting CodeRabbit on the final head |
| 2026-06-11 11:33 | Validate Queue Item 53 locally | Changelog gate tests/check, Python compile, shell/PowerShell syntax, Markdown heading trace, whitespace check, full `make check`, and Windows wrapper all pass; implementation also fixed local changelog auto-detection by resolving `git` with `shutil.which()`, failing closed on required git diff errors, and including untracked files |
| 2026-06-11 11:11 | Start Queue Item 53 | Issue #103 tracks the remaining Gate G ABI/release change approval policy gap; branch `codex/release-change-policy` starts from merged PR #102 and scopes to policy docs plus a changelog gate, excluding real signatures and production addresses |
| 2026-06-11 11:11 | Create release change policy issue #103 | No open issue covered the release/changelog approval gate, so a focused P1 release issue keeps this PR auditable |
| 2026-06-11 11:09 | Merge PR #102 | Release checksum bundle merged as `de10363c8aae72755decb50a3ffabee224be4536`; CI run `27342290072` passed, CodeRabbit latest-head review finished with no actionable comments/status success, no review threads remained, and issue #101 closed completed |
| 2026-06-11 11:02 | Address CodeRabbit PR #102 review locally | Accepted both findings: `release-artifacts/README.md` now shows deployment manifest and address-book generation/checking before checksum refresh, and `parse_checksum_file` rejects parent-directory path traversal with focused regression coverage; focused/full/Windows validation passed |
| 2026-06-11 10:43 | Open PR #102 | Release checksum bundle PR published at `https://github.com/6529-Collections/6529Stream/pull/102`; one state-only follow-up will record the PR URL before requesting CodeRabbit on the final head |
| 2026-06-11 10:42 | Validate Queue Item 52 locally | Release checksum tests/check, release artifact ownership-regression test/check, Python compile, shell/PowerShell syntax, JSON/line-format parsing, traceability grep, full `make check`, Windows wrapper, and whitespace validation all pass; release-artifact check now ignores checksum-bundle outputs so both generated artifact families can coexist, and check mode reports deleted covered files even when the regenerated covered set becomes empty |
| 2026-06-11 10:22 | Start Queue Item 52 | Issue #101 tracks the Gate G signable checksum-bundle gap; branch `codex/release-checksum-bundle` starts from merged PR #100 and scopes to deterministic SHA256SUMS/manifest generation plus local/CI drift checks |
| 2026-06-11 10:18 | Create release checksum issue #101 | No open issue covered deterministic release checksum bundles, so a focused P1 release issue keeps the Gate G PR auditable |
| 2026-06-11 10:15 | Merge PR #100 | Address-book generator merged as `ad6deea8b6ba33e90703da1d7bd105f29eb7a24f`; CI run `27339627582` passed, CodeRabbit final re-check comment `4679472288` was clean, the only review thread was resolved, and stale aggregate CodeRabbit status was documented in merge decision comment `4679490149` |
| 2026-06-11 10:08 | Address CodeRabbit PR #100 integer validator finding locally | Accepted CodeRabbit inline comment `3394948002`: `require_int` now rejects booleans, chain IDs must be positive, git commits must be 40-character hashes, lifecycle states are constrained to the deployment schema enum, address-book tests now cover 14 cases including missing output directory and unknown contracts, and focused checks, full `make check`, Windows wrapper, JSON parsing, and whitespace validation pass |
| 2026-06-11 10:00 | Address CodeRabbit PR #100 findings locally | Accepted CodeRabbit comment `4679312734`: removed duplicate Makefile execution, added an explicit generated-output docs note, added `deployments/schema/address-book.schema.json`, normalized generated addresses to lowercase, constrained `verification_status`, validated `sha256:` hash formats, expanded address-book tests to 8 cases, and reran focused checks, full `make check`, Windows wrapper, JSON parsing, and whitespace validation successfully |
| 2026-06-11 09:49 | Open PR #100 and request CodeRabbit | Address-book generator PR published at `https://github.com/6529-Collections/6529Stream/pull/100`; CodeRabbit review requested in issue comment `4679297117`; Claude remains intentionally skipped per current user instruction |
| 2026-06-11 09:47 | Validate Queue Item 51 locally | Address-book generator tests, address-book drift check, Python compile, shell/PowerShell syntax, JSON parsing, full `make check`, Windows wrapper, and whitespace validation all pass; validation tightened `source_dirty` to strict boolean parsing and records the ABI checksum source path in the generated artifact |
| 2026-06-11 09:28 | Start Queue Item 51 | Issue #99 tracks the remaining deterministic address-book artifact gap; branch `codex/address-book-generator` starts from merged PR #98 and scopes to manifest-derived address books plus local/CI drift checks |
| 2026-06-11 09:27 | Create address-book issue #99 | No open issue covered deterministic address books, so a focused P1 release issue keeps the Gate G PR auditable |
| 2026-06-11 09:25 | Merge PR #98 | ABI compatibility checks merged as `5646761344b5387f280aa928a158e4a6ac1e9711`; CI run `27336811054` passed, CodeRabbit injected release notes but left a stale pending status with no review threads, and the autonomous maintainer decision was to merge rather than stall |
| 2026-06-11 09:17 | Open PR #98 and request CodeRabbit | ABI compatibility PR published at `https://github.com/6529-Collections/6529Stream/pull/98`; CodeRabbit review requested in issue comment `4679037794`; Claude remains intentionally skipped per current user instruction |
| 2026-06-11 09:15 | Validate Queue Item 50 locally | ABI compatibility generator/checker tests, compatibility drift check, Python compile, shell/PowerShell syntax, JSON parsing, full `make check`, Windows wrapper, and whitespace validation all pass |
| 2026-06-11 09:09 | Start Queue Item 50 | Issue #97 tracks the remaining deterministic ABI diff gate; branch `codex/abi-compatibility-checks` starts from merged PR #96 and scopes to a committed ABI surface baseline plus local/CI compatibility checks |
| 2026-06-11 09:01 | Create ABI compatibility issue #97 | No open issue covered ABI compatibility diff checks, so a focused P1 release issue keeps the Gate G PR auditable |
| 2026-06-11 08:58 | Merge PR #96 | Deployment manifest generator merged as `3d317f760de5cd2d009dd749a76551b28264c24e`; CI run `27335241255` passed, CodeRabbit generated release notes but left a stale pending status with no review threads, and the autonomous maintainer decision was to merge rather than stall |
| 2026-06-11 08:49 | Open PR #96 and request CodeRabbit | Deployment manifest generator PR published at `https://github.com/6529-Collections/6529Stream/pull/96`; CodeRabbit review requested in issue comment `4678810031`; Claude remains intentionally skipped per current user instruction |
| 2026-06-11 08:47 | Validate Queue Item 49 locally | Deployment manifest generator, manifest drift checks, JSON parsing, shell/PowerShell syntax, full `make check`, Windows wrapper, and whitespace validation all pass |
| 2026-06-11 08:35 | Start Queue Item 49 | Issue #95 tracks the remaining local manifest-generation gap; branch `codex/deployment-manifest-generator` starts from merged PR #94 and scopes to generated Anvil manifests plus drift checks |
| 2026-06-11 08:26 | Create deployment manifest issue #95 | No open issue covered deterministic deployment manifest generation/checking from committed inputs, so a focused P1 deployment issue keeps the PR auditable |
| 2026-06-11 08:24 | Merge PR #94 | Release artifact catalog merged as `d89ac51576af1922e2e7559f6c94c1f10a5de487`; CI run `27333506619` passed, CodeRabbit produced a PR summary but left a stale pending status with no review threads, and the autonomous maintainer decision was to merge rather than stall |
| 2026-06-11 08:15 | Open PR #94 and request CodeRabbit | Release artifact catalog PR published at `https://github.com/6529-Collections/6529Stream/pull/94`; CodeRabbit review requested in issue comment `4678554666`; Claude remains intentionally skipped per current user instruction |
| 2026-06-11 08:12 | Validate Queue Item 48 locally | Release artifact generator, drift checks, JSON parsing, shell/PowerShell syntax, full `make check`, Windows wrapper, and whitespace validation all pass; release artifacts are generated from the production `via-ir` build profile |
| 2026-06-11 07:59 | Start Queue Item 48 | Issue #93 tracks the Gate G release-artifact gap; branch `codex/release-artifact-catalog` starts from merged PR #92 and scopes to deterministic ABI/bytecode/interface/event catalog generation plus drift checks |
| 2026-06-11 07:44 | Create release artifact issue #93 | No open issue covered ABI checksums, interface IDs, and event topic catalog generation, so a focused P1 release issue keeps the PR auditable |
| 2026-06-11 07:38 | Merge PR #92 | Deployment rehearsal baseline merged as `eeefda163c2b727a9e3fba3922a220d184babf6c`; CI was green on final head `7b1381a78898a50c8d82dda6cafc8361381cc5f7`, CodeRabbit was green, and the only actionable thread was resolved |
| 2026-06-11 07:29 | Address CodeRabbit PR #92 comments | Accepted both low-risk review items: normalized the `StreamMetadataRenderer` size evidence to `6,843` bytes throughout the PR #90 audit trail and changed the deployment manifest schema `$id` to a resolvable raw GitHub URL |
| 2026-06-11 07:16 | Open PR #92 and request CodeRabbit | Deployment rehearsal baseline published at `https://github.com/6529-Collections/6529Stream/pull/92`; CodeRabbit review requested in issue comment `4678115878`; Claude remains intentionally skipped per current user instruction |
| 2026-06-11 07:14 | Revalidate Queue Item 47 after manifest expansion | Expanded the local example manifest to cover all nine deployed contracts and ABI hash placeholders, then reran focused manifest tests, `make check`, Windows wrapper, and whitespace validation successfully |
| 2026-06-11 07:05 | Finish Queue Item 47 local validation | Full local and Windows gates pass after adding the local deployment rehearsal, manifest schema/example, manifest parsing/wiring tests, CI workflow rehearsal step, and production size command narrowed to skip both test and script artifacts |
| 2026-06-11 06:57 | Exclude scripts from production size gate | `forge build --sizes --via-ir --skip test` measured the new rehearsal script bytecode as if it were production deployable bytecode; the release gate now uses `--skip test --skip script` and CI has a separate deployment rehearsal step |
| 2026-06-11 06:44 | Start Queue Item 47 | PR #90 is merged, issue #91 now tracks the missing Gate E deployment rehearsal baseline, and branch `codex/deployment-rehearsal` starts from `origin/main` |
| 2026-06-11 06:37 | Merge PR #90 | Size-reduction PR merged as `36d993a946aad298b920c19fcbc26485b220b6e4`; CI passed on final head `a6db76f68c0fb7bb6ebeabafdff53583ee488b53`, CodeRabbit was green, and review threads were resolved |
| 2026-06-11 06:31 | Address CodeRabbit PR #90 comments locally | Accepted both CodeRabbit quick wins: escape public renderer `schemaVersion`/`metadataState` inputs, add direct library regression coverage, and align roadmap Slither low/informational counts; focused metadata tests, Windows wrapper, size gate, whitespace, and Slither comparison all pass |
| 2026-06-11 06:17 | Open PR #90 | StreamCore size-reduction PR published at `https://github.com/6529-Collections/6529Stream/pull/90`; the branch proves `StreamCore` fits under EIP-170 through the production size gate, and CodeRabbit will be requested after the PR state update is pushed |
| 2026-06-11 06:13 | Finish Queue Item 46 local validation | Full local gate set is ready for PR: `make check`, Windows wrapper, touched-file formatting, whitespace, production size gate, stale-helper grep, and Slither baseline comparison all pass; `StreamCore` is `23,139` runtime bytes with `1,437` bytes of EIP-170 headroom, and Slither high/medium remain unchanged at `4/19` |
| 2026-06-11 06:04 | Keep only the high-value renderer library extraction | Temporary freeze/dependency/randomizer helper extractions barely changed `StreamCore` size and would have added extra linked-library calls in mint/freeze/admin paths, so they were folded back into `StreamCore`; the final local production size gate still passes with `StreamCore` at `23,139` runtime bytes and `1,437` bytes of EIP-170 headroom |
| 2026-06-11 05:57 | Use IR-optimized production size gate | Default all-artifact `forge build --sizes` still measures non-production test/script artifacts and default non-IR `StreamCore` bytecode; the production release gate is now explicit as `forge build --sizes --via-ir --skip test --skip script --force`, which skips non-production artifacts and proves deployable contracts fit |
| 2026-06-11 05:48 | Remove optional ERC721Enumerable support | The roadmap already identified ERC721Enumerable as a P1 architecture concern; `StreamCore` only needs live supply locally, so the optional enumerable interface was removed, live `totalSupply()` was preserved, and interface support is now explicitly tested |
| 2026-06-11 05:31 | Start Queue Item 46 | PR #88 is merged and `forge build --sizes` now shows an explicit `StreamCore` deployment blocker, so issue #89 tracks P1-DEPLOY-001 and branch `codex/streamcore-size-reduction` starts with low-risk metadata renderer/escaper extraction |
| 2026-06-11 05:29 | Create issue #89 for EIP-170 blocker | P1-META-006 still owns metadata escaping/size/render policy, but `StreamCore` exceeding EIP-170 is a separate release/deployment blocker that needs its own acceptance criteria and size-budget evidence |
| 2026-06-11 05:17 | Address CodeRabbit PR #88 control-character note | CodeRabbit found the wrapper implementation sound and noted one low-severity browser URL-parser gap for null/control characters in `collectionLibrary`; `_escapeHtmlAttribute` now entity-escapes C0 controls and DEL, the decoded HTML test covers embedded null/newline bytes, focused/adjacent/full/Windows/format/whitespace gates pass, Slither remains `718` total findings with high/medium unchanged at `4/19`, and `forge build --sizes` reports the known `StreamCore` blocker at `35,696` runtime bytes |
| 2026-06-11 05:11 | Open PR #88 and request CodeRabbit | Animation wrapper safety is published at `https://github.com/6529-Collections/6529Stream/pull/88`; CodeRabbit review requested in issue comment `4677381075`; Claude remains intentionally skipped per current user instruction |
| 2026-06-11 05:08 | Validate Queue Item 45 locally | Focused metadata escaping tests, adjacent metadata suite, full `make check`, Windows wrapper, touched-file formatting, whitespace, and Slither baseline comparison pass; Slither remains `718` total findings with high/medium unchanged at `4/19`; `forge build --sizes` continues to expose the known oversized `StreamCore` release blocker at `35,281` runtime bytes |
| 2026-06-11 04:52 | Start Queue Item 45 | PR #87 merged, local `main` is synced, issue #51 was reopened because only the first metadata escaping slice landed, and the next tight P1-META-006 slice is generated animation HTML wrapper safety |
| 2026-06-11 04:51 | Reopen issue #51 | PR #87 intentionally left generated HTML/JavaScript escaping or rejection, semantic attribute schema/structured attributes, URI policy, invalid UTF-8 policy, size limits, and render-sandbox tests open, so the issue should continue tracking the remaining P1-META-006 acceptance criteria |
| 2026-06-11 04:49 | Merge PR #87 | Final head `1c50f7a0d4703c2712e714789f7d32d3543f490d` was CI-clean, CodeRabbit success, no actionable comments were generated for the state-only follow-up, and the visible delimiter review thread was resolved |
| 2026-06-11 04:45 | Mark PR #87 merge-ready | CI run `27324323091` passed on head `1daa794be32809f582d9398f39b5f62bb6c25f79`, CodeRabbit status is success with final clean comment `4677250565`, and the only visible inline review thread was resolved by CodeRabbit |
| 2026-06-11 04:42 | Address CodeRabbit PR #87 delimiter finding | Added container-kind tracking to the raw-attribute parser so object and array closers must match their opener, covered mismatched `{]` and `[}` delimiters, and refreshed focused 9-test metadata escaping suite, full `make check`, Windows wrapper, touched-file formatting, whitespace, and Slither baseline comparison; Slither remains `718` total findings with high/medium unchanged at `4/19` |
| 2026-06-11 04:35 | Address CodeRabbit PR #87 positive-test suggestions | Added empty-attributes and multiple-top-level-object acceptance tests, refreshed focused 8-test metadata escaping suite, full `make check`, Windows wrapper, touched-file formatting, whitespace, and Slither baseline comparison; Slither remains `718` total findings with high/medium unchanged at `4/19` |
| 2026-06-11 04:28 | Open PR #87 and request CodeRabbit | Metadata escaping safety baseline published at `https://github.com/6529-Collections/6529Stream/pull/87`; CodeRabbit review requested in issue comment `4677178780`, and Claude remains intentionally skipped per current user instruction |
| 2026-06-11 04:26 | Finish Queue Item 44 local validation | Focused metadata escaping tests, adjacent metadata suite, full `make check`, Windows wrapper, touched-file formatting, whitespace, heading/traceability scans, and Slither baseline comparison all pass; Slither remains `718` total findings with high/medium unchanged at `4/19` |
| 2026-06-11 04:09 | Implement Queue Item 44 local draft | Added JSON string escaping, raw attribute structural guards, parser-backed metadata escaping tests, adjacent metadata validation, and docs/roadmap traceability while leaving generated HTML/JavaScript escaping, URI policy, invalid UTF-8 policy, size limits, and render-sandbox tests as explicit follow-up work under issue #51 |
| 2026-06-11 03:59 | Start Queue Item 44 | PR #86 merged and main is synced; issue #51 is the next Gate D metadata row covering JSON escaping, size policy, render-sandbox tests, and executable metadata docs |
| 2026-06-11 03:58 | Merge PR #86 | CI passed, CodeRabbit confirmed the remint fix and reported no actionable follow-up comments, the review thread was resolved by CodeRabbit, and issue #50 was closed by the squash merge |
| 2026-06-11 03:54 | Address CodeRabbit PR #86 remint finding | Added `BurnedTokenRemintNotAllowed` guard in `_mintProcessing`, covered failed remint after burn, documented terminal burned token IDs, and reran focused/adjacent/full/Windows/format/whitespace/traceability/Slither gates with high/medium unchanged at `4/19` |
| 2026-06-11 03:35 | Open PR #86 | Burn metadata semantics are published with local validation evidence, close issue #50, and CodeRabbit review was requested with `@coderabbitai review` |
| 2026-06-11 03:33 | Validate Queue Item 43 locally | Focused burn tests, adjacent metadata/randomizer suites, full `make check`, Windows wrapper, touched-file formatting, whitespace, heading scan, traceability grep, and Slither comparison all pass; Slither remains `718` total findings with high/medium unchanged at `4/19` |
| 2026-06-11 03:24 | Fix Queue Item 43 freeze regression and Slither drift | Moved non-burned token-hash freeze checks before range/collection checks so frozen collections fail closed with `MetadataFrozen`, and removed test/helper/static-analysis drift while keeping post-burn timestamps audit-only |
| 2026-06-11 03:10 | Implement Queue Item 43 local draft | Added retained burned-token audit state, protocol burn events, request-linked post-burn randomness audit events for VRF/arRNG, freeze-safe post-burn hash recording, and focused burn tests |
| 2026-06-11 03:09 | Validate Queue Item 43 focused tests | `forge test --match-contract StreamCoreBurnTest -vvv` passes with 3 tests covering burn audit state, post-burn VRF fulfillment after freeze, and arRNG parity |
| 2026-06-11 03:02 | Select Queue Item 43 | The next missing Gate D row is P1-META-005 burn metadata semantics; it is tightly scoped after freeze/dependency work and before escaping/render-safety work |
| 2026-06-11 03:00 | Merge PR #85 | PR #85 merged as `49f9204`; CI passed, CodeRabbit review threads were resolved/outdated, and a stale pending aggregate CodeRabbit context was documented before merge |
| 2026-06-11 02:45 | Validate CodeRabbit PR #85 registry-address fix | Focused dependency tests now pass with 10 tests including registry-swap stability, adjacent metadata/freeze suites pass, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither comparison pass with high/medium unchanged at `4/19` |
| 2026-06-11 02:36 | Address CodeRabbit PR #85 registry-address review | Store the dependency registry address in each collection dependency pin and use that pinned registry for script retrieval, state views, events, and freeze manifests so a global registry swap cannot alter already-pinned output |
| 2026-06-11 02:17 | Validate CodeRabbit PR #85 sentinel drift fix | Focused dependency tests now pass with 9 tests, adjacent metadata/freeze suites pass, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither comparison pass with high/medium unchanged at `4/19` |
| 2026-06-11 02:13 | Address CodeRabbit PR #85 sentinel drift review | Reserve `bytes32(0)` in dependency registry writes and bypass registry latest-version lookup for no-dependency pins so the sentinel cannot drift if a zero-key dependency is attempted |
| 2026-06-11 01:58 | Address CodeRabbit PR #85 review | Fail closed for nonzero unknown dependency keys while preserving the explicit `bytes32(0)` no-dependency sentinel, move duplicate dependency-repinning test helpers into `StreamFixture`, add regression coverage, and rerun focused/full/Windows/Slither validation with high/medium unchanged at `4/19` |
| 2026-06-11 01:42 | Open PR #85 | Dependency version immutability is published with local validation evidence; next step is CI and CodeRabbit review monitoring |
| 2026-06-11 01:40 | Validate Queue Item 42 locally | Focused dependency/metadata/freeze tests, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither comparison all pass; Slither remains `718` total findings with high/medium unchanged at `4/19` after explicitly initializing new test helper flags and narrowly suppressing a provenance timestamp false positive |
| 2026-06-11 01:21 | Implement Queue Item 42 local draft | Added immutable dependency registry versions, provenance/deprecation views, collection dependency pins, pinned dependency freeze manifests, focused tests, and docs/roadmap traceability; full validation remains to run |
| 2026-06-11 01:06 | Start Queue Item 42 | PR #84 merged and main is synced; the next missing Gate D metadata row is P1-META-003 dependency registry versioning, immutability, provenance, and collection dependency pinning |
| 2026-06-11 01:03 | Merge PR #84 | CI passed on final head `b48fbe9`, CodeRabbit reported no actionable comments after the burn/range follow-up, and issue #47 remains open for dependency, burn, and escaping work |
| 2026-06-11 00:59 | Validate CodeRabbit PR #84 second follow-up | Focused freeze tests, full `make check`, Windows wrapper, formatting, whitespace, and Slither comparison passed after guarding post-freeze burn and pre-mint hash range writes |
| 2026-06-11 00:57 | Address CodeRabbit PR #84 second follow-up | Guarded `burn()` after collection freeze to keep the manifest surface immutable, added pre-mint token-range validation to `setTokenHash`, and added focused regression coverage; full gate is rerunning before push |
| 2026-06-11 00:42 | Validate CodeRabbit PR #84 review fix | Focused freeze tests and `make check` pass after moving live-token aggregate tracking before `_safeMint`; Slither returned to the prior `718` total findings with high/medium unchanged at `4/19` |
| 2026-06-11 00:32 | Address CodeRabbit PR #84 review | Durable state now records open PR #84; freeze eligibility and manifest preview use tracked pending metadata counts plus a live-token metadata accumulator instead of full-range token scans; freeze tests now assert exact revert reasons and cover burned pending tokens |
| 2026-06-11 00:16 | Validate Queue Item 41 locally | Focused freeze tests, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither comparison all pass; Slither high/medium remain `4/19` after fixing the initial test-only unused-return row |
| 2026-06-11 00:12 | Keep the Queue Item 41 PR as a reference to issue #47, not a closure | Issue #47 includes dependency content immutability acceptance criteria; this PR implements the `StreamCore` freeze-manifest and current mutation-guard slice while leaving registry versioning/provenance to issue #48 |
| 2026-06-11 00:08 | Implement Queue Item 41 local draft | Added typed freeze manifest hashes, manifest/event/views, final-supply freeze boundary, terminal live-token metadata eligibility, current `StreamCore` post-freeze guards, focused freeze tests, and docs/roadmap traceability |
| 2026-06-11 00:02 | Start Queue Item 41 | PR #83 merged; the next missing Gate D metadata row is P1-META-002 collection freeze boundaries, and dependency versioning/burn/escaping remain separate issues |
| 2026-06-11 00:00 | Merge PR #83 | CI passed on final head `78664b0`, CodeRabbit verified the assertion-label cleanup with no concerns, the zero-hash thread was resolved, and the stale aggregate CodeRabbit status was documented before merge |
| 2026-06-10 23:55 | Accept CodeRabbit PR #83 assertion-label nit | Clarified the zero-hash regression failure message after CodeRabbit confirmed the guard and coverage were solid; focused metadata tests, `make check`, Windows wrapper, formatting, and whitespace checks all pass |
| 2026-06-10 23:48 | Address CodeRabbit PR #83 zero-hash finding | Added `setTokenHash` guard for `bytes32(0)`, added pending-sentinel regression coverage, and reran focused metadata tests, `make check`, Windows wrapper, formatting, whitespace, and Slither baseline comparison |
| 2026-06-10 23:30 | Open PR #83 | Schema-v1 metadata state outputs are published with local validation evidence; next step is state follow-up push and CodeRabbit request |
| 2026-06-10 23:28 | Validate Queue Item 40 locally | Focused metadata tests, full `make check`, Windows wrapper, formatting, whitespace, heading scan, traceability grep, and Slither comparison all pass; Slither high/medium remain unchanged |
| 2026-06-10 23:26 | Start Queue Item 40 | ADR 0006 sequencing calls for schema versioning and explicit metadata state after current-output golden files and before freeze/dependency/burn hardening |
| 2026-06-10 23:20 | Merge PR #82 | CI passed, CodeRabbit resolved the inline thread and approved the latest head, and the stale aggregate CodeRabbit status was documented before merge |
| 2026-06-10 23:15 | Address CodeRabbit PR #82 inline test gap | Hardened negative-path ERC-4906 tests to assert no raw metadata event topics, added post-burn hash-storage no-event coverage, and refreshed focused/full/Windows/Slither validation with 210 total tests |
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
| 2026-06-10 23:08 | Address CodeRabbit PR #82 coverage suggestions | Accepted CodeRabbit's low-risk suggestions from comment `4675512759`: added pre-mint `setTokenHash` no-event coverage, two-token image/attribute event coverage, and the `_exists` guard comment; focused tests, full `make check`, Windows wrapper, formatting, whitespace, and Slither baseline comparison all pass with 209 tests |
| 2026-06-12 06:27 | Address CodeRabbit PR #141 review | Recorded generated release-artifact files in scope, added deterministic token-hash evidence to the auction ceremony rehearsal, replaced gas-affected proceeds balance deltas with ledger-credit evidence, and reran focused rehearsal validation plus `make check` |
| 2026-06-12 06:35 | Merge PR #141 | CI run `27398853992` passed, CodeRabbit status was green, all CodeRabbit review threads were resolved by the bot, issue #140 closed completed, and the local branch fast-forwarded `main` to merge commit `1b3ad3df35fb6dedd65b2b227b1beb29feaa8b61` |
| 2026-06-12 06:37 | Create issue #142 and select Queue Item 74 | No open GitHub issues remained; the next Gate E gap is local emergency redeployment rehearsal because ADR 0007 still requires executable emergency redeployment evidence without secrets before broader fork/testnet/live ceremonies |
| 2026-06-12 06:52 | Implement Queue Item 74 local draft | Added local emergency redeployment rehearsal script/test/gate wiring, updated docs/roadmap/changelog/run-state, regenerated release manifest/checksum evidence, and passed focused Forge/script validation |
| 2026-06-12 07:07 | Finish local Queue Item 74 validation | Focused Forge tests and script rehearsal, release manifest/checksum/changelog drift checks, bash syntax checks, full `make check`, and Windows PowerShell wrapper validation pass locally; CI and CodeRabbit remain pending until PR creation |
| 2026-06-12 07:10 | Open PR #143 | Emergency redeployment rehearsal PR opened on head `cf8f5ec488294005ecf2c809018fee6d84f40c98` with issue #142 closure, local validation transcript, and fork/testnet/live emergency evidence explicitly scoped to later Gate E work |
| 2026-06-12 07:22 | Address CodeRabbit PR #143 review | Accepted CodeRabbit's request to make deployment-version uniqueness a direct script assertion, then reran focused Forge formatting, evidence test, and emergency redeployment script validation |
| 2026-06-12 07:28 | Finish PR #143 follow-up validation | Full `make check` passed after the CodeRabbit deployment-version guard fix; CI rerun and CodeRabbit re-review remain pending until the follow-up commit is pushed |
| 2026-06-12 15:12 | Mark PR #159 merge-ready | CI run `27424138673` passed on head `207ba0d00066ccab9a0414d8f8f848aa1c3e1c4a`, CodeRabbit status was success, and the visible CodeRabbit review suggestions were addressed in the follow-up commit |
| 2026-06-12 16:13 | Mark PR #161 merge-ready | Final CI run `27428125013` passed on head `95a70908b3470488dac8e142c427de28d022824a`, CodeRabbit status was success, and the visible review threads were resolved |
| 2026-06-13 09:55 | Merge PR #209 | Release evidence packet index merged as `dec345094e26304a50c5b5e098c002b002972c37`; CI run `27463241499` and CodeRabbit passed on final head `e571a2a2b4107c27f5c229e02d00dbe93c78381a`, and issue #207 closed completed |
| 2026-06-13 09:56 | Create issue #210 and select Queue Item 108 | Durable state still marked PR #209 active after merge, so reconcile roadmap/run-state evidence before choosing the next substantive no-secret roadmap target |
| 2026-06-13 09:59 | Finish Queue Item 108 local validation | Heading scan, state evidence grep, and whitespace checks pass for the roadmap/run-state reconciliation |
| 2026-06-13 10:00 | Open PR #211 and request CodeRabbit | State reconciliation PR opened on head `6a9ff2c3e2e4970c874b1dffd4a76a5b285d9457`; CodeRabbit requested in comment `4698194605` |
| 2026-06-13 10:12 | Merge PR #211 and select Queue Item 109 | PR #211 merged as `767dd61183b0b350c114f48aa034e08192a16c23` after CI run `27463609371` and CodeRabbit success; issue #210 closed completed and issue #212 opened for the release evidence issue backlog artifact |
| 2026-06-13 10:29 | Implement Queue Item 109 local draft | Added the release evidence issue-backlog generator/tests, local/CI gate wiring, release-manifest/checksum coverage, docs, changelog, roadmap, and durable state updates without creating issues automatically or changing readiness claims |
| 2026-06-13 10:39 | Finish Queue Item 109 local validation | Focused evidence, manifest, checksum, release-artifact, readiness, changelog, syntax, heading, and whitespace checks pass, and full `make check` passes with existing warning noise only |
| 2026-06-13 10:42 | Open PR #213 and request CodeRabbit | Release evidence issue backlog PR opened on head `c45d49c2cb31ceddf0d0657c532b09654b7c4207`; CodeRabbit requested in comment `4698282548` |
| 2026-06-13 10:55 | Address CodeRabbit PR #213 review | CI run `27464488143` passed on head `9f20c468eb2f8cce5a42d22080773945fc0cfe46`; CodeRabbit review `4491326886` requested typed packet-field validation, a missing nested-field regression, and tooling command-list parity |
| 2026-06-13 11:05 | Validate PR #213 review fix locally | Focused issue-backlog, manifest, checksum, release-artifact, readiness, changelog, syntax, heading, whitespace, and full `make check` validation pass with existing Foundry warning noise only |
| 2026-06-13 11:14 | Merge PR #213 | Release evidence issue backlog PR merged as `fc8df90cea2ac77fb8be88c3d2258a77693f374c` after final CI run `27465004282`, CodeRabbit success, and issue #212 closure |
| 2026-06-13 11:16 | Create issue #214 and child tracker issues | Opened parent issue #214, then created release-evidence tracker issues #215 through #231 from the generated issue backlog entries |
| 2026-06-13 11:32 | Start Queue Item 110 | Created branch `codex/release-evidence-issue-links` from PR #213 squash merge and began committing the deterministic issue-link map/checker for issue #214 |
| 2026-06-13 11:47 | Finish Queue Item 110 local validation | Focused issue-link, release-artifact, manifest, checksum, readiness, changelog, syntax, heading, whitespace, and full `make check` validation pass with existing Foundry warning noise only |
| 2026-06-13 11:51 | Open PR #232 and request CodeRabbit | Release evidence issue-link PR opened on head `b159a596923f16d33e6bdb8f59700a39ed9cd913`; CodeRabbit requested in comment `4698436262` |
| 2026-06-13 12:09 | Address CodeRabbit PR #232 review | CI run `27465990522` passed on head `7d959c5fdc49b79dd1bb1c2240f8ff86bfd71ff9`; CodeRabbit review `4491391500` requested IO/UTF-8 decode error wrapping, and the follow-up regression plus full `make check` validation pass locally |
| 2026-06-13 12:18 | Merge PR #232 and select Queue Item 111 | Release evidence issue links merged as `acfb94230ad596de6a4578f6b269cbc6fa8fd78d` after final CI run `27466388746`, CodeRabbit success, and issue #214 closure; issue #233 opened to reconcile durable state before continuing the child evidence tracker issues |
| 2026-06-13 12:23 | Open PR #234 | Release evidence issue-link state reconciliation PR opened on head `dff1c2d4aad9c3708cf19031a99840fe37bfa31e`; CodeRabbit review will be requested on the PR-state head |
| 2026-06-13 12:46 | Start Queue Item 112 | PR #234 merged as `1ac0765632f053c5a29c27375d04de8c9d75736b` after CI run `27466683865` and CodeRabbit success; issue #235 opened for deterministic release evidence issue-body sync artifacts and live tracker issue body updates |
| 2026-06-13 12:59 | Apply generated tracker issue bodies | Issues #215 through #231 now have exact generated no-secret body payloads from `release-artifacts/latest/release-evidence-issue-body-sync.json`; live GitHub bodies verified against the artifact |
| 2026-06-13 13:13 | Finish Queue Item 112 local validation | Focused release evidence body-sync, release-artifact, manifest, checksum, readiness, changelog, syntax, heading, whitespace, full `make check`, and Windows PowerShell wrapper validation all pass with existing Foundry warning noise only |
| 2026-06-13 13:16 | Open PR #236 and request CodeRabbit | Release evidence issue body-sync PR opened on head `f7dc33795e45129da62e3636448f781c4bcbe251`; CodeRabbit review requested in comment `4698628618` |
| 2026-06-13 13:31 | Address CodeRabbit PR #236 review locally | Foundry smoke run `27467859837` passed; CodeRabbit review `4491474201` requested two minor docs/roadmap wording fixes, which are prepared locally with regenerated release manifest/checksum artifacts and focused validation passing |
| 2026-06-13 13:38 | Merge PR #236 | Release evidence issue body sync merged as `1a825466d2333dc75e2fb8e2aeb11dc9b0dccc5a` after final CI run `27468161616`, CodeRabbit success, resolved review threads, and issue #235 closure |
| 2026-06-13 13:41 | Start Queue Item 113 | Issue #237 opened to reconcile PR #236 merge evidence and roadmap metadata; tracker issues #215 through #231 had `release` and `roadmap` labels re-applied to match committed `applied_labels` |
| 2026-06-13 13:44 | Open PR #238 | Release evidence body-sync state reconciliation PR opened on head `5d6002d78b75da03ae3ce45dbcfefecdcd4fa8b8`; CodeRabbit review will be requested after this PR-state follow-up commit |

## Resume Instructions

If this thread resumes after compaction:

1. Read `ops/AUTONOMOUS_RUN.md`.
2. Read `ops/ROADMAP.md`.
3. Run `git status --short`.
4. Continue the current PR worklog item.
5. If a PR is open, fetch PR comments/checks and resolve them before starting
   the next PR.
6. If no PR is open, continue the next item in `PR Queue`.
