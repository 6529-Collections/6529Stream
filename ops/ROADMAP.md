# 6529Stream Roadmap

This roadmap is the execution plan for turning 6529Stream into a
world-class open-source smart-contract repository for 6529 NFT drops.

It is intentionally structured as a gated launch plan, not a loose backlog. The
repo is currently useful as a protocol draft and audit baseline, but it is not
production-ready. Work should move through decisions, characterization tests,
implementation, verification, deployment rehearsal, and release gates in that
order.

## 0. Current Status

### Maturity Statement

- Maturity: pre-audit and not production-ready.
- Current CI proves that the repo compiles and runs the initial
  characterization test skeleton. It does not prove protocol correctness.
- Known remaining P0 blockers include broader payment accounting and
  cross-contract invariants, fuller randomizer reserve lifecycle accounting,
  metadata state work, remaining static analysis findings, missing invariants,
  broader production governance, and incomplete deployment discipline.
  Drop authorization now uses EIP-712 with EOA and ERC-1271 support; auction
  custody, settlement state, outbid refunds, auction-local settlement credits,
  fixed-price `StreamDrops` pull credits, and `StreamCuratorsPool` curator
  reward credits now have target-state
  implementation coverage. `StreamMinter` and `NextGenRandomizerRNG`
  emergency-withdrawal boundaries now have target-state coverage for their
  current custody models, P0-ADMIN-001 target-scoped function-admin checks
  cover the current protected-function surface, and P0-ADMIN-002
  domain-scoped pause/emergency-recipient controls now have target-state
  coverage. P0-ADMIN-003 signer-manager controls now separate drop-signing
  identities from signer-lifecycle authority. P0-RAND-001 through P0-RAND-007
  randomizer lifecycle, callback, migration, failed-state, retry, and
  raw-output-hash work now have target-state coverage for VRF and arRNG
  adapters, and P0-RAND-008 removed the concrete `XRandoms` weak helper from
  production source. P0-INIT-001 fixed the remaining first-party production
  `uninitialized-local` rows. P0-META-001 dependency script segment-safe
  encoding now has typed chunk/content hash coverage, and P0-CORE-001 removed
  dead always-zero public/allowlist mint-accounting state. P1-META-004
  `StreamCore` ERC-4906 metadata update signaling now has implementation and
  target-state test coverage. Gate E now has a first local deployment rehearsal
  script, manifest schema, generated Anvil manifest example, manifest drift
  check, manifest parsing test, sanitized Foundry broadcast fixture ingestion,
  generated local and broadcast-derived address books, generated source
  verification input bundle, generated release manifest, and release checksum
  bundle, while live fork/testnet rehearsals, production broadcast retention,
  and live artifact verification remain open.
- Public docs must describe actual on-chain behavior, not intended product
  behavior.

### Verification Metadata

| Field | Value |
| --- | --- |
| Last verified | `2026-06-11 14:06 UTC` local broadcast-manifest ingestion PR candidate validation; CI TBD |
| OS tested | Windows / Linux |
| Foundry version | `v1.7.1` |
| Solidity compiler version | `0.8.19` |
| Slither version | `0.11.5` |
| CI run | TBD |
| Command transcript location | `ops/SLITHER_BASELINE.md` for Slither baseline; other transcripts TBD |

### Machine-Verifiable Baseline

| Area | Current status | Evidence | Required before public beta |
| --- | --- | --- | --- |
| Build | Passes with warnings when `forge` is invoked through the installed binary path | `forge build` | Build passes in CI and locally with warnings burned down or documented |
| Unit/integration tests | Tests cover admin guards, target-scoped function-admin permission regressions, domain-scoped pause controls, EIP-712/ERC-1271 drop authorization, auction custody and payment credits, fixed-price pull-payment credits, curator reward credits, current emergency-withdrawal boundaries, randomizer lifecycle/callback validation, randomness/pending metadata behavior, ERC-4906 metadata update signaling, raw-output hash storage, dependency-script encoding hashes, explicit local-initialization regressions, vendored utility-library regressions, and retained airdrop mint-accounting behavior; broader P0/P1 tests are missing | `forge test -vvv` | P0 regression and integration suite exists |
| Production size | Production deployable contracts pass the IR-optimized size gate; `StreamCore` is 24,461 runtime bytes with 115 bytes of EIP-170 headroom | `forge build --sizes --via-ir --skip test --skip script --force` | Production size gate passes in CI and deployment scripts use the same profile |
| Formatting | Fails broadly | `forge fmt --check smart-contracts` | Passing, or vendored exclusions documented |
| Static analysis | Runs with a tracked high/medium baseline: 717 total findings, including 4 High, 19 Medium, and 93 Low; current high/medium rows are fixed, accepted, or documented false positives | `slither . --config-file slither.config.json --foundry-compile-all`, `ops/SLITHER_BASELINE.md`, and `docs/vendored-libraries.md` | High/medium findings fixed, accepted, or documented |
| Deployment | Partial local baseline: deploy-and-wire rehearsal script, manifest schema, address-book schema, generated Anvil manifest config/example, sanitized Foundry broadcast fixture ingestion, generated Anvil and broadcast-derived address books, manifest parsing test, and generated ABI/bytecode checksum inputs exist; live fork/testnet rehearsal and production broadcast retention remain missing | `forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir`, `test/StreamDeploymentManifest.t.sol`, `scripts/generate_broadcast_manifest_input.py --check`, `scripts/generate_deployment_manifest.py --check`, `scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check`, `scripts/generate_address_books.py --check`, `deployments/broadcasts/`, `deployments/schema/deployment-manifest.schema.json`, `deployments/schema/address-book.schema.json`, `deployments/address-books/`, and `release-artifacts/latest/abi-checksums.json` | Anvil deployment and fork rehearsal pass |
| Docs | Partial README and roadmap only | manual inspection | Architecture, security, deployment, and protocol docs merged |
| Release artifacts | Partial deterministic baseline: ABI checksums, bytecode checksums, interface IDs, event topic catalog, source verification inputs, ABI compatibility baseline, sanitized broadcast fixture ingestion, local and broadcast-derived deployment manifest checksums, local and broadcast-derived address books, machine-readable release manifest, signable release checksum bundle, release change approval policy, and changelog gate are generated or documented from committed inputs; detached signatures, signed release tags, production address books, live explorer verification, and verified live addresses remain missing | `python scripts/generate_release_artifacts.py --check`, `python scripts/generate_source_verification_inputs.py --check`, `python scripts/check_abi_compatibility.py --check`, `python scripts/generate_broadcast_manifest_input.py --check`, `python scripts/generate_deployment_manifest.py --check`, `python scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check`, `python scripts/generate_address_books.py --check`, `python scripts/generate_release_manifest.py --check`, `python scripts/generate_release_checksums.py --check`, `python scripts/check_changelog.py`, `release-artifacts/latest/`, `release-artifacts/latest/source-verification-inputs.json`, `release-artifacts/latest/release-manifest.json`, `release-artifacts/baselines/v0.1.0/abi-surface.json`, `deployments/broadcasts/`, `deployments/schema/address-book.schema.json`, `deployments/examples/anvil-6529stream-v0.1.0-001.json`, `deployments/examples/anvil-6529stream-v0.1.0-001-broadcast.json`, `deployments/address-books/anvil-6529stream-v0.1.0-001.json`, `deployments/address-books/anvil-6529stream-v0.1.0-001-broadcast.json`, `CHANGELOG.md`, and `docs/release-policy.md` | ABIs, manifests, source verification inputs, checksums, and verified addresses published |
| Windows setup | Foundry installed under `~/.foundry/bin`, but current shell may not resolve `forge` from `PATH` | direct binary invocation | Bootstrap works in current and future shells, or limitation documented |

## 1. Launch Gates

Each gate must be satisfied before moving to the next launch phase. If a gate is
intentionally bypassed, the bypass must be documented with owner, reason,
expiry, and risk.

For production drops or public security claims, Gate B1, Gate C, and Gate E may
not be bypassed. Any exception requires explicit maintainer, security owner, and
protocol owner signoff.

This roadmap distinguishes release modes:

- Public repository publication may happen earlier if maturity warnings are
  prominent and the repo is clearly marked experimental/pre-audit.
- Production drop launch requires Gates A through F complete.
- Audited release requires external audit completion or an explicit public
  rationale for audit waiver.

### Gate A: Reproducible Baseline

Status: In Progress.
Owner: TBD.
Blocking issues: TBD.
Evidence: TBD.

Exit criteria:

- Fresh Linux checkout can run build, test, format-check, and Slither commands.
- Fresh Windows checkout can run equivalent commands or has a documented
  best-effort limitation.
- CI publishes build and test logs.
- `test/`, `script/`, `docs/`, and remapping/dependency structure exist.
- Generated artifacts are ignored by default.
- README states the repo is not production-ready.
- Initial and converted target-state tests cover fixed-price drop execution,
  auction creation, admin guard, payout/accounting, and randomness behavior
  enough to detect accidental regressions.

Required evidence:

- Passing CI link.
- Command transcript for local Linux and Windows smoke checks.
- Characterization test file list.
- `.gitignore`/generated-artifact policy.

### Gate B1: P0 Protocol Decisions Accepted

Status: In Progress.
Owner: TBD.
Blocking issues: TBD.
Evidence: TBD.

Exit criteria:

- Drop authorization ADR accepted.
- Auction custody ADR accepted.
- Payment accounting ADR accepted.
- Admin/governance ADR accepted.
- Randomness ADR accepted.

Required evidence:

- ADR files under `docs/adr/`.
- Reviewer signoff from protocol and security owners.
- Open questions explicitly tracked as blockers or accepted non-goals.

### Gate B2: Release Protocol Decisions Accepted

Status: Complete.
Owner: TBD.
Blocking issues: [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45),
[`P2-UPGRADE-ADR`](https://github.com/6529-Collections/6529Stream/issues/53).
Evidence: `docs/adr/0006-metadata-freeze.md` and
`docs/adr/0007-upgrade-redeployment.md` accepted.

Exit criteria:

- Metadata/freeze ADR accepted.
- Upgrade/redeployment ADR accepted.

Required evidence:

- ADR files under `docs/adr/`.
- Reviewer signoff from protocol and security owners.
- Open questions explicitly tracked as blockers or accepted non-goals.

### Gate C: P0 Implementation Complete

Status: In Progress.
Owner: TBD.
Blocking issues: TBD.
Evidence: TBD.

Exit criteria:

- `tx.origin` removed from drop execution.
- Drop authorization uses EIP-712 typed structured data.
- Replay protection implemented in contract storage.
- ERC-1271 support implemented or explicitly out of scope.
- Auction custody is explicit and tested.
- Auction refunds use pull-payment credits.
- Admin selector mismatch fixed and permission matrix tested.
- Randomizer callbacks validate request, token, collection, and randomizer epoch.
- Slither high/medium baseline fixed, accepted, or documented.
- P0 regression tests pass in CI.

Required evidence:

- P0 issue checklist complete.
- Test traceability matrix updated.
- CI link.
- Updated architecture/security docs.

### Gate D: Test And Invariant Baseline Complete

Status: In Progress.
Owner: TBD.
Blocking issues: TBD.
Evidence: Payment sequence fuzz invariant baseline added in
`test/StreamPaymentsInvariant.t.sol`; metadata golden and ERC-4906 event
baselines added in `test/StreamMetadataGolden.t.sol` and
`test/StreamMetadataEvents.t.sol`; supply, replay, freeze, gas, and deployment
rehearsal baselines remain open.

Exit criteria:

- Unit, integration, negative, adversarial, and regression tests cover all P0
  findings.
- Foundry invariant tests cover supply, payments, auction consistency, replay,
  and frozen metadata.
- Metadata golden-file tests cover pending, fulfilled, escaped, and frozen
  outputs.
- Gas snapshot baseline exists for mint, bid, settlement, curator claim,
  `tokenURI`, and dependency/script reads.

Required evidence:

- Coverage report after meaningful tests exist.
- Gas report.
- Test traceability appendix.
- CI link.

### Gate E: Deployment Rehearsal Complete

Status: In Progress.
Owner: TBD.
Blocking issues: [`P1-DEPLOY-002`](https://github.com/6529-Collections/6529Stream/issues/91),
[`P1-DEPLOY-003`](https://github.com/6529-Collections/6529Stream/issues/95),
[`P1-DEPLOY-004`](https://github.com/6529-Collections/6529Stream/issues/109).
Evidence: local deployment rehearsal script, manifest schema, generated Anvil
manifest config/example, sanitized broadcast fixture ingestion,
broadcast-derived manifest config/example, generated address books, manifest
parsing/wiring test, manifest drift check, `make check`, and Windows wrapper
pass; CI evidence TBD.

Exit criteria:

- Foundry deployment scripts exist.
- Anvil deployment rehearsal passes.
- Fork deployment dry run passes.
- Local deployment manifest and sanitized broadcast-derived manifest are
  generated; live fork/testnet manifests are generated before public beta.
- Post-deploy admin, signer, randomizer, dependency, curator, and auction wiring
  verified.
- Contract verification inputs retained.

Required evidence:

- Deployment command transcript.
- Generated manifest and broadcast evidence.
- Post-deploy checklist.
- Verification artifact references.

### Gate F: External Audit Package Ready

Status: Not Started.
Owner: TBD.
Blocking issues: TBD.
Evidence: TBD.

Exit criteria:

- Architecture docs complete.
- Threat model complete.
- Protocol invariants documented.
- Static-analysis baseline complete.
- Test coverage and gas reports attached.
- Deployment assumptions documented.
- Known accepted risks separated from unresolved blockers.

Required evidence:

- Audit package index.
- Slither appendix.
- Test matrix.
- ADR index.
- Security docs.

### Gate G: Open-Source Release Ready

Status: Not Started.
Owner: TBD.
Blocking issues: TBD.
Evidence: TBD.

Exit criteria:

- `SECURITY.md`, `CONTRIBUTING.md`, CODEOWNERS, issue templates, PR template,
  changelog, and release policy exist.
- Release checklist complete.
- ABIs, address books, deployment manifests, broadcast-derived deployment
  evidence, source verification inputs, checksums, and verified contract
  addresses are published.
- Integration examples and event catalog exist.
- Docs links and commands are verified.

Required evidence:

- Release tag.
- Signed/checksummed artifacts.
- Public docs.
- CI link.

## 1.1 Milestone Map

| Milestone | Gate | Purpose | Exit evidence |
| --- | --- | --- | --- |
| M0 Reproducible Baseline | Gate A | Make repo reproducible and honest | CI logs, local transcripts, characterization tests |
| M1A Protocol Decisions | Gate B1 | Accept P0 ADRs before unsafe implementation | ADRs, reviewer signoff |
| M1B Core Safety Implementation | Gate C | Fix P0 blockers | P0 issue checklist, regression tests |
| M2 Verification Baseline | Gate D | Add invariants, gas, coverage, and golden tests | Test matrix, gas report |
| M3 Deployment Rehearsal | Gate E | Prove deployment ceremony | Manifests, post-deploy checklist |
| M4 Audit Package | Gate F | Prepare external audit | Audit package index |
| M5 Open-Source Release | Gate G | Publish release artifacts and docs | Release tag, checksums, public docs |

### Milestone 1A: Core Protocol Decisions

This milestone maps to Gate B1. It must complete before engineers implement the
main P0 rewrites.

Exit criteria:

- Drop authorization ADR accepted.
- Auction custody ADR accepted.
- Payment accounting ADR accepted.
- Admin/governance ADR accepted.
- Randomness ADR accepted.

### Milestone 1B: Core Safety Implementation

This milestone maps to Gate C. It starts only after Milestone 1A is accepted.

Exit criteria:

- `tx.origin` removed from drop execution.
- Drop authorization uses EIP-712 typed structured data.
- Replay protection is implemented in contract storage.
- ERC-1271 support implemented or explicitly out of scope.
- Auction custody is explicit and tested.
- Auction refunds use pull-payment credits.
- Admin selector mismatch fixed and permission matrix tested.
- Randomizer callbacks validate request, token, collection, and randomizer epoch.
- P0 regression tests pass in CI.

## 2. Priority, Severity, And Work Type

Priority, severity, and work type are separate labels.

### Priority

- `P0`: Blocks production or public security claims.
- `P1`: Blocks audit, public beta, or integration partner work.
- `P2`: Blocks open-source maturity or repeatable operations.
- `P3`: Long-term quality and scale.

### Severity

- `Critical`: Direct loss of funds or NFTs.
- `High`: Blocked mint/settlement, privilege escalation, replay, custody failure,
  or user-owed fund loss.
- `Medium`: Degraded metadata, randomness, rewards, indexing, or integration
  behavior.
- `Low`: Docs, tooling, maintainability, or non-critical process issues.

### Work Type

- `DESIGN`: Requires ADR or design acceptance before code changes.
- `CODE`: Contract or script implementation.
- `TEST`: Harness, regression, fuzz, invariant, fork, or gas tests.
- `DOCS`: README, protocol docs, NatSpec, runbooks, or audit docs.
- `OPS`: Deployment, monitoring, release, incident response, or tooling.

Issue labels should combine these dimensions, for example:

```md
P0 / High / CODE+TEST+DOCS / Blocks: Gate C / Depends: Gate B1 ADR
```

## 3. Protocol Decisions Required Before Implementation

These decisions block unsafe P0 implementation. Do not implement the associated
contract changes until the relevant ADR is accepted.

| ADR | Issue | File target | Blocks | Required decision |
| --- | --- | --- | --- | --- |
| Drop authorization | [`P0-AUTH-ADR`](https://github.com/6529-Collections/6529Stream/issues/17) | `docs/adr/0001-drop-authorization.md` | Gate B1, `P0-AUTH-*` | EIP-712 schema, recipient/payer policy, nonce model, replay protection, signer rotation, ERC-1271 stance |
| Auction custody | [`P0-AUCT-ADR`](https://github.com/6529-Collections/6529Stream/issues/21) | `docs/adr/0002-auction-custody.md` | Gate B1, `P0-AUCT-*` | Token custody, settlement actor, no-bid semantics, transfer method, cancellation |
| Payment accounting | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24) | `docs/adr/0003-payment-accounting.md` | Gate B1, `P0-PAY-*` | Pull credits, owed balances, surplus, withdrawals, emergency withdrawal limits |
| Admin/governance | [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33) | `docs/adr/0004-admin-governance.md` | Gate B1, `P0-ADMIN-*` | Global/function/collection roles, signer lifecycle, pause controls, multisig expectations |
| Randomness | [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14) | `docs/adr/0005-randomness.md` | Gate B1, `P0-RAND-*` | Provider choice, pending state, callback validation, retries, stale callback handling |
| Metadata/freeze | [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45) | `docs/adr/0006-metadata-freeze.md` | Gate B2, [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9), `P1-META-*` | Pending/final metadata, frozen state, dependency immutability, burn metadata, ERC-4906 event policy |
| Upgrade/redeployment | [`P2-UPGRADE-ADR`](https://github.com/6529-Collections/6529Stream/issues/53) | `docs/adr/0007-upgrade-redeployment.md` | Gate B2, deployment/release | Redeploy vs upgrade stance, migration expectations, versioning |

Each ADR must include problem, current behavior, intended behavior, alternatives,
security impact, migration impact, test plan, rollout plan, non-goals, and
accepted risks.

## 4. First Implementation Queue

This is the recommended first batch of issues.

1. `P0/M0`: Add repo status and maturity warning to README.
2. `P0/M0`: Make local and CI baseline reproducible.
3. `P0/M0`: Add `test/`, `script/`, `docs/`, and remappings skeleton.
4. `P0/M0`: Add characterization test harness.
5. `P0/M0`: Add Slither baseline table.
6. `P0-AUTH-ADR / P0/DESIGN`: ADR for drop authorization.
7. [`P0-AUCT-ADR`](https://github.com/6529-Collections/6529Stream/issues/21) / P0/DESIGN: ADR for auction custody.
8. [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24) / P0/DESIGN: ADR for payment accounting.
9. [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33) / P0/DESIGN: ADR for admin/governance.
10. [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14) / P0/DESIGN: ADR for randomness.
11. [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45) / P1/DESIGN: ADR for metadata/freeze.
12. [`P2-UPGRADE-ADR`](https://github.com/6529-Collections/6529Stream/issues/53) / P2/DESIGN: ADR for upgrade/redeployment.
13. [`P0-AUTH-001`](https://github.com/6529-Collections/6529Stream/issues/18) / P0/CODE+TEST+DOCS: Remove `tx.origin`.
14. [`P0-AUTH-002`](https://github.com/6529-Collections/6529Stream/issues/10) / P0/CODE+TEST+DOCS: Implement EIP-712 authorization.
15. [`P0-AUTH-003`](https://github.com/6529-Collections/6529Stream/issues/19) / P0/CODE+TEST+DOCS: Add ERC-1271 support.
16. [`P0-AUCT-002`](https://github.com/6529-Collections/6529Stream/issues/12) / P0/CODE+TEST+DOCS: Refactor auction bidding to pull credits.
17. [`P0-AUCT-001`](https://github.com/6529-Collections/6529Stream/issues/22) / P0/CODE+TEST+DOCS: Formalize auction custody and settlement.
18. [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34) / P0/CODE+TEST+DOCS: Fix admin selector mismatch.
19. [`P0-ADMIN-002`](https://github.com/6529-Collections/6529Stream/issues/35) / P0/CODE+TEST+DOCS+OPS: Define pause and emergency controls.
20. [`P0-ADMIN-003`](https://github.com/6529-Collections/6529Stream/issues/79) / P0/CODE+TEST+DOCS: Implement signer lifecycle manager.
21. [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37) / P0/CODE+TEST+DOCS: Harden randomizer callbacks.
22. `P1/TEST`: Add first invariant suite.
23. `P1/DOCS`: Add protocol spec and threat model.
24. [`P1-DEPLOY-002`](https://github.com/6529-Collections/6529Stream/issues/91) / P1/OPS+TEST+DOCS: Add deployment scripts, manifest schema, and local rehearsal gate.
25. [`P1-RELEASE-001`](https://github.com/6529-Collections/6529Stream/issues/93) / P1/OPS+TEST+DOCS: Generate ABI checksums, bytecode checksums, interface IDs, and event topic catalog.
26. [`P1-DEPLOY-003`](https://github.com/6529-Collections/6529Stream/issues/95) / P1/OPS+TEST+DOCS: Generate and check deployment manifests from committed inputs.
27. [`P1-RELEASE-002`](https://github.com/6529-Collections/6529Stream/issues/97) / P1/OPS+TEST+DOCS: Add ABI compatibility diff checks against a committed baseline.
28. [`P1-RELEASE-003`](https://github.com/6529-Collections/6529Stream/issues/99) / P1/OPS+TEST+DOCS: Generate deployment address books from committed manifests.
29. [`P1-RELEASE-004`](https://github.com/6529-Collections/6529Stream/issues/101) / P1/OPS+TEST+DOCS: Generate a signable release checksum bundle from committed release and deployment artifacts.
30. [`P1-RELEASE-005`](https://github.com/6529-Collections/6529Stream/issues/103) / P1/OPS+TEST+DOCS: Add release change approval policy and changelog gate.
31. [`P1-RELEASE-006`](https://github.com/6529-Collections/6529Stream/issues/105) / P1/OPS+TEST+DOCS: Generate a machine-readable release manifest tying release artifacts, deployment artifacts, governance docs, and release-ceremony status together.
32. [`P1-RELEASE-007`](https://github.com/6529-Collections/6529Stream/issues/107) / P1/OPS+TEST+DOCS: Generate source verification inputs from production Foundry artifacts, source files, compiler settings, and contract config.
33. [`P1-DEPLOY-004`](https://github.com/6529-Collections/6529Stream/issues/109) / P1/OPS+TEST+DOCS: Ingest sanitized Foundry broadcast output into deterministic deployment-manifest evidence.

## 5. Best-Practice Checklist

This checklist is the repository-wide quality bar. Detailed tickets appear in
later sections.

### Standards-First NFT Behavior

- Maintain strict ERC-721 compatibility.
- Use ERC-2981 royalties if royalties are part of the product.
- Document that ERC-2981 exposes royalty information; it does not enforce
  marketplace payment.
- Test `royaltyInfo()` for default, token-specific, zero-sale-price, and changed
  receiver/fee cases.
- Emit ERC-4906 metadata update events if token or collection metadata can
  change.
- If ERC-4906 is implemented, test `supportsInterface(0x49064906)`.
- Emit `MetadataUpdate` / `BatchMetadataUpdate` only when JSON metadata changes,
  not merely on mint or burn unless intentionally documented.
- Define ABI and interface stability expectations.
- Maintain a changelog for external API, interface, event, and deployment
  changes.

### Typed, Replay-Safe Authorization

- Use EIP-712 for drop authorization.
- Treat EIP-712 as the encoding/signing standard, not the complete
  replay-protection mechanism.
- Bind signer, poster, recipient, collection, token data hash, price, deadline,
  nonce/drop ID, chain ID, verifying contract, domain version, and signer epoch
  in signed data or contract state.
- Implement replay protection with consumed nonces/drop IDs, deadline, chain ID,
  verifying contract, domain version, and signer-rotation rules.
- Support ERC-1271 signature validation for contract signers where signed
  authorization may come from a Safe, DAO, or smart wallet, or explicitly mark
  contract signers out of scope.
- Test both EOA signatures and ERC-1271 contract signatures when supported.
- Avoid `tx.origin`.
- Avoid ad hoc string signing.
- Avoid `abi.encodePacked` with multiple dynamic fields.

### Money Safety By Default

- Prefer pull payments over push payments.
- Use checks-effects-interactions for value-moving flows.
- Add reentrancy tests in addition to any `nonReentrant` modifiers.
- Separate protocol surplus from user-owed balances.
- Make payout split rounding explicit.
- Make emergency-withdrawable funds explicit and bounded by total owed.

### Production-Grade Randomness

- Treat block-based randomness as demo/test only.
- For Chainlink VRF, track `requestId` through fulfillment.
- Choose and document confirmation counts by network and value at risk.
- Handle pending randomness states explicitly.
- Avoid re-request or cancellation patterns that can bias outcomes.
- Do not allow user-significant inputs after randomness is requested.
- Ensure fulfillment callbacks do not revert in normal operation.

### Complete Lifecycle Tests

- Test fixed-price mint.
- Test auction mint, bid, outbid, extension, settlement, and no-bid settlement.
- Test contract wallet and ERC721 receiver callback behavior.
- Test metadata pending, final, updated, and frozen states.
- Test curator reward claims and delegation edge cases.
- Add invariant tests for supply, payments, auctions, drops, randomness, and
  frozen metadata.

### Open-Source Quality

- Ensure setup is reproducible from a fresh checkout.
- Run CI for build, tests, formatting, static analysis, coverage, and gas
  snapshots.
- Add `SECURITY.md`, `CONTRIBUTING.md`, CODEOWNERS, issue templates, and a pull
  request template.
- Document license and provenance for vendored code.
- Publish release artifacts including ABIs, deployment manifests, checksums, and
  verified contract addresses.

### Operational Maturity

- Add deployment scripts and post-deployment checklists.
- Add runbooks for stuck auctions, failed randomness, bad Merkle roots, bad
  metadata, failed payouts, and signer compromise.
- Monitor admin changes, pending randomness, pending auctions, curator pool
  balances, and failed claims.
- Document the trust model and accepted risks publicly.

## 6. P0 Launch Blockers

Each P0 item is written as an issue-ready task. Implementation should not begin
until listed dependencies are satisfied.

### P0-AUTH-001: Remove `tx.origin` From Drop Execution

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Dependencies: `P0-AUTH-ADR`.

Problem:

- Fixed-price and auction flows use `tx.origin` for recipient/execution address.
  This breaks contract wallets, relayers, multisigs, and account-abstraction
  wallets.

Previous behavior:

- `StreamDrops` assigns fixed-price receiver and execution address from
  `tx.origin`.

Intended behavior:

- The intended recipient/execution address is explicit, validated, and stored.
- `msg.sender` may be payer/relayer only according to the ADR policy.
- Full signed-field validation remains owned by `P0-AUTH-002`.

Required code changes:

- Remove all `tx.origin` uses.
- Add explicit recipient/execution fields according to the ADR.
- Validate zero addresses and role/payer semantics.

Required tests:

- EOA execution.
- Contract wallet execution.
- Relayer execution if supported.
- Recipient different from payer if supported.
- Zero recipient rejection.
- Wrong recipient signature failure, once `P0-AUTH-002` adds EIP-712
  validation.

Required docs:

- `docs/drop-authorization.md`.
- README maturity/status update if behavior changes before full fix.

Acceptance criteria:

- No `tx.origin` remains in protocol source.
- Contract wallet execution test passes.
- `P0-AUTH-001` interim legacy drop IDs included the explicit recipient; packed
  IDs are replaced by `P0-AUTH-002`.
- External docs describe payer, signer, poster, recipient, execution address, and
  settlement recipient semantics.

### P0-AUTH-002: Replace Drop Authorization With EIP-712

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Dependencies: `P0-AUTH-ADR`.
- Status: EOA and EIP-2098 typed authorization implemented in
  `smart-contracts/StreamDrops.sol`; ERC-1271 contract signer support is
  implemented separately by `P0-AUTH-003`.

Problem:

- Previous drop IDs were built with string concatenation and `abi.encodePacked`.
  Authorization needed a robust typed domain, nonce/deadline model, and
  storage-backed replay protection.

Current behavior:

- Drop authorization now accepts `DropAuthorization` EIP-712 typed data,
  validates the configured signer, consumes the derived `dropId`, and keeps EOA
  and contract signer validation split between `P0-AUTH-002` and
  `P0-AUTH-003`.

Intended behavior:

- Drop signatures use EIP-712 typed structured data.
- Replay protection is implemented by contract storage, not assumed from EIP-712.

Required code changes:

- Add EIP-712 domain with `name`, `version`, `chainId`, and `verifyingContract`.
- Add signed struct fields for poster, payer policy, recipient, collection ID,
  drop mode, token data hash, price, auction fields, nonce/drop ID, deadline,
  salt, and signer epoch if used.
- Store consumed nonces or drop IDs.
- Reject expired, wrong-domain, wrong-contract, wrong-chain, wrong-signer, and
  replayed signatures.
- Enforce signature malleability policy: low `s`, valid `v`, and zero-address
  recovered signer rejection.
- Support EIP-2098 compact signatures under the same malleability policy.
- Define front-running semantics: a third party may submit a signed drop only if
  recipient, price, token data, settlement recipient, and signed execution
  constraints cannot be redirected.
- Remove `retrieveMessageAndDropID` and the old packed-hash `mintDrop` surface.

Child tickets:

- `P0-AUTH-002A`: Define and implement EIP-712 domain and typed schema.
- `P0-AUTH-002B`: Add nonce/drop ID consumed-state storage.
- `P0-AUTH-002C`: Add deadline, domain, chain, contract, signer, and field
  substitution checks.
- `P0-AUTH-002D`: Add malleability policy and EIP-2098 support/reject policy.
- `P0-AUTH-002E`: Add replay and front-running regression tests.

Required tests:

- EOA signature passes.
- EIP-712 digest matches the explicit typed-data domain and struct encoding.
- Replay on same contract fails.
- Replay across chain ID/domain/verifying contract fails.
- Expired signature fails.
- Wrong signer fails.
- Wrong field substitution fails.
- Malleable signature fails.
- EIP-2098 compact signature behavior matches ADR.
- Third-party submission cannot redirect recipient, price, token data, or
  settlement recipient.
- Zero-address recovered signer fails.
- Signer rotation behavior is tested.
- Free fixed-price drops reject non-zero payer.
- Fixed-price drops reject non-zero auction reserve and auction end fields.
- Auction drops reject non-zero payer and fixed-price value fields.
- Consumption, cancellation, and signer-epoch events are asserted.
- Duplicate cancellation is rejected before emitting a second cancellation event.
- Contract signer path is covered by `P0-AUTH-003`.

Required docs:

- EIP-712 schema.
- Nonce/drop ID policy.
- Signer rotation policy.
- Example payload fixtures.
- ERC-1271 contract signer behavior.

Acceptance criteria:

- EIP-712 domain includes name, version, chain ID, and verifying contract.
- Replay protection is backed by consumed-state storage.
- EOA signatures pass.
- EIP-2098 compact signatures pass.
- Wrong signer, wrong domain, wrong chain, wrong verifying contract, expired,
  replayed, cancelled, stale-epoch, malleable, bad-quantity, bad-payer, and
  zero-recovered-signer authorizations fail.
- Sale-mode-specific field misuse fails before a drop is consumed.
- Drop consumption, cancellation, and signer-epoch events include the expected
  indexed identifiers and data.
- Duplicate cancellation fails without a second cancellation event.
- Token data substitution fails.
- Contract signer validation is handled by `P0-AUTH-003`.
- Legacy packed authorization helper and old `mintDrop` ABI are removed.
- All required negative tests pass.

### P0-AUTH-003: Decide And Implement ERC-1271 Support

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Dependencies: `P0-AUTH-ADR`.
- Status: Implemented in `smart-contracts/StreamDrops.sol` with target-state
  tests in `test/StreamDropsERC1271.t.sol`.

Problem:

- The roadmap requires contract wallet execution, but contract wallet signing is
  a separate decision. Safe/DAO/smart-wallet signers need ERC-1271 validation.

Current behavior:

- Contract signers validate the same EIP-712 drop authorization digest by
  returning the ERC-1271 magic value from `isValidSignature(bytes32,bytes)`.
  Non-ERC-1271 contracts and invalid ERC-1271 responses fail closed.

Intended behavior:

- Contract signers work via ERC-1271 for the first release, while EOA
  signatures continue to use the low-`s`, valid-`v`, and zero-recovered-signer
  ECDSA policy from `P0-AUTH-002`.

Required code changes:

- Call `isValidSignature(hash, signature)` by `staticcall` when the configured
  signer is a contract.
- Require the standard ERC-1271 magic value `0x1626ba7e`.
- Fail closed on reverted calls, empty returns, short or extra return data,
  invalid magic values, wrong digest, and wrong signature bytes.
- Preserve the existing EOA recovery path for EOA signers.

Required tests:

- ERC-1271 mock signer success.
- ERC-1271 auction path success.
- ERC-1271 invalid magic value failure.
- Reverted ERC-1271 signature check failure.
- Empty, short, and extra ERC-1271 return failures.
- Wrong digest and wrong signature-byte failures.
- Replayed and expired ERC-1271 authorization failures.
- Contract signer without ERC-1271 implementation fails closed.
- EOA signing remains unaffected.

Required docs:

- Contract signer policy.
- Safe/DAO signing example before public beta.

Acceptance criteria:

- ERC-1271 signatures pass only when the contract signer returns the standard
  magic value for the exact EIP-712 digest and signature bytes.
- Invalid, reverted, empty-return, malformed-return, replayed, and expired
  contract-signer paths fail without consuming the drop.
- Behavior is tested and documented.

### P0-AUCT-001: Formalize Auction Custody And State Machine

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [#22](https://github.com/6529-Collections/6529Stream/issues/22).
- Dependencies: [`P0-AUCT-ADR`](https://github.com/6529-Collections/6529Stream/issues/21), ADR 0002.
- Status: Implemented for ADR 0002 auction custody and settlement
  state-machine semantics. Broader protocol-wide payment accounting, pause
  controls, deployment readiness, fuller randomizer reserve lifecycle
  accounting, and full ADR 0003 completion remain separate roadmap work.

Problem:

- Auction settlement can fail if the auction contract lacks custody or approval
  for the token.

Historical behavior before P0-AUCT-001:

- Auction minting and settlement imply token transfer authority that is not
  guaranteed end to end.

Current behavior after P0-AUCT-001:

- Auction drops mint NFT custody to the configured auction contract and register
  an explicit auction record.
- `StreamAuctions` exposes auction status, custody, end-time, and pending
  no-bid claim views.
- Bid and no-bid settlement transfer from auction escrow and store terminal
  state before repeated attempts can duplicate side effects.
- No-bid EOA poster settlement transfers directly; no-bid contract poster
  settlement records a pending NFT claim for poster-controlled completion.
- With-bid settlement atomically creates poster, protocol, and curator pull
  credits with the highest-bidder NFT transfer; a failed transfer reverts the
  credits and terminal state.
- Auction-local proceeds rounding is explicit: poster gets half, protocol gets
  one quarter, and the curator credit receives any integer remainder.

Intended behavior:

- Auction token custody is known at all times.
- Settlement ownership semantics are explicit for bid and no-bid cases.

Required code changes:

- Implement escrow custody through the auction contract.
- Require auction contract configuration before auction drops mint.
- Register auction records after mint and require custody confirmation.
- Define pre-bid cancellation by poster or authorized auction admin.
- Add a formal `AuctionStatus` state model:
  - `None`
  - `Created`
  - `Active`
  - `EndedNoBid`
  - `EndedWithBid`
  - `SettledNoBid`
  - `SettledWithBid`
  - `Cancelled`
- Add events for state transitions.
- Convert with-bid final auction proceeds to auction-local pull credits.

Required tests:

- Auction created.
- Token custody verified.
- Successful bid settlement.
- No-bid settlement.
- Contract poster no-bid settlement pending-claim fallback.
- Cancellation before first bid and rejection after first bid.
- Failed NFT transfer leaves auction unsettled and credits unchanged.
- Reverting ERC721 receiver.
- No-bid pending-claim transfer failure rollback.
- Non-divisible highest-bid proceeds rounding.
- Forced ETH does not corrupt owed or emergency-surplus views.
- Repeated settlement attempt.
- Post-claim bid failure.
- Auction extension updates the auction record and emits an event.

Required docs:

- `docs/auction-custody.md`.
- State-machine diagram.
- Event catalog.

Acceptance criteria:

- Auction token custody is known and asserted in tests.
- Settlement is idempotent.
- Failed NFT transfer cannot trap ETH or mark settlement complete.
- Implementation matches `docs/adr/0002-auction-custody.md`.
- No-bid contract poster fallback keeps custody pending and allows a
  poster-authorized claim to a receiver.
- With-bid settlement credits final proceeds only after NFT transfer succeeds.

### P0-AUCT-002: Fix Auction Bidding Reentrancy And Refunds

- Priority/severity/type: `P0 / Critical / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [#12](https://github.com/6529-Collections/6529Stream/issues/12).
- Dependencies: [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), ADR 0002.
- Status: Implemented for auction bid/outbid refunds by PR #58. Broader auction
  custody, settlement proceeds, fixed-price pull payments, curator rewards, and
  emergency surplus boundaries remain separate P0 work.

Problem:

- Outbid refunds use push `call` before bid state is fully updated, creating
  reentrancy and denial-of-service risk.

Historical behavior before PR #58:

- Previous highest bidder is synchronously refunded during bidding.

Intended behavior:

- Previous bidder refund becomes a withdrawable credit.
- Highest bid and bidder update before any external interaction.

Required code changes:

- Replace outbid push refund with bidder credit accounting.
- Update bid state before crediting/refund logic where applicable.
- Add reentrancy protection to withdraw functions.

Required tests:

- Malicious bidder cannot reenter.
- Reverting previous bidder cannot block a new bid.
- Previous bidder can withdraw credit.
- Bid exactly at minimum passes.
- Bid one wei below minimum fails.
- High increment and zero increment behavior match ADR.

Required docs:

- Payment accounting model.
- Auction bid rules.

Acceptance criteria:

- No push refund in bid path.
- Previous bidder refund becomes withdrawable credit.
- Reentrant bidder test passes.
- Failed withdrawal preserves credit.
- Active highest-bid escrow and bidder credits are excluded from auction
  emergency-withdrawable surplus.

### P0-PAY-001: Add Pull-Payment Accounting

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [#25](https://github.com/6529-Collections/6529Stream/issues/25).
- Dependencies: [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24).

Problem:

- Poster, platform, curator, auction bidder, and curator reward payments are
  pushed synchronously, allowing reverts and reentrancy to block protocol flows.

Current behavior:

- Multiple contracts use low-level ETH `call` during minting, bidding,
  settlement, claims, and emergency withdrawals.

Intended behavior:

- User-owed balances are tracked separately from protocol surplus.
- Recipients withdraw their own credits.

Required code changes:

- Add accounting for poster credits, bidder credits, curator credits, curator
  reserves, protocol credits, active auction bid escrow, randomness reserves,
  protocol surplus, total poster owed, total bidder owed, total curator owed,
  total reserved, total owed, and emergency withdrawable balance.
- Add withdrawal functions.
- Ensure failed withdrawal does not erase credit.

Child tickets:

- [`P0-PAY-002`](https://github.com/6529-Collections/6529Stream/issues/26):
  Add credit ledger storage and total-owed views. Implemented for current
  local ledgers with category totals, `totalOwed()`, `totalReserved()`,
  `surplus()`, and `emergencyWithdrawable()` aliases on value-holding payment
  surfaces; broader shared-ledger abstraction remains future work under
  `P0-PAY-001` only if the project chooses that implementation path.
- [`P0-PAY-003`](https://github.com/6529-Collections/6529Stream/issues/27):
  Convert fixed-price poster/platform payouts to credits. Implemented for
  `StreamDrops` poster, protocol, and curator-reserve accounting; broader
  payment-parent work remains open.
- [`P0-PAY-004`](https://github.com/6529-Collections/6529Stream/issues/28):
  Convert auction outbid refunds to credits.
- [`P0-PAY-005`](https://github.com/6529-Collections/6529Stream/issues/29):
  Convert curator reward claims to credits. Implemented for
  `StreamCuratorsPool` curator credits, withdrawal behavior, and local
  owed/surplus views; shared payment-parent work remains open.
- [`P0-PAY-006`](https://github.com/6529-Collections/6529Stream/issues/30):
  Add withdrawal functions and failed-withdrawal behavior.
- [`P0-PAY-007`](https://github.com/6529-Collections/6529Stream/issues/31):
  Bound emergency withdrawals by surplus. Implemented for current
  emergency-withdrawal surfaces: `StreamAuctions`, `StreamDrops`,
  `StreamCuratorsPool`, `StreamMinter`, and `NextGenRandomizerRNG`; broader
  shared-ledger invariants remain open.
- [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8):
  Add payment invariants and forced-ETH tests. Implemented for the current local
  payment ledgers through fixed scenario tests and a bounded sequence fuzz
  invariant baseline covering `StreamDrops`, `StreamAuctions`,
  `StreamCuratorsPool`, `StreamMinter`, and `NextGenRandomizerRNG`; broader
  shared-ledger architecture work remains open under #25, #26, and #30 unless a
  later implementation introduces a unified protocol-wide ledger.

Required tests:

- Reverting recipient cannot block mint/bid/settlement.
- Failed withdrawal preserves credit.
- Reentrant withdrawal cannot steal funds.
- Forced ETH and direct ETH are reconciled.
- Emergency withdrawal cannot withdraw owed funds.

Required docs:

- Payment accounting ADR.
- Withdrawal docs.
- Emergency withdrawal policy.

Acceptance criteria:

- `totalOwed == totalPosterOwed + totalBidderOwed + totalCuratorOwed +
  totalCuratorReserved + totalProtocolOwed + totalAuctionBidEscrow +
  totalRandomnessReserved + otherContractSpecificReserved`.
- `address(this).balance >= totalOwed`; direct or forced ETH may make
  `address(this).balance > totalOwed` by creating surplus.
- `emergencyWithdrawable == address(this).balance - totalOwed`.
- No withdrawal can reduce another user's owed balance.
- Current local-ledger implementations expose ADR-style read aliases where
  applicable: `StreamDrops` exposes fixed-price poster, protocol,
  curator-reserve, total-reserved, total-owed, surplus, and
  emergency-withdrawable views; `StreamAuctions` exposes bidder, poster,
  protocol, curator, active-bid-escrow, total-reserved, total-owed, surplus,
  and emergency-withdrawable views; `StreamCuratorsPool`, `StreamMinter`, and
  `NextGenRandomizerRNG` expose their local owed/reserved/surplus boundaries.

### P0-ADMIN-001: Fix Admin Selector And Permission Model

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34).
- Dependencies: [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33).
- Status: Implemented for target-scoped function-admin checks, selector mismatch
  fixes, global-admin bypass, owner/root role-management recovery, revocation,
  deferred collection-admin lookup behavior, and negative permission tests.
  Pause domains are implemented under P0-ADMIN-002; signer lifecycle manager
  controls are implemented under P0-ADMIN-003. Deployment ceremony and broader
  production role operations remain separate roadmap work.

Problem:

- Function-level permissions can be misapplied when modifiers use the wrong
  selector. Collection admin permissions exist but are not consistently
  enforced.

Historical behavior before P0-ADMIN-001:

- `StreamCore.setCollectionData` is gated by
  `this.changeMetadataView.selector`.
- `StreamCore.updateCollectionInfo` is gated by
  `this.changeMetadataView.selector`; if this grouping is intended, the target
  implementation must replace it with an explicit named metadata role and tests.
- `StreamCuratorsPool.setMultipleMerkleRoots` is gated by
  `this.setMerkleRoot.selector`.
- Function-admin grants are keyed by address and selector only, not by target
  contract and selector.
- `IStreamAdmins` exposed collection-admin retrieval, but the implementation
  did not provide collection-admin storage or behavior.
- `StreamAdmins.tdhSigner` had no root recovery path, so the current admin
  registrar could become stuck if the key was lost or compromised.

Intended behavior:

- Every protected function is gated by the intended selector or role.
- Function-admin grants are scoped by account, target contract, and selector.
- Collection-scoped admin rules are explicit.
- Drop signer identities are not automatically admin identities.

Required code changes:

- Fix selector mismatch.
- Audit all `FunctionAdminRequired(this.*.selector)` calls.
- Scope function-admin checks to target contract and selector.
- Add a root-managed rotation path for the admin registrar or equivalent role.
- Define global, function, deferred collection, signer, guardian/pause, and
  owner roles.
- Make critical role changes two-step where practical: propose/accept or
  schedule/execute.
- Add events for grants, revocations, signer updates, ownership transfer, and
  sensitive address updates.
- Signer rotation events should include old signer, new signer, signer epoch,
  and effective block or time.
- Remove or explicitly implement the stale collection-admin interface path.

Required tests:

- Function admin can call only intended function.
- Wrong selector cannot authorize mutation.
- Same selector on another target contract cannot be authorized by the grant.
- Global admin path.
- Collection admin path if implemented.
- Unsupported collection-admin path if deferred.
- Revoked admin path.
- Unauthorized caller path.
- Signer add, remove, rotation, epoch increment, and stale epoch rejection.
- Admin registrar rotation and compromised/lost registrar recovery.
- Per-drop cancellation.
- Critical role transfer propose/accept or schedule/execute behavior where
  implemented.

Required docs:

- Admin/governance ADR.
- Access-control matrix.
- Signer lifecycle runbook.

Acceptance criteria:

- Selector mismatch fixed.
- Permission matrix tests pass.
- Role model is documented.
- P0-ADMIN-001 selector, target-scope, revocation, root-recovery, and deferred
  collection-admin tests pass.
- Signer lifecycle, cancellation controls, pause domains, and deployment admin
  ceremony remain tracked by follow-up roadmap items.

### P0-ADMIN-002: Define Pause And Emergency Controls

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS+OPS`.
- Blocks: Gate C.
- Issue: [`P0-ADMIN-002`](https://github.com/6529-Collections/6529Stream/issues/35).
- Dependencies: [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33), [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24).

Problem:

- The roadmap mentions emergency withdrawals and runbooks, but does not define
  pause/guardian controls.

Current behavior:

- Domain-scoped pause controls now exist for drop execution, minting, auction
  bidding, auction settlement, metadata mutation, and randomness requests.
- User credit withdrawals remain unpaused by default according to ADR 0004.
- Current emergency withdrawals are bounded by local `emergencyWithdrawable()`
  or equivalent reserve accounting and send surplus to the explicit
  `StreamAdmins.emergencyRecipient()`.
- Signer-manager-specific compromise controls remain partial: drop execution
  can be paused and stale signed drops can be invalidated through existing
  epoch/cancellation paths, but dedicated signer-manager roles remain future
  work.

Intended behavior:

- Emergency response controls are explicit, minimal, monitored, and tested.
- Pause controls are domain-scoped and do not silently block unrelated flows.
- Emergency withdrawals are surplus-only according to ADR 0003.

Required code changes:

- Keep pause controls domain-scoped for minting, bidding, settlement,
  withdrawals, drop execution, metadata mutation, and randomness requests.
- Keep pause and unpause authority separated: guardians can pause, unpause
  admins can unpause, and the governance root can manage both roles.
- Keep user withdrawals unpaused unless a later ADR-backed bounded withdrawal
  pause is accepted.
- Pause events should include scope, paused state, admin, and reason.
- Add signer-compromise response controls: drop-execution pause, signer epoch
  invalidation, per-drop cancellation, and monitored events.
- Replace full-balance emergency withdrawals with surplus-bounded withdrawals or
  prove a contract has no owed/reserved balances by construction.

Required tests:

- Pause/unpause authorization.
- Mint pause.
- Bid pause.
- Settlement pause.
- Drop execution pause.
- Metadata pause if implemented.
- Withdrawal pause or non-pause according to ADR.
- Events emitted and indexed.
- Signer-compromise runbook controls.
- Emergency withdrawal cannot withdraw poster, bidder, curator, protocol, active
  bid escrow, or randomness reserve balances.
- Direct or forced ETH can be withdrawn as surplus only when ADR 0003 accounting
  proves it is not owed or reserved.

Required docs:

- Emergency controls section in admin/governance docs.
- Incident runbook updates.
- Deployment admin ceremony checklist.

Acceptance criteria:

- Pause model accepted in ADR.
- Pause behavior is tested and monitored.
- Withdrawal non-pause behavior is tested; if a later withdrawal pause is
  implemented, it must be temporary, evented, and cannot erase credits.
- Emergency controls are bounded by `emergencyWithdrawable()` or equivalent
  surplus views and route surplus to the explicit emergency recipient.

### P0-ADMIN-003: Implement Signer Lifecycle Manager

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate B1/Gate C.
- Issue: [`P0-ADMIN-003`](https://github.com/6529-Collections/6529Stream/issues/79).
- Dependencies: [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33), ADR 0001.
- Status: Implemented for a single active drop signer model with
  root-managed signer managers, owner-approved signer-lifecycle targets, exact
  signer-lifecycle function grants, signer rotation, epoch invalidation, and
  per-drop cancellation tests.
  Multi-signer sets, production signing runbooks, and deployment ceremony
  manifests remain future release work.

Problem:

- Drop-signing identities should authorize drops, not manage protocol roles.
- ADR 0004 requires explicit signer-manager authority, signer rotation,
  epoch invalidation, per-drop cancellation, and observable events.

Historical behavior before P0-ADMIN-003:

- `StreamAdmins` allowed the constructor `tdhSigner` to register global and
  function admins through the same registrar path as the root owner.
- `StreamAdmins` also seeded that signer as a global admin by default.
- `StreamDrops` had signer rotation, epoch increment, and cancellation
  functions, but signer-manager authority and direct signer-lifecycle tests
  were incomplete.

Intended behavior:

- The governance root can grant and revoke signer managers.
- Signer managers can grant or revoke only the exact `StreamDrops`
  signer-lifecycle selectors on owner-approved signer-lifecycle targets:
  `updateTDHsigner`, `incrementSignerEpoch`, and `cancelDrop`.
- Drop signers are not operational admins merely because they can sign drops.
- Signer rotation increments the epoch, invalidates stale signed payloads, and
  permits fresh payloads from the new signer.

Required code changes:

- Add root-managed signer-manager storage and events to `StreamAdmins`.
- Add owner-managed signer-lifecycle target allowlisting.
- Remove drop-signer-based role-management authority from `StreamAdmins`.
- Add restricted signer-lifecycle function-admin grant helpers.
- Keep owner/root recovery for broader role management.

Required tests:

- Owner can grant and revoke signer managers.
- Owner can grant and revoke signer-lifecycle targets.
- Signer managers can grant exact signer-lifecycle selectors and cannot grant
  broad function-admin, non-signer selectors, or unapproved targets.
- Revoked signer managers cannot grant signer-lifecycle selectors.
- Drop signer cannot manage global or function-admin roles by default.
- Signer rotation emits epoch/signer events, invalidates stale payloads, and
  accepts a fresh payload from the new signer.
- Per-drop cancellation works before execution and fails after consumption.
- Unauthorized signer-lifecycle calls fail.

Required docs:

- Admin/governance ADR.
- Test matrix.
- Status and known blockers.
- Signer lifecycle runbook in a later deployment/ops PR.

Acceptance criteria:

- Drop-signing identities are not operational admins by default.
- Signer-manager authority is root-managed, evented, and restricted to
  signer-lifecycle grants on approved targets.
- Signer rotation and cancellation behavior are covered by direct tests.
- Roadmap/status docs distinguish implemented signer lifecycle controls from
  remaining deployment ceremony and signing-runbook work.

### P0-RAND-001: Harden Randomizer Requests And Callbacks

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37).
- Dependencies: [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14), [ADR 0005](../docs/adr/0005-randomness.md), ADR 0003, ADR 0004.
- Status: Parent issue completed in PR #65, with child follow-ups tracked below.
  VRF and arRNG adapters now have request lifecycle storage, provider/epoch
  validation, duplicate/stale rejection, observable stale marking, seed
  derivation that includes provider/request/collection/token epoch/output, and
  target-state tests.

Problem:

- Randomness callback validation and pending/failure states are not strong enough
  for production drops.

Current behavior:

- VRF and arRNG randomizer adapters now record request lifecycle state before
  fulfillment and validate callbacks through `StreamRandomizerLifecycle`.
- `StreamCore.setTokenHash` only checks the caller is the current collection
  randomizer and the token hash is still zero.
- `_safeMint` runs before `calculateTokenHash`, so receivers and indexers can
  observe a minted token while randomness is pending.
- Off-chain metadata returns a `pending` URI while the hash is zero; on-chain
  metadata currently embeds the zero hash directly.
- `StreamCore` now exposes a collection randomizer epoch that increments when a
  collection randomizer is updated; stale callbacks from replaced providers
  cannot silently fulfill old requests.
- VRF and arRNG adapters expose request state, request-to-token,
  token-to-request, token-to-collection, and pending-request count views.
- `StreamCore.addRandomizer` now blocks ordinary provider migration while the
  current lifecycle-aware adapter reports pending requests; explicit admin stale
  marking or valid fulfillment clears pending counts before migration.
- Callback-after-burn policy, canonical core/coordinator-owned lifecycle state,
  and richer metadata state remain open.
- Failed post-processing is now observable: if core token-hash writing reverts
  after valid provider output is accepted, VRF and arRNG adapters mark the
  request `FailedPostProcessing`, store the derived seed and failure-data hash,
  clear pending counts, emit a failure event with provider and epoch context,
  and reject duplicate callbacks.
- Failed post-processing retry is now bounded and deterministic: admins can call
  `retryRandomnessPostProcessing` only on `FailedPostProcessing` requests, the
  retry uses the stored derived seed, emits retry success/failure events, and
  cannot request new provider output. Successful retry emits the retry event
  followed by fulfillment confirmation for the same request ID; indexers should
  treat that sequence as retry confirmation rather than a second provider
  callback.
- `RandomizerNXT` block-derived helper randomness is out of production scope
  under ADR 0005 and no longer advertises itself as a production randomizer.
  The concrete `XRandoms` production-source helper was removed in
  `P0-RAND-008`; tests keep only an inline mock helper to prove the
  `RandomizerNXT` legacy boundary.

Intended behavior:

- Fulfillment validates request ID, token, collection, provider, and randomizer
  epoch.
- Pending and failed randomness are explicit states.
- Production drops use provider-backed async randomness only.
- Provider migration is observable and cannot silently fulfill stale requests.
- Provider migration is blocked by default while lifecycle-aware providers have
  pending requests for the collection.

Required code changes:

- Store `requestId => tokenId/collectionId/randomizerEpoch`. Implemented for
  VRF and arRNG adapters.
- Fulfill by request ID, not arrival order. Implemented for VRF and arRNG
  adapters.
- Reject stale callbacks from replaced randomizers. Implemented for VRF and
  arRNG adapters.
- Reject duplicate fulfillments. Implemented for VRF and arRNG adapters.
- Define whether fulfillment stores raw random words, derived token hash, or
  both. Implemented policy: adapters store the derived seed/hash and a
  canonical `rawOutputHash = keccak256(abi.encode(randomWords))`, expose both in
  request records, and avoid storing full provider word arrays in contract
  storage.
- Define whether randomizer migration can happen while requests are pending.
  Implemented default policy: ordinary migration is blocked while the current
  lifecycle-aware adapter reports pending requests.
- Record failed or stale post-processing for retry by a separate function if
  needed. Stale marking, failed post-processing state, and bounded deterministic
  manual retry are implemented for VRF and arRNG adapters.
- Add a bounded manual-retry path only for deterministic post-processing
  failures, not for changing random output. Implemented for VRF and arRNG
  adapters.
- Do not allow user-significant inputs after randomness request.
- Expose request lifecycle views by request ID and token ID. Implemented for
  request records, request state, token-level request/state views,
  request-to-token, token-to-request, and token-to-collection adapter views.
- Emit request, fulfillment, stale, failure, retry, provider-update, and
  epoch-update events.
- Remove, isolate, or disable weak helper randomness for production deployment
  paths. Implemented: `RandomizerNXT` cannot be configured as a production
  randomizer, and the concrete `XRandoms` helper contract was removed from
  production source.
- Bind provider fees, refunds, and adapter balances to ADR 0003 reserve and
  surplus accounting.

Child tickets:

- [`P0-RAND-002`](https://github.com/6529-Collections/6529Stream/issues/38):
  Add request lifecycle storage and views. Implemented for request and token
  lookups.
- [`P0-RAND-003`](https://github.com/6529-Collections/6529Stream/issues/39):
  Add callback validation for request, token, collection, and randomizer epoch.
  Closed as completed after PR #65.
- [`P0-RAND-004`](https://github.com/6529-Collections/6529Stream/issues/40):
  Add pending, fulfilled, stale, and failed post-processing states. Implemented
  for request lifecycle state, failed post-processing eventing, failure-data
  hash storage, and duplicate-callback rejection.
- [`P0-RAND-005`](https://github.com/6529-Collections/6529Stream/issues/41):
  Define and test randomizer migration with pending requests. Implemented
  default blocking policy for lifecycle-aware providers.
- [`P0-RAND-006`](https://github.com/6529-Collections/6529Stream/issues/42):
  Add bounded manual retry for deterministic post-processing failures.
  Implemented for VRF and arRNG adapters with stored-seed retry and attempt
  limits.
- [`P0-RAND-007`](https://github.com/6529-Collections/6529Stream/issues/43):
  Implement raw random words versus derived hash storage policy. Implemented by
  storing canonical raw-output hashes alongside derived seeds and deriving token
  hashes from `RANDOMNESS_SEED_TYPEHASH`, request-bound fields, and
  `rawOutputHash`.
- [`P0-RAND-008`](https://github.com/6529-Collections/6529Stream/issues/73):
  Remove weak `XRandoms` helper randomness from production source. Implemented
  by deleting the concrete helper contract while retaining the `IXRandoms`
  interface and inline test mock needed to prove `RandomizerNXT` cannot be
  configured for production collections.

Required tests:

- Pending metadata.
- Fulfilled metadata.
- Duplicate fulfillment fails. Implemented for VRF and arRNG adapters.
- Stale callback fails. Implemented for stale-marked requests and replaced
  randomizer epochs.
- Replaced randomizer callback fails. Implemented.
- Randomizer migration with pending requests follows ADR. Implemented for the
  default block-by-pending policy, plus stale/fulfilled unblocking and
  new-provider fulfillment.
- Failed post-processing state is observable. Implemented for VRF and arRNG
  adapters when deterministic core hash writing reverts.
- Manual retry cannot change random output. Implemented in
  `StreamRandomizerRetry.t.sol` by retrying only the stored derived seed, with no
  random-word, token, or collection inputs.
- Stored randomness data matches ADR 0005. Implemented with `rawOutputHash`
  request storage and event assertions in `StreamRandomizerLifecycle.t.sol` and
  `StreamRandomizerRetry.t.sol`.
- Derived token hash is deterministic from stored data. Implemented by deriving
  seeds from `RANDOMNESS_SEED_TYPEHASH`, provider, request ID, collection,
  token, epoch, and `rawOutputHash`.
- User-significant token data cannot bias output after request. Implemented by
  proving post-request `tokenData` mutation does not affect the stored seed or
  raw-output hash.
- Callback after burn follows ADR behavior.
- Fulfillment does not revert in normal operation.
- Unknown request ID fails. Implemented.
- Wrong provider fails. Implemented through live provider/epoch checks.
- Wrong token fails. Implemented by binding fulfillment to the recorded request
  token.
- Wrong collection fails. Implemented by validating the core token-to-collection
  binding before fulfillment.
- Wrong randomizer epoch fails. Implemented.
- Zero derived seed/hash fails.
- Weak helper randomizer cannot be configured for production collections or is
  fully outside production scope. Implemented: `RandomizerNXT` is rejected by
  `StreamCore.addRandomizer`, and the concrete `XRandoms` helper was removed
  from production source.
- Randomness reserves are not emergency-withdrawable surplus.

Required docs:

- Randomness lifecycle docs.
- Provider configuration docs.
- Stuck request runbook.
- Deployment manifest policy for production-eligible randomizers.
- Slither baseline update after `weak-prng` rows are fixed, scoped, or accepted
  with proof. Implemented in `ops/SLITHER_BASELINE.md` with `weak-prng=0`.

Acceptance criteria:

- Randomizer fulfillment validates request ID, token, collection, provider, and
  randomizer epoch for VRF and arRNG adapters.
- Pending, fulfilled, stale, and failed post-processing states are implemented
  and documented; metadata integration remains broader Gate D work.
- A valid provider callback produces exactly one terminal seed/hash for VRF and
  arRNG adapters.
- Unknown, empty-output, duplicate, stale, wrong-collection, and wrong-epoch
  callbacks fail with asserted custom errors.
- Fulfillment cannot finalize a zero derived seed/hash. The guard is present;
  a dedicated preimage-style test remains future work because `keccak256` zero
  output is not practically constructible.
- Pending/final metadata behavior is explicit for both off-chain and on-chain
  metadata.
- Provider migration increments a collection-level randomizer epoch or stricter
  equivalent.
- Existing pending requests cannot be silently fulfilled by a replacement
  provider.
- Ordinary migration while requests are pending is rejected with
  `PendingRandomnessRequests`; explicit stale marking or fulfillment clears the
  lifecycle-aware pending count before migration.
- Manual retry can only retry deterministic post-processing using the same
  provider output. Implemented for VRF and arRNG adapters through stored-seed
  retry, function-admin authorization, retry success/failure events, and
  `MAX_RANDOMNESS_POST_PROCESSING_RETRIES`.
- `RandomizerNXT` and `XRandoms` are removed from production paths, moved to
  test/demo scope, or otherwise made impossible to configure for production
  drops. Implemented: `RandomizerNXT` cannot be configured for production
  collections, and `XRandoms` no longer ships as a concrete production-source
  helper.
- Provider fee refunds and adapter balances are covered by ADR 0003 reserve and
  emergency-withdrawable tests. Current arRNG adapter reserve boundary is
  covered; request-level provider reserve lifecycle remains open.

### P0-SLITHER-001: Triage Static Analysis Baseline

- Priority/severity/type: `P0 / High / TEST+DOCS`.
- Blocks: Gate C and Gate F.
- Dependencies: Reproducible Slither invocation.

Problem:

- Slither reports a large baseline with high/medium findings that are not
  triaged.

Current behavior:

- `slither . --foundry-compile-all` runs but is not yet a CI gate.

Intended behavior:

- High/medium findings are fixed, accepted with rationale, or excluded as
  documented false positives.

Required code changes:

- None for triage itself; follow-up code issues may be created per finding.

Required tests:

- Each fixed finding gets at least one regression test.

Required docs:

- Appendix A Slither baseline summary.
- Detailed high/medium baseline in `ops/SLITHER_BASELINE.md`.
- Slither config after triage for any detector suppressions.

Acceptance criteria:

- Slither baseline table has detector, contract, function, source kind, source
  location, severity, confidence, status, resolution, required test, issue,
  gate, and owner.
- Current high/medium Slither rows are captured in `ops/SLITHER_BASELINE.md`.
- Every `Open` or `Needs Issue` finding has a canonical GitHub issue link that
  owns fix, accepted-risk, or false-positive resolution.
- CI fails on new high/medium findings after baseline is accepted.

## 7. P1 Protocol And Contract Workstreams

### Protocol Specification

- Write an actor-oriented protocol spec for:
  - TDH signer.
  - Global admin.
  - Function admin.
  - Collection admin.
  - Poster.
  - Buyer.
  - Bidder.
  - Curator.
  - Delegator.
  - Randomness provider.
  - Payout recipient.

- Define lifecycle specs for:
  - Collection creation.
  - Collection data setting.
  - Artist signature.
  - Fixed-price drop.
  - Auction drop.
  - Auction settlement.
  - Randomness request and fulfillment.
  - Metadata update and freeze.
  - Burn.
  - Curator reward claim.

- Add state-machine diagrams for fixed-price drop, auction, randomness,
  metadata freeze, and curator claim.
- Add storage model docs that identify what each contract owns, what can be
  recomputed, and what is canonical.
- Add public API matrix for stable external API, internal API, events, and
  errors.
- Add non-goals for the first public release.

### Protocol Invariants

- Collection IDs map to non-overlapping token ID ranges.
- Collection circulation supply cannot exceed configured max supply.
- Final supply is monotonic after being set.
- Burn accounting matches ERC721 ownership state.
- Token hash is set once and cannot be overwritten.
- Frozen collections cannot mutate metadata, scripts, image data, attributes, or
  dependency references.
- One signed drop executes at most once.
- One drop maps to one minted token.
- Fixed-price and auction drops cannot collide on the same drop ID.
- Highest bid and bidder update atomically.
- Outbid credits cannot be lost.
- Settlement is idempotent.

### StreamCore, Collections, And Minter

- Decide whether zero-supply collections are valid.
- Prevent underflow in reserved max token index calculations.
- Replace magic maximum supply and token range constants with named constants.
- Decide whether collection total supply `1/1` is product invariant or
  configuration.
- Require equal lengths for `StreamMinter.mint` arrays.
- Reject zero recipients.
- Reject zero-token entries unless intentionally allowed.
- Define empty batch behavior.
- Require `publicEndTime > publicStartTime`.
- Emit phase update events.
- Define when phase updates are allowed after minting starts.
- Review `burn(uint256 _collectionID, uint256 _tokenId)` and prefer deriving
  collection ID from token ID.
- Remove or complete unused state such as `setMintingCosts`, `tdhThreshold`, and
  `activeTime`.

### ERC721 Lifecycle

- Define callback-safe mint ordering.
- Test receiver callbacks that call `tokenURI`, transfer, approve, burn, or
  attempt reentry during mint.
- Define transfer and approval behavior during pending randomness.
- Burned-token metadata behavior now follows ADR 0006 and P1-META-005:
  `tokenURI` is unavailable, audit state is retained, and burned tokens do not
  count as live supply.

### Metadata, Scripts, And Dependency Registry

- Accept [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45)
  before metadata schema, freeze, dependency, burn, or ERC-4906 implementation.
- [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9)
  now provides segment-safe dependency-script rendering plus typed chunk and
  content hashes. Dependency version records and collection key/version/content
  pins are now implemented by
  [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48).
- Implement [`P1-META-001`](https://github.com/6529-Collections/6529Stream/issues/46):
  metadata schema and golden-file tests. Initial characterization fixtures pin
  current off-chain pending/final URIs, and schema-v1 on-chain fixtures now pin
  base64 JSON output with explicit `metadata_schema_version` and
  `metadata_state` fields. Remaining P1-META-001 work is tied to freeze/burn
  state coverage and any future schema migration.
- [`P1-META-002`](https://github.com/6529-Collections/6529Stream/issues/47)
  now implements the first collection freeze-boundary slice for `StreamCore`:
  freeze requires ended minting, elapsed final-supply delay, and final live
  token metadata; stores a deterministic manifest hash; emits
  `CollectionFrozen`; finalizes supply; tightens the reserved max token ID; and
  rejects current metadata-significant `StreamCore` writes after freeze.
  Dependency version pins are included in the freeze manifest; escaping and
  richer freeze invariants remain with their dedicated P1-META issues.
- [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48)
  now implements the first dependency registry versioning slice: registry writes
  create immutable versions with typed content hashes, provenance/deprecation
  views, and collection key/version/content-hash/registry-address pins; later
  registry versions or registry swaps do not change existing or frozen
  collection output until an unfrozen collection is explicitly repinned.
- [`P1-META-004`](https://github.com/6529-Collections/6529Stream/issues/49)
  now implements `StreamCore` ERC-4906 support and metadata update signaling:
  `supportsInterface(0x49064906)` succeeds, token-level metadata writes and
  randomness fulfillment emit `MetadataUpdate`, collection-level metadata
  writes emit `BatchMetadataUpdate` over the minted-ever range, and
  mint-only/burn paths do not emit misleading ERC-4906 events. Dependency
  registry version creation does not emit ERC-4906 for pinned collections
  because their output remains unchanged until explicit repinning.
- [`P1-META-005`](https://github.com/6529-Collections/6529Stream/issues/50)
  now implements burn metadata and supply semantics: burned tokens have no
  public `tokenURI`, emit protocol burn audit events, expose retained audit
  state, are excluded from live supply, cannot be reminted, and can record valid
  post-burn randomness as audit-only state without changing live metadata or
  freeze manifests.
- Continue [`P1-META-006`](https://github.com/6529-Collections/6529Stream/issues/51):
  metadata escaping, size limits, and render-sandbox tests. The first
  implementation slice now escapes on-chain JSON string fields and rejects raw
  attribute fragments that can break out of the enclosing attributes array. The
  second slice now hardens generated animation wrapper boundaries by escaping
  the library attribute, embedding `tokenData` and dependency scripts through
  escaped JavaScript strings, and neutralizing closing-script sequences. The
  third slice now enforces numeric byte limits for collection display fields,
  collection scripts, token data, token images, token attributes, generated
  `tokenURI` output, dependency scripts, and dependency provenance strings.
- Add metadata schema and golden-file tests for `name`, `description`, `image`,
  `attributes`, and `animation_url`.
- Complete the remaining render-safety work for browser sandboxing, URI policy,
  invalid UTF-8 policy, and structured attributes or semantic attribute schema
  validation.
- On-chain metadata now uses base64 JSON data URIs for schema-v1 output.
- Numeric byte limits are now set for collection scripts, dependency scripts,
  `tokenData`, image data, attributes, dependency provenance, and generated
  `tokenURI`.
- Dependency creation, update, versioning, deprecation, and freeze-time
  immutability now have a first implementation slice. Continue with dependency
  artifact packaging, external source manifests, and deployment migration
  runbooks.
- Treat generated HTML as executable code; render-sandbox tests remain required.
- Hash dependency chunks, full dependency output, and full collection script
  output.
- Define external URL policy for library URL, base URI, image URI, website, and
  license URL/text.

### Curator Rewards And Delegation

- Specify how `StreamCuratorsPool` trusts `DelegationManagementContract`.
- Document `ALL_COLLECTIONS` sentinel
  `0x8888888888888888888888888888888888888888`.
- Document curator reward use case `1`, subdelegation use case `998`, and
  consolidation use case `999`.
- Add zero-address, self-delegation, and past-expiry validation where intended.
- Add equal length checks for `batchDelegations` and `batchRevocations`.
- Replace magic batch limit `< 6` with a named constant and tests.
- Review unbounded array-returning views and nested de-duplication loops.
- Decide whether `NFTdelegation.sol` is protocol source, vendored source, or an
  external deployed dependency.
- Define Merkle proof leaf encoding:
  - Use `abi.encode`, not ambiguous packed dynamic fields.
  - Include collection, claimant, amount, root epoch, and domain fields.
  - Include index if using bitmap claims.
  - Test duplicate leaves and double claims.

### Standards, APIs, Naming, And Errors

- Normalize contract and file naming.
- Replace numeric option switches with typed APIs or enums.
- Replace magic metadata update indexes `999999` and `1000000`.
- Add ABI and interface stability policy.
- ERC721Enumerable is not part of the current `StreamCore` release surface.
  `StreamCore` preserves live `totalSupply()` but does not advertise ERC-721
  Enumerable or expose `tokenByIndex` / `tokenOfOwnerByIndex`.
- Continue reviewing supply model versus storage model:
  - Collection token ranges reserve up to 10 billion token IDs per collection.
  - Optional ERC721Enumerable-style indexing should stay off-chain unless a
    future ADR accepts the bytecode/gas cost.
  - Decide realistic collection sizes and gas targets before promising large
    ranges publicly.
- Establish gas budgets for mint, bid, settle, curator claim, `tokenURI`, and
  dependency/script reads.
- Replace ambiguous revert strings with custom errors for security-relevant
  paths.
- Document each custom error.
- Assert expected custom errors in P0 regression tests.

## 8. P1 Test Strategy And Verification

### Characterization Tests Before Refactors

- Add tests that lock current behavior before P0 rewrites.
- Maintain fixed-price drop characterization and target-state payment tests as
  fixed-price payment work lands.
- Characterize current auction creation/custody behavior and maintain
  target-state custody and settlement coverage as P0 auction work lands.
- Characterize current admin guards.
- Characterize current payout behavior.
- Characterize current randomness/pending metadata behavior.
- Initial Gate A skeleton coverage: admin signer/global/function permissions,
  current `StreamDrops` packed drop ID encoding, signer-only drop execution,
  fixed-price minting to explicit recipients, drop replay rejection, mocked
  `StreamDrops` auction argument passing, real
  `StreamDrops -> StreamMinter -> StreamCore` auction mint custody to the
  auction contract escrow, auction status/end-time recording, current admin selector
  mismatch behavior, converted fixed-price pull-payment behavior, poster,
  payout-address, and curators-pool rejection behavior, pending metadata,
  immediate randomizer fulfillment, configured-randomizer-only token hash
  setting, and one-time token hash immutability.
- Note: this Gate A list includes some known-unsafe behavior that remains to be
  rewritten by later P0 work. These tests are regression tripwires before P0
  rewrites, not endorsements of protocol correctness.

### Test Ordering

1. Harness and deployment fixtures.
2. Admin guard regression tests.
3. Drop authorization characterization tests.
4. Auction characterization tests.
5. EIP-712 tests.
6. Auction custody/payment tests.
7. Randomizer pending/fulfilled/stale tests.
8. Metadata golden-file tests.
9. Invariant tests.
10. Fork/deployment rehearsal tests.
11. Gas snapshots.

### Testing Ladder

- Unit tests for admin guards, setters, zero-address checks, phase boundaries,
  supply math, and Merkle proof checks.
- Integration tests for real contract flows through
  `StreamDrops -> StreamMinter -> StreamCore`, auctions, curator claims,
  randomness, and metadata.
- Negative/adversarial tests for wrong signer, replayed drop, expired drop,
  reverting recipients, reentrant bidder, ERC721 receiver callback reentry, bad
  Merkle proof, and stale randomizer callback.
- Fuzz and invariant tests for supply, one-drop-one-token, immutable token hash,
  payment accounting, auction consistency, and frozen metadata.
- Golden-file tests for metadata JSON, generated HTML, dependency scripts,
  pending randomness, fulfilled randomness, and escaped token data.
- Fork/deployment tests for anvil, forked networks, VRF/arRNG config, admin
  grants, verification inputs, and post-deploy wiring.
- Gas and size regression tests for mint, bid, settlement, curator reward claim,
  `tokenURI`, dependency/script reads, and contract size limits.

### Minimum P0 Test Gate

No P0 security PR may merge without:

- Happy path test.
- Direct regression test.
- Negative test.
- Event assertion where relevant.
- Docs update if external behavior changes.
- Test matrix row updated.

### Minimum P0 Merge Gate

No P0 contract PR may merge without:

- Security owner review.
- Protocol owner review.
- CI tests passing.
- Test matrix row updated with issue, gate, owner, and status.
- Docs updated if external behavior changes.
- No new high/medium static-analysis findings.

### First Test Queue

- Fixed-price drops: initial characterization passing for the happy path,
  replay failure, wrong signer failure, synchronous payout behavior, poster
  rejection, payout-address rejection, and curators-pool rejection.
- Fixed-price drop expired deadline failure after EIP-712 is introduced.
- Admin selector mismatch regression: initial characterization passing.
- Auction mint custody happy path: initial characterization passing.
- Pending metadata and immediate randomizer fulfillment: initial
  characterization passing.
- Token hash randomizer authorization and one-time immutability: initial
  characterization passing.
- Auction bid, outbid, extension, and settlement.
- Malicious bidder reentrancy.
- No-bid auction settlement.
- Payout recipient revert.
- Outbid refund revert or pull-credit withdrawal.
- Admin selector permission regression.
- Zero-address constructor and setter reverts.
- Randomizer pending metadata.
- Randomizer fulfilled metadata.
- Randomizer stale callback failure.
- Curator reward valid claim.
- Curator reward double claim.
- Curator reward delegated claim.
- Curator reward invalid proof.

### Test CI Requirements

- Run `forge test -vvv` on every pull request.
- Run fuzz/invariant tests in CI once stable.
- Run fork/deployment tests on scheduled or manually triggered workflows if they
  require RPC credentials.
- Publish coverage after meaningful tests exist.
- Publish gas snapshots and fail on unexpected regressions after baselines are
  approved.
- Keep every bug fix paired with a regression test.

## 9. P2 Tooling, CI, And Repository Hygiene

### Reproducible Setup

- Make setup work on Windows and Linux.
- Make the Windows bootstrap usable in current and future shells.
- Add `make.ps1` or document Makefile as Unix-only.
- Add `make check` or documented equivalent as the canonical local gate.
- Keep the production size gate in `make check`, Windows/Linux check scripts,
  and CI: `forge build --sizes --via-ir --skip test --skip script --force`.
- Treat generic all-artifact `forge build --sizes` as a diagnostic only while
  test-only invariant handlers exceed initcode limits.
- Add exact tool pinning for:
  - Foundry.
  - Solidity compiler.
  - Slither.
  - Python.
  - Node if introduced.
- Add optional devcontainer, Nix flake, or Docker image for CI parity.

### Formatting, Linting, And Static Analysis

- Decide whether vendored code is formatted/linted or excluded.
- Make `forge fmt --check smart-contracts` pass or document exclusions.
- Burn down invalid NatSpec tags and warning baseline.
- Normalize Solidity pragmas across source, interfaces, tests, and vendored
  files.
- Add Markdown lint.
- Add ShellCheck for shell scripts.
- Add PowerShell Script Analyzer for PowerShell scripts.
- Keep `slither.config.json` free of detector suppressions until triage.
- Fail CI on new high/medium findings after baseline acceptance.

### Dependency And Provenance Management

- Prefer package-managed OpenZeppelin and Chainlink dependencies through Foundry
  remappings.
- If vendoring remains, document exact upstream versions and local
  modifications.
- Add `NOTICE` or equivalent provenance docs.
- Confirm mixed SPDX identifiers are compatible with intended distribution.
- Add dependency license report and, if feasible, NOTICE generation.

### Repository Boundary

- Decide whether `ops/skills` and `.codex` guidance belong in the public
  protocol repo.
- If included, document them as contributor automation.
- If not, move them to an internal or ops-focused repo.
- Ensure README references match the canonical location.

## 10. P2 Deployment And Operations

### Deployment Scripts And Manifests

- Maintain Foundry deployment scripts for local/anvil rehearsal and add testnet
  and fork dry-run coverage.
- Add post-deploy wiring for admins, minter, drops, auctions, randomizers,
  dependency registry, payout, and curator pool.
- Maintain deployment manifest schema and JSON example with network, chain ID,
  addresses, constructor args, git commit, compiler version, Foundry version,
  ABI hashes, admin multisig addresses, and external dependencies.
- Generate deployment manifest examples from committed inputs and fail local/CI
  checks when the generated manifest drifts.
- Make deployment rehearsal a release blocker.

### Admin Ceremony Checklist

- Deployer address.
- Safe/multisig address.
- Owner transfer.
- Role grants.
- Signer setup.
- Pause/guardian setup if accepted.
- Verification.
- Dry-run mint.
- Dry-run auction.
- Manifest generation.

### Operational Runbooks

- Stuck auction.
- Failed payout.
- Stuck randomness.
- Incorrect Merkle root.
- Incorrect dependency script.
- Bad metadata before freeze.
- Bad metadata after freeze.
- Compromised signer.
- Compromised admin.
- Marketplace metadata not refreshing.

### Monitoring, Indexing, And Reorgs

- Every externally important state transition emits an event.
- Events include stable IDs.
- Common query fields are indexed.
- Event topic catalog is generated for releases.
- Add indexer confirmation-depth guidance.
- Add chain reorg behavior for off-chain consumers.
- Add drop-signing pipeline behavior under reorg.
- Add signed payload invalidation for failed or superseded payloads.

### Off-Chain Drop Pipeline

- Add CLI tools or scripts to generate EIP-712 payloads, sign payloads, verify
  signatures, generate Merkle roots/proofs, validate metadata JSON, and simulate
  a drop on an anvil fork.
- Add end-to-end rehearsal docs for collection setup, fixed-price drop, auction
  drop, curator rewards, metadata freeze, and emergency recovery.

## 11. P2 Documentation And Open-Source Project

### Documentation Quality Bar

- Documentation is layered:
  - Quick for contributors.
  - Precise for auditors.
  - Operational for maintainers.
  - Clear for integrators.
- Document actual on-chain behavior, not aspirational product behavior.
- Keep known blockers separate from accepted risks.
- Add `docs/status.md` or a README maturity block:
  - Experimental.
  - Not audited.
  - Not production-ready.
  - Known P0 blockers.
- Add `docs/known-blockers.md`.
- Reserve `docs/known-risks.md` for accepted risks only.

### Documentation File Targets

- First wave:
  - `docs/architecture.md`.
  - `docs/drop-authorization.md`.
  - `docs/auction-custody.md`.
  - `docs/deployment.md`.
  - `docs/security.md`.
  - `CONTRIBUTING.md`.
  - `SECURITY.md`.
- Protocol docs:
  - Fixed-price drop model.
  - Auction custody and settlement model.
  - EIP-712 signing schema.
  - Payment split and rounding rules.
  - Metadata and freeze lifecycle.
  - Randomness lifecycle.
  - Curator and delegation semantics.
- Developer setup docs:
  - Windows.
  - Linux.
  - CI.
  - Foundry.
  - Slither/static analysis.
  - Build/test/fmt/lint/coverage/gas commands.
  - PATH/tooling troubleshooting.

### API And NatSpec Docs

- Fully annotate public/external Solidity interfaces.
- Generate API docs from NatSpec after external interfaces stabilize.
- Document events, custom errors, structs, roles, permissions, and invariants.
- Fix invalid NatSpec tags currently emitted by `forge build`.
- Add docs tests that run README commands in CI where practical.

### Security And Audit Docs

- Add `SECURITY.md`.
- Add threat model.
- Add vulnerability disclosure process.
- Add emergency runbooks.
- Add audit history.
- Add external audit package index.

### Contributor Infrastructure

- Add `CONTRIBUTING.md`.
- Add code of conduct.
- Add issue templates.
- Add PR template.
- Add CODEOWNERS.
- Add changelog.
- Add maintainer/release policy.
- Add issue labels and triage rules.
- Add RFC process for protocol changes.
- Add public roadmap status fields: proposed, accepted, in progress, blocked,
  and done.

### Glossary And NextGen Lineage

- Define TDH, poster, curator, drop, pool, collection, dependency, randomizer,
  freeze, execution address, signer, payer, and settlement recipient.
- Document which contracts are inherited or modified from NextGen.
- Document behavior that intentionally differs.
- Document names retained for backward compatibility.
- Document names that should be renamed before first public release.

## 12. P2 Release, Versioning, And Integration

### Release Discipline

- Define per-contract semantic version, protocol release version, deployment
  version, ABI version, and metadata schema version.
- Add signed tags.
- Add checksummed artifacts. Initial `SHA256SUMS` and machine-readable checksum
  manifest generation exists under `release-artifacts/latest/`.
- Add detached signatures for the checksum bundle once maintainer signing-key
  policy is accepted.
- Add build provenance attestation where practical.
- Add machine-readable release manifest. Initial
  `release-artifacts/latest/release-manifest.json` generation and drift check
  ties release artifacts, ABI compatibility, deployment manifests, address
  books, governance docs, and release-ceremony status together; live production
  release ceremony evidence remains future work.
- Add source verification artifact retention. Initial
  `release-artifacts/latest/source-verification-inputs.json` generation and
  drift check retain source hashes, compiler settings, constructor ABI,
  bytecode/linking status, and verification command templates; live explorer
  submission evidence remains future broadcast work.
- Add ABI compatibility diff checks for every release. Initial production
  contract ABI surface baseline exists under
  `release-artifacts/baselines/v0.1.0/abi-surface.json`; intentional breaking
  changes are governed by `docs/release-policy.md` and the changelog gate, while
  baseline refreshes still require maintainer approval.
- Add changelog gate for release-impacting PRs. Initial `CHANGELOG.md`,
  `docs/release-policy.md`, `scripts/check_changelog.py`, and CI/local gate
  wiring exist.
- Add interface ID catalog. Initial deterministic interface ID catalog exists
  under `release-artifacts/latest/`.
- Add deployment manifest generator. Initial local Anvil manifest generation,
  sanitized Foundry broadcast-derived manifest input generation, and checksum
  drift checks exist; live fork/testnet broadcast manifests remain future work.
- Add deployment address-book generator. Initial local Anvil and sanitized
  broadcast-derived address books exist under `deployments/address-books/`;
  production address books remain future live-broadcast release work.
- Add release checksum bundle generator. Initial signable local checksum files
  exist under `release-artifacts/latest/`; detached signatures and signed tags
  remain future release-ceremony work.
- Add storage layout snapshots if upgradeability is ever introduced.

### Release Checklist

- All CI green.
- Slither baseline accepted.
- Gas snapshot accepted.
- Deployment rehearsal complete.
- Manifests generated. Initial local Anvil and sanitized broadcast-derived
  manifest generation and checksum drift checks exist; fork/testnet production
  manifests remain future work.
- Release manifest generated. Initial deterministic top-level manifest exists
  under `release-artifacts/latest/release-manifest.json`; production broadcast
  manifests, detached signatures, and signed tags remain future release-ceremony
  work.
- Source verification inputs generated. Initial deterministic verification
  input bundle exists under
  `release-artifacts/latest/source-verification-inputs.json`; live explorer
  submissions remain future broadcast work.
- ABIs checksummed. Initial ABI and bytecode checksum baseline exists under
  `release-artifacts/latest/`; the signable checksum bundle exists under
  `release-artifacts/latest/SHA256SUMS`; detached signatures remain future
  work.
- Contracts verified.
- Changelog written and changelog gate passes.
- Security docs updated.

### Breaking Change Definition

- Function removal.
- Event signature change.
- Changed revert behavior.
- Changed metadata schema.
- Changed authorization schema.
- Changed deployment manifest schema.
- Changed role/permission semantics.

### Integration Outputs

- ABI JSON.
- Address book JSON per network.
- Deployment manifest JSON.
- Source verification input JSON.
- Release manifest JSON.
- Interface IDs. Initial generated catalog exists under
  `release-artifacts/latest/interface-ids.json`.
- Event topic catalog. Initial generated catalog exists under
  `release-artifacts/latest/event-topic-catalog.json`.
- Fixed-price mint client.
- Auction bid client.
- Auction settlement client.
- Curator reward claim client.
- Metadata fetch/render client.
- Admin setup script.

### Indexer/Subgraph Plan

- Schema.
- Event handlers.
- Backfill strategy.
- Reorg handling.
- Versioning for contract redeployments.

### Marketplace Compatibility

- OpenSea.
- Reservoir.
- Blur.
- Manifold or other common collector tooling.
- ERC-2981 royalty note: `royaltyInfo()` exposes royalty information, but
  payment depends on marketplace or external payment logic.

## 13. P3 Content, Legal, Privacy, And Long-Term Scale

### Content Provenance And Moderation

- Define who can submit token data.
- Define who approves token data before signing.
- Define how poster identity is verified.
- Define how artist approval is recorded.
- Define how content hashes are stored off-chain and on-chain.
- Document immutable-content risk.
- Add copyright/DMCA intake.
- Add trademark complaint handling.
- Add malware or hostile script review.
- Add PII/secrets accidental inclusion playbook.
- Add jurisdiction and sanctions escalation path for payout recipients.

### Pre-Mint Content Checklist

- Script linting.
- Dependency review.
- Metadata preview.
- External URL review.
- Royalty recipient review.
- Payout recipient review.
- Artist sign-off.

### Data Retention And Privacy

- Never commit private keys, API keys, unreleased drop payloads, private
  collector data, or internal operational notes.
- Intentionally public data may include deployment manifests, ABI artifacts,
  drop payload fixtures, metadata fixtures, and audit reports.
- Token data is public once submitted on-chain and may be indexed permanently.
- Token data must not contain secrets, private user data, or nonconsensual
  personal information.

### Long-Term Scalability

- Extreme stress testing for many delegation entries.
- Extreme stress testing for many auction bids.
- Extreme stress testing for large metadata and dependency script sizes.
- Long-term indexer/backfill performance testing.

## Appendix A: Slither Baseline

Source of truth: `ops/SLITHER_BASELINE.md`.

Status values: `Open`, `Fixed`, `Accepted`, `False Positive`, `Needs Issue`.
Every detailed row must record source file and line range, identify whether the
finding is first-party, vendored, generated, or test-only, and include an issue
link for each `Open` or `Needs Issue` row before Gate F.

Current capture:

- Tool: Slither `0.11.5`.
- Compiler: Solidity `0.8.19`.
- Command: `slither . --config-file slither.config.json --foundry-compile-all --json <temp-file>`.
- Status: high/medium rows triaged, not accepted as a CI gate.
- Result: 717 findings, including 4 High, 19 Medium, and 93 Low.

Impact summary:

| Impact | Count |
| --- | ---: |
| High | 4 |
| Medium | 19 |
| Low | 93 |
| Informational | 590 |
| Optimization | 11 |

High/medium detector summary:

| Detector | Impact | Count | Primary scope | Status | Issue | Required action |
| --- | --- | ---: | --- | --- | --- | --- |
| `arbitrary-send-eth` | High | 0 current / 4 fixed | first-party emergency withdrawals | Fixed | [#8](https://github.com/6529-Collections/6529Stream/issues/8) | Current emergency-withdrawal surfaces are bounded: auction, fixed-price drops, curator pool, StreamMinter surplus, and conservative randomizer reserve boundary tests now exist |
| `encode-packed-collision` | High | 0 current / 3 fixed | drop authorization and dependency/script hashing | Fixed | [#9](https://github.com/6529-Collections/6529Stream/issues/9), [#10](https://github.com/6529-Collections/6529Stream/issues/10) | Drop authorization rows and dependency-script segment hashing are fixed; keep typed hash tests and Slither baseline traceability |
| `incorrect-exp` | High | 1 | vendored `Math.mulDiv` | False Positive | [#11](https://github.com/6529-Collections/6529Stream/issues/11) | OpenZeppelin provenance and `mulDiv` full-precision regressions are documented in `docs/vendored-libraries.md` and `test/StreamVendoredLibraries.t.sol` |
| `reentrancy-eth` | High | 0 current / 1 fixed | auction bidding | Fixed | [#12](https://github.com/6529-Collections/6529Stream/issues/12) | Replaced bid-path push refunds with bidder pull credits and state-before-withdrawal flow |
| `suicidal` | High | 3 | test-only forced-ETH helpers | Accepted | Accepted test-only | Intentionally retained for forced-ETH accounting tests under Solidity 0.8.19 |
| `uninitialized-state` | High | 0 current / 2 fixed | mint-accounting mappings | Fixed | [#13](https://github.com/6529-Collections/6529Stream/issues/13) | Removed never-written public/allowlist mint-count mappings and kept retained airdrop-counter regression coverage |
| `weak-prng` | High | 0 current / 2 fixed | word pool randomness helpers | Fixed | [#73](https://github.com/6529-Collections/6529Stream/issues/73) | Removed the concrete `XRandoms` production-source helper and kept `RandomizerNXT` impossible to configure for production collections |
| `divide-before-multiply` | Medium | 9 | vendored math/base64 helpers | False Positive | [#11](https://github.com/6529-Collections/6529Stream/issues/11) | OpenZeppelin provenance plus Base64 padding and `mulDiv` precision regressions are documented in `docs/vendored-libraries.md` and `test/StreamVendoredLibraries.t.sol` |
| `incorrect-equality` | Medium | 1 | test-only malleable-signature helper | Accepted | Accepted test-only | Keep scoped to test-only EIP-712 negative coverage |
| `locked-ether` | Medium | 7 | test-only rejection/reentrancy/mock receivers | Accepted | Accepted test-only | Keep scoped to payment and emergency-withdrawal tests |
| `uninitialized-local` | Medium | 1 current accepted test-only / 11 fixed | first-party and test helper locals | Fixed for first-party production rows; only the accepted test-only `MockStreamMinter` helper row remains current | [#15](https://github.com/6529-Collections/6529Stream/issues/15), [#9](https://github.com/6529-Collections/6529Stream/issues/9) | Keep production locals explicit and test-only acceptance documented |
| `unused-return` | Medium | 1 | ERC-1271 test tuple helper | Accepted | Accepted test-only | Keep scoped to test-only assertion helper |

## Appendix B: Test Matrix

Status values: `Missing`, `Planned`, `In Progress`, `Passing`, `Blocked`.

| Finding | Required test | Intended test file | Status | Issue | Gate | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| `tx.origin` recipient bug | Contract executor submits a drop without `tx.origin` dependency | `test/StreamDropsCharacterization.t.sol` and `test/StreamDropsIntegrationCharacterization.t.sol` | Target-state explicit-recipient, contract-executor, non-zero auction-recipient rejection, and no-bid settlement tests added | [`P0-AUTH-001`](https://github.com/6529-Collections/6529Stream/issues/18) | Gate C | TBD |
| Ad hoc drop authorization | EIP-712 valid, explicit digest encoding, replayed, expired, wrong chain, wrong contract, wrong signer, cancelled, duplicate cancellation, stale epoch, malleable, zero recovered signer, token substitution, bad quantity, bad payer, sale-mode field misuse, lifecycle event assertions, and compact signature tests | `test/StreamDropsEIP712.t.sol` | Passing for EOA/EIP-2098 target state; non-ERC-1271 contract signer fails closed | [`P0-AUTH-002`](https://github.com/6529-Collections/6529Stream/issues/10) | Gate C | TBD |
| ERC-1271 decision | ERC-1271 mock signer success, auction success, invalid magic, reverted check, empty/short/extra return, wrong digest, wrong signature bytes, replay, expiry, and EOA regression | `test/StreamDropsERC1271.t.sol` | Passing | [`P0-AUTH-003`](https://github.com/6529-Collections/6529Stream/issues/19) | Gate B1/Gate C | TBD |
| Auction reentrancy | Malicious bidder cannot reenter bid/withdraw flows | `test/StreamAuctionPayments.t.sol` | Passing for P0-AUCT-002: bid path has no outbid push refund, rejecting previous bidder cannot block, and withdrawal reentrancy cannot drain more than credited funds | [`P0-AUCT-002`](https://github.com/6529-Collections/6529Stream/issues/12) | Gate C | TBD |
| Outbid refund failure | Previous bidder credited even if receiver reverts | `test/StreamAuctionPayments.t.sol` | Passing: outbid creates bidder credit, current highest bid remains active escrow, previous bidder can withdraw, and failed withdrawal preserves credit | [`P0-AUCT-002`](https://github.com/6529-Collections/6529Stream/issues/12) | Gate C | TBD |
| Payment ledger totals | Poster, bidder, curator, curator reserve, protocol, total owed, total reserved, surplus, and emergency-withdrawable views follow ADR 0003 | `test/StreamAuctionPayments.t.sol`, `test/StreamFixedPricePayments.t.sol`, `test/StreamCuratorsPool.t.sol`, `test/StreamEmergencyWithdraw.t.sol`, `test/StreamPaymentsInvariant.t.sol` | Passing for current local ledgers: auction bidder credits, active bid escrow, settlement poster/protocol/curator credits, fixed-price poster/protocol/curator-reserve credits, curator reward credits, StreamMinter zero-owed surplus, randomizer adapter reserve, local total owed, total reserved, balance coverage, `surplus()`, and emergency-withdrawable views are covered by scenario tests plus bounded sequence fuzzing. A unified protocol-wide shared ledger abstraction remains future work if introduced. | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-002`](https://github.com/6529-Collections/6529Stream/issues/26), [`P0-PAY-003`](https://github.com/6529-Collections/6529Stream/issues/27), [`P0-PAY-005`](https://github.com/6529-Collections/6529Stream/issues/29), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C/Gate D | TBD |
| Withdrawal failure behavior | Failed withdrawal preserves account credit and category totals | `test/StreamAuctionPayments.t.sol`, `test/StreamFixedPricePayments.t.sol`, `test/StreamCuratorsPool.t.sol`, `test/StreamPaymentsInvariant.t.sol` | Passing for implemented local withdrawal paths: auction bidder credits, auction settlement proceeds, fixed-price poster/protocol credits, and curator reward credits have failed-withdrawal regressions, while sequence fuzzing proves mixed withdrawals do not corrupt category totals. A future shared withdrawal abstraction would need its own direct failure tests. | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-003`](https://github.com/6529-Collections/6529Stream/issues/27), [`P0-PAY-005`](https://github.com/6529-Collections/6529Stream/issues/29), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| Emergency surplus boundary | Emergency withdrawal can withdraw only surplus and cannot withdraw owed or reserved funds | `test/StreamAuctionPayments.t.sol`, `test/StreamFixedPricePayments.t.sol`, `test/StreamCuratorsPool.t.sol`, `test/StreamEmergencyWithdraw.t.sol`, `test/StreamPaymentsInvariant.t.sol` | Passing for all first-party emergency-withdraw functions currently found by `rg -n "function emergencyWithdraw" smart-contracts`: `StreamAuctions.emergencyWithdraw()` excludes bidder credits, active highest-bid escrow, and auction settlement credits; `StreamCuratorsPool.emergencyWithdraw()` excludes curator reward credits from surplus; `StreamMinter.emergencyWithdraw()` exposes zero owed and withdraws only forced surplus; `NextGenRandomizerRNG.emergencyWithdraw()` exposes zero emergency-withdrawable balance for adapter reserves. `StreamDrops` has no emergency-withdraw function, but its `totalOwed()`/`emergencyWithdrawable()` fixed-price surplus views are included because payment accounting depends on them. Bounded sequence fuzzing now reasserts these surplus boundaries after mixed mint, bid, settlement, withdrawal, randomizer, emergency-withdrawal, and forced-balance operations. | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-003`](https://github.com/6529-Collections/6529Stream/issues/27), [`P0-PAY-005`](https://github.com/6529-Collections/6529Stream/issues/29), [`P0-PAY-007`](https://github.com/6529-Collections/6529Stream/issues/31), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C/Gate D | TBD |
| Randomness reserve accounting | Randomizer provider reserves are not emergency-withdrawable surplus | `test/StreamEmergencyWithdraw.t.sol`, `test/StreamPaymentsInvariant.t.sol`, later `test/StreamRandomizerPayments.t.sol` | Passing for current adapter boundary: `NextGenRandomizerRNG` treats its full balance as `totalRandomnessReserved()`/`totalOwed()` and reports zero `emergencyWithdrawable()` balance, including direct ETH, forced ETH, post-request remaining reserve, and mixed sequence fuzz operations. Fuller request-level provider reserve lifecycle accounting remains open. | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-007`](https://github.com/6529-Collections/6529Stream/issues/31), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8), [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14) | Gate C/Gate D | TBD |
| Auction custody failure | Auction settlement succeeds only with explicit custody/approval | `test/StreamAuctionCustody.t.sol` | Passing: explicit auction-contract escrow, registration, status views, active/ended/terminal states, with-bid settlement, failed NFT transfer, cancellation, extension, and post-terminal bid rejection are covered | [`P0-AUCT-001`](https://github.com/6529-Collections/6529Stream/issues/22) | Gate B1/Gate C | TBD |
| No-bid settlement ambiguity | No-bid settlement ownership follows ADR | `test/StreamAuctionCustody.t.sol` | Passing: no-bid settlement targets the signed poster, contract posters create pending NFT claims, only the poster can complete the claim, and repeated settlement is rejected | [`P0-AUCT-001`](https://github.com/6529-Collections/6529Stream/issues/22) | Gate B1/Gate C | TBD |
| Admin selector mismatch | Wrong function selector cannot authorize mutation; intentional grouped permissions use explicit named roles | `test/StreamAdminSelectors.t.sol`, `test/StreamCoreAdminCharacterization.t.sol` | Passing: P0-ADMIN-001 fixes `setCollectionData`, `updateCollectionInfo`, and `setMultipleMerkleRoots` selector guards and covers wrong-selector regressions | [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34) | Gate C | TBD |
| Function-admin target scope | Grant for one contract and selector cannot authorize another target with the same selector | `test/StreamAdminSelectors.t.sol` | Passing: function-admin grants are keyed by account, target, and selector; same selector on another target does not authorize; revocation and global-admin bypass are covered | [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34) | Gate C | TBD |
| Collection-admin support | Collection admin can mutate only explicitly allowed fields for one collection, or unsupported interface behavior is explicit | `test/StreamAdmins.t.sol`, later `test/StreamCollectionAdmins.t.sol` | Passing for deferred support: `StreamAdmins.retrieveCollectionAdmin(...)` returns false and no collection-admin mutation path is implemented; positive collection-admin roles remain future work | [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34) | Gate C | TBD |
| Signer lifecycle | Signer manager grants, rotation, epoch increment, stale epoch rejection, and per-drop cancellation follow ADR 0004 | `test/StreamAdmins.t.sol`, `test/StreamAdminSelectors.t.sol`, `test/StreamSignerAdmin.t.sol`, `test/StreamDropsEIP712.t.sol` | Passing for current single-active-signer model: drop signers are not global or role-management admins by default, owner/root can grant and revoke signer managers and signer-lifecycle targets, signer managers can grant only exact `StreamDrops` signer-lifecycle selectors on approved targets, revoked signer managers cannot grant, signer rotation emits events and invalidates stale old-signer payloads, fresh new-signer payloads pass, per-drop cancellation works before execution and fails after consumption, and unauthorized lifecycle calls fail. Multi-signer sets and production signing runbooks remain future work. | [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33), [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34), [`P0-ADMIN-003`](https://github.com/6529-Collections/6529Stream/issues/79) | Gate B1/Gate C | TBD |
| Pause controls | Domain-specific pause blocks only the intended mint, bid, settlement, metadata, randomness-request, or drop-execution path | `test/StreamPauseControls.t.sol` | Passing: guardians can pause but not unpause, unpause admins can unpause but not pause, owner/root can manage pause roles, `DropExecution`, `Mint`, `AuctionBid`, `AuctionSettlement`, `MetadataMutation`, and `RandomnessRequest` pauses block their intended paths, ordinary user credit withdrawals remain available during operational pauses, and the signer-compromise flow can pause drop execution, invalidate/cancel an exposed drop, unpause, and still reject the stale payload | [`P0-ADMIN-002`](https://github.com/6529-Collections/6529Stream/issues/35) | Gate C | TBD |
| Admin emergency controls | Emergency admin can withdraw only surplus and cannot alter credits, reserves, custody, or consumed drop IDs | `test/StreamEmergencyWithdraw.t.sol`, `test/StreamAuctionPayments.t.sol`, `test/StreamCuratorsPool.t.sol`, `test/StreamPaymentsInvariant.t.sol` | Passing for current first-party surfaces: `StreamAdmins.emergencyRecipient()` is the explicit surplus recipient, `StreamMinter`, `StreamAuctions`, and `StreamCuratorsPool` use it for positive surplus withdrawal, `NextGenRandomizerRNG` exposes zero emergency-withdrawable reserve, unauthorized emergency withdrawals revert without transfer, and payment/reserve tests cover poster, bidder, curator, active-bid escrow, and randomizer reserve boundaries. Sequence fuzzing now covers emergency controls against mixed payment operations. Dedicated signer-manager and deployment emergency runbooks remain future work | [`P0-ADMIN-002`](https://github.com/6529-Collections/6529Stream/issues/35), [`P0-PAY-007`](https://github.com/6529-Collections/6529Stream/issues/31), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C/Gate D | TBD |
| Randomness request lifecycle | Request records expose token, collection, provider, request ID, epoch, state, request time, and fulfillment time | `test/StreamRandomizerLifecycle.t.sol` | Passing for VRF and arRNG request records, request state, request-to-token, token-to-request, token-to-collection, first-class token-level request/state views, empty token lookup, token-level stale lookup, requested block/time, fulfilled block/time, and derived seed storage | [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37), [`P0-RAND-002`](https://github.com/6529-Collections/6529Stream/issues/38) | Gate C | TBD |
| Randomizer callback validation | Valid fulfillment accepts only the stored request ID, token, collection, provider, and randomizer epoch | `test/StreamRandomizerLifecycle.t.sol` | Passing for VRF/arRNG valid fulfillment, unknown request, zero arRNG request ID, empty output, duplicate fulfillment, core token-to-collection mismatch, live provider/epoch validation, and reentrant arRNG request-submission rejection | [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37), [`P0-RAND-003`](https://github.com/6529-Collections/6529Stream/issues/39) | Gate C | TBD |
| Randomizer stale callback | Replaced randomizer or stale-epoch fulfillment rejected | `test/StreamRandomizerLifecycle.t.sol` | Passing for stale epoch rejection, admin-marked stale requests, old-provider callback rejection after explicit stale marking, and duplicate old-provider callbacks after fulfillment | [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37), [`P0-RAND-003`](https://github.com/6529-Collections/6529Stream/issues/39), [`P0-RAND-005`](https://github.com/6529-Collections/6529Stream/issues/41) | Gate C | TBD |
| Randomness lifecycle states | Pending, fulfilled, stale, and failed post-processing states drive metadata and views | `test/StreamRandomizerLifecycle.t.sol` | Passing for lifecycle state coverage: pending, fulfilled, stale, and failed post-processing states are observable by request and token where applicable; VRF and arRNG adapters catch deterministic core hash-writing failures, record `FailedPostProcessing`, store the derived seed and failure-data hash, clear pending counts, emit a failure event with provider and epoch context, and reject duplicate callbacks. Metadata integration remains Gate D work. | [`P0-RAND-004`](https://github.com/6529-Collections/6529Stream/issues/40) | Gate C/Gate D | TBD |
| Randomizer migration | Provider migration with pending requests is blocked or explicitly marks affected requests stale according to ADR 0005 | `test/StreamRandomizerLifecycle.t.sol`, later `test/StreamRandomizerMigration.t.sol` | Passing for default block-by-pending policy: VRF and arRNG adapters expose lifecycle-aware pending counts; `StreamCore.addRandomizer` rejects migration while pending requests exist; fulfilled and stale requests clear pending counts; migration with no pending requests emits the provider/epoch event; a new provider can request and fulfill after migration. Automatic bulk stale marking remains future incident tooling. | [`P0-RAND-005`](https://github.com/6529-Collections/6529Stream/issues/41) | Gate C | TBD |
| Randomness retry | Manual retry reprocesses the same provider output and cannot redraw randomness | `test/StreamRandomizerRetry.t.sol` | Passing for bounded deterministic retry: VRF and arRNG adapters expose admin-gated `retryRandomnessPostProcessing`, retry only `FailedPostProcessing` requests, reuse the stored derived seed, emit retry success/failure and fulfillment events without duplicating the initial failure event on retry failure, refresh fulfillment timing on retry success, preserve token/collection/provider/epoch binding validation, reject unauthorized callers and terminal fulfilled requests, and cap repeated failed attempts with `MAX_RANDOMNESS_POST_PROCESSING_RETRIES` | [`P0-RAND-006`](https://github.com/6529-Collections/6529Stream/issues/42) | Gate C | TBD |
| Randomness seed storage | Derived seed/hash includes `RANDOMNESS_SEED_TYPEHASH`, provider, request ID, collection, token, randomizer epoch, and raw-output hash | `test/StreamRandomizerLifecycle.t.sol`, `test/StreamRandomizerRetry.t.sol` | Passing: VRF and arRNG adapters store `rawOutputHash = keccak256(abi.encode(randomWords))`, derive the token seed from `RANDOMNESS_SEED_TYPEHASH`, provider, request ID, collection, token, randomizer epoch, and raw-output hash, expose both values in request/token views and lifecycle interface views, emit both values in fulfillment/failure/retry events, emit provider-specific raw-word fulfillment events for off-chain auditability, avoid storing full provider word arrays, and prove post-request token-data mutation cannot bias the seed | [`P0-RAND-007`](https://github.com/6529-Collections/6529Stream/issues/43) | Gate C | TBD |
| Weak helper randomness | `RandomizerNXT` and `XRandoms` are removed, test/demo-scoped, or impossible to configure for production drops | `test/StreamRandomizerLifecycle.t.sol` | Passing: `RandomizerNXT.isRandomizerContract()` returns false, `StreamCore.addRandomizer` rejects it for production collections, and the concrete `XRandoms` helper contract was removed from production source; Slither now reports `weak-prng=0` | [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14), [`P0-RAND-008`](https://github.com/6529-Collections/6529Stream/issues/73) | Gate C/Gate F | TBD |
| Pending randomness metadata | Off-chain and on-chain `tokenURI` pending/final behavior is deterministic and never treats zero hash as finalized randomness | `test/StreamMetadataGolden.t.sol`, later `test/StreamMetadata.t.sol` | Passing for schema-v1 coverage: off-chain pending/final URIs match fixtures, on-chain pending output returns base64 JSON with `metadata_state: "pending"` and no final animation HTML, and on-chain final output returns base64 JSON with `metadata_state: "final"` and the animation URL. Stale-state display remains future metadata/randomness work. | [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45), [`P1-META-001`](https://github.com/6529-Collections/6529Stream/issues/46), [`P0-RAND-004`](https://github.com/6529-Collections/6529Stream/issues/40) | Gate C/Gate D | TBD |
| Metadata schema golden files | Off-chain URI rules, on-chain pending JSON, on-chain final JSON, and generated HTML remain deterministic under the accepted schema | `test/StreamMetadataGolden.t.sol` | Passing for current schema-v1 slice: `offchain-pending-token-uri.txt`, `offchain-final-token-uri.txt`, `onchain-pending-schema-v1-token-uri.txt`, and `onchain-final-schema-v1-token-uri.txt` lock output, and `metadataSchemaVersion()` plus `tokenMetadataState(tokenId)` expose the active schema and state. Escaping and stale-state display remain future P1-META work. | [`P1-META-001`](https://github.com/6529-Collections/6529Stream/issues/46) | Gate D | TBD |
| Metadata escaping and render safety | JSON, HTML, JavaScript, raw attributes, URI, and size-limit inputs are escaped, validated, or rejected | `test/StreamMetadataEscaping.t.sol`, `test/StreamMetadataSizeLimits.t.sol` | Partial: on-chain JSON string fields are escaped for schema-v1 output; raw attribute fragments reject literal control characters, unterminated strings, unbalanced delimiters, and unquoted array/object breakout attempts; decoded metadata is parser-checked for hostile collection/image strings; final animation HTML is decoded to assert library-attribute escaping, escaped `tokenData` and dependency-script JavaScript string embedding, and closing-script neutralization; numeric byte caps are enforced for collection display fields, collection scripts, token data, token images, token attributes, generated `tokenURI` output, dependency scripts, and dependency provenance. Remaining work: semantic attribute schema validation or structured attributes, URI policy, invalid UTF-8 policy, and browser render-sandbox tests. | [`P1-META-006`](https://github.com/6529-Collections/6529Stream/issues/51) | Gate D | TBD |
| Collection freeze boundary | Frozen collections cannot mutate collection fields, base URI, metadata mode, scripts, dependency references, token data, image, attributes, final supply, or live-token metadata state | `test/StreamMetadataFreeze.t.sol` | Passing for current `StreamCore` boundary: freeze requires ended minting, elapsed final-supply delay, and final live-token metadata; stores and exposes `collectionFreezeManifestHash`; emits `CollectionFrozen`; finalizes supply to minted-ever count; tightens the reserved max token ID; blocks dependency-registry swaps while any collection is frozen; and rejects current metadata-significant writes after freeze. Dependency version pins are included in the freeze manifest; escaping and richer invariant/fork coverage remain future P1-META work. | [`P1-META-002`](https://github.com/6529-Collections/6529Stream/issues/47) | Gate D | TBD |
| Dependency registry immutability | Dependency versions are immutable, pinned by key/version/content hash/registry address, and cannot change frozen collection output | `test/StreamDependencyRegistry.t.sol` | Passing: registry writes create new immutable versions, chunk-index updates derive a new version without mutating the previous one, version records expose typed content hash/provenance/creator/creation/deprecation views, collection metadata pins key/version/content hash/registry address, explicit repinning moves an unfrozen collection to the latest dependency in the current registry, output and freeze manifests stay stable after later registry versions or registry swaps until explicit repin, and segment-boundary hashes remain distinct in `test/StreamMetadataEncoding.t.sol`. Dependency artifact packaging and migration runbooks remain future operational work. | [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48) | Gate D | TBD |
| ERC-4906 metadata signaling | `supportsInterface(0x49064906)` succeeds and `MetadataUpdate` / `BatchMetadataUpdate` emit from metadata write paths that can change token JSON | `test/StreamMetadataEvents.t.sol` | Passing for current `StreamCore` behavior: ERC-4906 interface support succeeds, randomness fulfillment and token metadata input writes emit `MetadataUpdate`, collection-level metadata mode/base URI/display/script/dependency-reference writes emit `BatchMetadataUpdate` over the minted-ever range, empty collections do not emit empty batch events, and mint-only plus burn paths do not emit ERC-4906. Dependency registry version creation does not emit ERC-4906 for pinned collections because their output does not change; explicit repinning goes through `updateCollectionInfo` and emits the existing collection-range update. | [`P1-META-004`](https://github.com/6529-Collections/6529Stream/issues/49), [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48) | Gate D | TBD |
| Dependency script packed encoding | Dependency script retrieval uses safe typed concatenation/hash encoding and cannot collide across script segments | `test/StreamMetadataEncoding.t.sol` | Passing: typed chunk/content hashes include dependency key, chunk count, chunk index, chunk byte length, and chunk content hash; ambiguous chunk splits that render the same JavaScript produce distinct content hashes while preserving rendered-script compatibility; zero-chunk dependency hashes are deterministic | [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9), [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48) | Gate C/Gate D | TBD |
| Deployment redeployment rehearsal | Deployment manifests, broadcast-derived manifest inputs, address books, ABI hashes, source verification inputs, admin ceremony, signer setup, deprecation checks, and emergency redeployment rehearsal follow ADR 0007 | `test/StreamDeploymentManifest.t.sol`, `script/RehearseDeployment.s.sol`, `scripts/generate_release_artifacts.py`, `scripts/test_release_artifacts.py`, `scripts/generate_source_verification_inputs.py`, `scripts/test_source_verification_inputs.py`, `scripts/check_abi_compatibility.py`, `scripts/test_abi_compatibility.py`, `scripts/generate_broadcast_manifest_input.py`, `scripts/test_broadcast_manifest_input.py`, `scripts/generate_deployment_manifest.py`, `scripts/test_deployment_manifest.py`, `scripts/generate_address_books.py`, `scripts/test_address_books.py`, `scripts/generate_release_manifest.py`, `scripts/test_release_manifest.py`, `scripts/generate_release_checksums.py`, and `scripts/test_release_checksums.py` | In Progress: local deploy-and-wire rehearsal, Safe-placeholder ownership transfer, temporary admin revocation, manifest schema/example parsing, generated Anvil manifest config/example, sanitized Foundry broadcast fixture ingestion, generated broadcast-derived manifest config/example, generated local and broadcast-derived address books, deterministic source verification input bundle, deterministic top-level release manifest, deterministic manifest checksum, generated ABI/bytecode checksum baseline, generated interface ID catalog, generated event topic catalog, ABI compatibility baseline, signable checksum bundle, and default check-script gate added; live fork rehearsal, production broadcast retention, production address books, live explorer verification, dry-run mint/auction ceremonies, detached checksum signatures, and emergency redeployment rehearsal remain open | [`P2-UPGRADE-ADR`](https://github.com/6529-Collections/6529Stream/issues/53), [`P1-DEPLOY-002`](https://github.com/6529-Collections/6529Stream/issues/91), [`P1-RELEASE-001`](https://github.com/6529-Collections/6529Stream/issues/93), [`P1-RELEASE-002`](https://github.com/6529-Collections/6529Stream/issues/97), [`P1-DEPLOY-003`](https://github.com/6529-Collections/6529Stream/issues/95), [`P1-RELEASE-003`](https://github.com/6529-Collections/6529Stream/issues/99), [`P1-RELEASE-004`](https://github.com/6529-Collections/6529Stream/issues/101), [`P1-RELEASE-006`](https://github.com/6529-Collections/6529Stream/issues/105), [`P1-RELEASE-007`](https://github.com/6529-Collections/6529Stream/issues/107), [`P1-DEPLOY-004`](https://github.com/6529-Collections/6529Stream/issues/109) | Gate E/Gate G | TBD |
| Release artifact catalog | ABI checksums, bytecode checksums, standard/custom interface IDs, event topics, source verification inputs, broadcast-derived manifest inputs, ABI compatibility, address books, machine-readable release manifest, signable checksum files, and release-impact changelog policy are generated or checked deterministically from current Foundry/deployment artifacts | `scripts/generate_release_artifacts.py`, `scripts/test_release_artifacts.py`, `scripts/generate_source_verification_inputs.py`, `scripts/test_source_verification_inputs.py`, `scripts/check_abi_compatibility.py`, `scripts/test_abi_compatibility.py`, `scripts/generate_broadcast_manifest_input.py`, `scripts/test_broadcast_manifest_input.py`, `scripts/generate_deployment_manifest.py`, `scripts/test_deployment_manifest.py`, `scripts/generate_address_books.py`, `scripts/test_address_books.py`, `scripts/generate_release_manifest.py`, `scripts/test_release_manifest.py`, `scripts/generate_release_checksums.py`, `scripts/test_release_checksums.py`, `scripts/check_changelog.py`, `scripts/test_changelog_check.py`, `release-artifacts/latest/`, `release-artifacts/latest/source-verification-inputs.json`, `release-artifacts/latest/release-manifest.json`, `release-artifacts/baselines/v0.1.0/abi-surface.json`, `deployments/broadcasts/`, `deployments/address-books/`, `CHANGELOG.md`, and `docs/release-policy.md` | In Progress locally for the deterministic Gate G baseline: generator self-tests cover ABI hashing, bytecode hashing, event topic generation, configured standard interface IDs, computed selector XOR traceability, and drift detection; source-verification self-tests cover deterministic generation, check-mode drift, missing source/artifact errors, linked-bytecode reporting, constructor ABI retention, verification command templates, and ABI checksum mismatches; ABI compatibility self-tests cover compatible, additive, removed, changed, missing-contract, and check-mode drift cases; broadcast-ingestion self-tests cover deterministic generation, check-mode drift, wrong-chain broadcasts, missing/unexpected deployments, failed receipts, boolean receipt status rejection, receipt address mismatch, duplicate deployment names, and secret-like key rejection; address-book self-tests cover deterministic generation, drift detection, missing output directories, duplicate/invalid addresses, `source_dirty`, chain ID, lifecycle state, git commit, verification status, hash-format validation, missing metadata, missing release contracts, and unknown contracts; release-manifest self-tests cover deterministic generation, check-mode drift, missing required artifacts, required JSON schema versions, governance-doc hashing, release/deployment/broadcast metadata, source-verification coverage, and explicit checksum-bundle self-reference policy; checksum-bundle self-tests cover deterministic generation, sorted SHA256SUMS output, manifest coverage, self-reference exclusion, drift detection, deleted covered files, missing generated outputs, and missing covered roots; changelog self-tests cover release-impacting path detection, missing changelog edits, missing `Unreleased`, placeholder entries, and valid release notes. Detached checksum signatures, signed tags, production address books, live explorer verification, and verified live deployment hashes remain future Gate G work | [`P1-RELEASE-001`](https://github.com/6529-Collections/6529Stream/issues/93), [`P1-RELEASE-002`](https://github.com/6529-Collections/6529Stream/issues/97), [`P1-RELEASE-003`](https://github.com/6529-Collections/6529Stream/issues/99), [`P1-RELEASE-004`](https://github.com/6529-Collections/6529Stream/issues/101), [`P1-RELEASE-005`](https://github.com/6529-Collections/6529Stream/issues/103), [`P1-RELEASE-006`](https://github.com/6529-Collections/6529Stream/issues/105), [`P1-RELEASE-007`](https://github.com/6529-Collections/6529Stream/issues/107), [`P1-DEPLOY-004`](https://github.com/6529-Collections/6529Stream/issues/109) | Gate G | TBD |
| Mint-accounting state | Dead counters are removed or retained counters initialize and update according to the accepted drop/mint accounting design | `test/StreamMintAccounting.t.sol` | Passing: removed never-written public/allowlist mint-count mappings and retrieval APIs; retained airdrop counter starts at zero, increments on authorized minter calls, and remains unchanged on unauthorized mint attempts | [`P0-CORE-001`](https://github.com/6529-Collections/6529Stream/issues/13) | Gate C | TBD |
| Uninitialized local findings | First-party default-local behavior is explicit, removed, or covered by targeted regressions | `test/StreamInitialization.t.sol` | Passing: Bytes32 character counts, missing/matching delegation lookups, subdelegation register/revoke gates, empty-script generative rendering, and multi-recipient minter return indexes cover the remaining first-party production rows; Slither now reports only one accepted test-only `uninitialized-local` row | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| Vendored library Slither findings | Retained OpenZeppelin utility files have provenance, local delta notes, and regressions for flagged math/encoding behavior | `test/StreamVendoredLibraries.t.sol` | Passing: Base64 golden/padding vectors, `Math.mulDiv` full-precision boundaries, rounding-up behavior, overflow, and zero-denominator reverts cover the current vendored false-positive rows | [`P0-LIB-001`](https://github.com/6529-Collections/6529Stream/issues/11) | Gate F | TBD |
| Curator double claim | Valid claim succeeds once and second claim fails | `test/StreamCuratorsPool.t.sol` | Passing for P0-PAY-005: valid claims create credits and duplicate claims fail without increasing credit | [`P0-PAY-005`](https://github.com/6529-Collections/6529Stream/issues/29) | Gate C/Gate D | TBD |
| Merkle leaf ambiguity | Duplicate or ambiguous leaves cannot double claim | `test/StreamCuratorsPool.t.sol` | In Progress: reward leaves use `abi.encode`-based hashing for reward address, collection ID, and amount; root epoch/domain expansion remains future curator metadata work | [`P0-PAY-005`](https://github.com/6529-Collections/6529Stream/issues/29), `P1-CURATOR-*` | Gate D | TBD |
| Burn accounting | Burned-token supply, unavailable `tokenURI`, retained audit state, terminal token IDs, and callback-after-burn behavior follow ADR 0006 | `test/StreamCoreBurn.t.sol` | Passing: burn emits the ERC-721 transfer-to-zero event and `TokenBurned`, removes owner/`tokenURI`/`tokenMetadataState` availability, decrements live global and collection supply, increments `burnAmount`, rejects remint attempts for previously burned token IDs, retains token-to-collection/hash audit state, exposes `isTokenBurned` and `burnedTokenAuditState`, records valid VRF and arRNG post-burn randomness through `BurnedTokenRandomnessRecorded`, emits no ERC-4906 metadata updates for burn/post-burn fulfillment, and proves a valid post-burn VRF callback after collection freeze does not alter the frozen manifest. | [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45), [`P1-META-005`](https://github.com/6529-Collections/6529Stream/issues/50), [`P0-RAND-004`](https://github.com/6529-Collections/6529Stream/issues/40) | Gate D | TBD |
| Forced ETH accounting | Forced/direct ETH does not corrupt owed/surplus accounting | `test/StreamAuctionPayments.t.sol`, `test/StreamFixedPricePayments.t.sol`, `test/StreamCuratorsPool.t.sol`, `test/StreamEmergencyWithdraw.t.sol`, `test/StreamPaymentsInvariant.t.sol` | Passing for current first-party local accounting: direct and forced ETH regressions cover auction, fixed-price drops, curator pool, StreamMinter, and NextGenRandomizerRNG local accounting; bounded sequence fuzzing now injects deterministic forced-balance surplus between mixed operations and proves owed totals, reserves, balance coverage, and emergency-withdrawable surplus stay coherent. | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C/Gate D | TBD |

## Appendix C: ADR Index

| ADR | Issue | Status | File | Blocks |
| --- | --- | --- | --- | --- |
| 0001 Drop authorization | [`P0-AUTH-ADR`](https://github.com/6529-Collections/6529Stream/issues/17) | Accepted | `docs/adr/0001-drop-authorization.md` | Gate B1, `P0-AUTH-*` |
| 0002 Auction custody | [`P0-AUCT-ADR`](https://github.com/6529-Collections/6529Stream/issues/21) | Accepted | `docs/adr/0002-auction-custody.md` | Gate B1, `P0-AUCT-*` |
| 0003 Payment accounting | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24) | Accepted | `docs/adr/0003-payment-accounting.md` | Gate B1, `P0-PAY-*` |
| 0004 Admin/governance | [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33) | Accepted | `docs/adr/0004-admin-governance.md` | Gate B1, `P0-ADMIN-*` |
| 0005 Randomness | [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14) | Accepted | `docs/adr/0005-randomness.md` | Gate B1, `P0-RAND-*` |
| 0006 Metadata/freeze | [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45) | Accepted | `docs/adr/0006-metadata-freeze.md` | Gate B2, [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9), `P1-META-*` |
| 0007 Upgrade/redeployment | [`P2-UPGRADE-ADR`](https://github.com/6529-Collections/6529Stream/issues/53) | Accepted | `docs/adr/0007-upgrade-redeployment.md` | Gate B2, deployment/release |

## Appendix D: Issue Template

    ## Problem

    ## Current behavior

    ## Intended behavior

    ## Priority / severity / work type
    - Priority:
    - Severity:
    - Work type:
    - Blocks:

    ## Dependencies
    - ADRs:
    - Other issues:

    ## Implementation requirements

    ## Acceptance criteria

    ## Required tests
    - Happy path:
    - Negative:
    - Adversarial:
    - Invariant/fuzz:
    - Event assertions:

    ## Required docs

    ## Non-goals

    ## Reviewer checklist
    - Security reviewer:
    - Protocol reviewer:
    - Test reviewer:
    - Docs reviewer:

## Appendix E: Known Baseline Commands

```bash
forge build
forge test -vvv
forge fmt --check smart-contracts
slither . --foundry-compile-all
```

Do not claim a fixed passing test count in docs until meaningful tests exist.
Prefer CI status or commands users can run locally.
