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
- Known P0 blockers include ad hoc drop authorization, auction custody
  ambiguity, auction reentrancy, push payments, untriaged static analysis
  findings, missing tests, and missing deployment discipline.
- Public docs must describe actual on-chain behavior, not intended product
  behavior.

### Verification Metadata

| Field | Value |
| --- | --- |
| Last verified | TBD |
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
| Unit/integration tests | Initial characterization tests cover admin guards, current drop behavior, fixed-price payout behavior, and randomness/pending metadata behavior; broader P0/P1 tests are missing | `forge test -vvv` | P0 regression and integration suite exists |
| Formatting | Fails broadly | `forge fmt --check smart-contracts` | Passing, or vendored exclusions documented |
| Static analysis | Runs with a tracked but unaccepted baseline: 530 total findings, including 13 High and 26 Medium | `slither . --config-file slither.config.json --foundry-compile-all` and `ops/SLITHER_BASELINE.md` | High/medium findings fixed, accepted, or documented |
| Deployment | Missing | no meaningful `script/`/manifest process | Anvil deployment and fork rehearsal pass |
| Docs | Partial README and roadmap only | manual inspection | Architecture, security, deployment, and protocol docs merged |
| Release artifacts | Missing | no ABI/address/manifest release process | ABIs, manifests, checksums, and verified addresses published |
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
- Initial characterization tests cover current fixed-price drop, auction
  creation, admin guard, payout, and randomness behavior enough to detect
  accidental regressions.

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

Status: Not Started.
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

Status: Not Started.
Owner: TBD.
Blocking issues: TBD.
Evidence: TBD.

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

Status: Not Started.
Owner: TBD.
Blocking issues: TBD.
Evidence: TBD.

Exit criteria:

- Foundry deployment scripts exist.
- Anvil deployment rehearsal passes.
- Fork deployment dry run passes.
- Deployment manifest generated.
- Post-deploy admin, signer, randomizer, dependency, curator, and auction wiring
  verified.
- Contract verification inputs retained.

Required evidence:

- Deployment command transcript.
- Generated manifest.
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
- ABIs, address books, deployment manifests, checksums, and verified contract
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
20. [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37) / P0/CODE+TEST+DOCS: Harden randomizer callbacks.
21. `P1/TEST`: Add first invariant suite.
22. `P1/DOCS`: Add protocol spec and threat model.
23. `P2/OPS`: Add deployment scripts and manifest schema.

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
  `smart-contracts/StreamDrops.sol`; ERC-1271 contract signer support remains
  `P0-AUTH-003`.

Problem:

- Previous drop IDs were built with string concatenation and `abi.encodePacked`.
  Authorization needed a robust typed domain, nonce/deadline model, and
  storage-backed replay protection.

Current behavior:

- Drop authorization now accepts `DropAuthorization` EIP-712 typed data, validates
  an EOA signature from the configured signer, consumes the derived `dropId`, and
  rejects contract signers until ERC-1271 support lands.

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
- Reject contract signers explicitly until `P0-AUTH-003` adds ERC-1271.
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
- Contract signer path rejects explicitly until `P0-AUTH-003`.

Required docs:

- EIP-712 schema.
- Nonce/drop ID policy.
- Signer rotation policy.
- Example payload fixtures.
- ERC-1271 limitation until `P0-AUTH-003`.

Acceptance criteria:

- EIP-712 domain includes name, version, chain ID, and verifying contract.
- Replay protection is backed by consumed-state storage.
- EOA signatures pass.
- EIP-2098 compact signatures pass.
- Wrong signer, wrong domain, wrong chain, wrong verifying contract, expired,
  replayed, cancelled, stale-epoch, malleable, bad-quantity, bad-payer, and
  zero-recovered-signer authorizations fail.
- Token data substitution fails.
- Contract signers fail with an explicit pending-ERC-1271 policy until
  `P0-AUTH-003`.
- Legacy packed authorization helper and old `mintDrop` ABI are removed.
- All required negative tests pass.

### P0-AUTH-003: Decide And Implement ERC-1271 Support

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Dependencies: `P0-AUTH-ADR`.

Problem:

- The roadmap requires contract wallet execution, but contract wallet signing is
  a separate decision. Safe/DAO/smart-wallet signers need ERC-1271 validation.

Current behavior:

- No explicit ERC-1271 signature validation policy.

Intended behavior:

- Contract signers either work via ERC-1271 or are explicitly out of scope for
  the first release.

Required code changes:

- If supported, call `isValidSignature(hash, signature)` when the signer is a
  contract.
- If not supported, reject contract signers with a specific error and document
  the limitation.

Required tests:

- ERC-1271 mock signer success if supported.
- ERC-1271 invalid magic value failure if supported.
- Contract signer rejected if out of scope.
- EOA signing remains unaffected.

Required docs:

- Contract signer policy.
- Safe/DAO signing example if supported.

Acceptance criteria:

- ERC-1271 signatures pass or are explicitly out of scope.
- Behavior is tested and documented.

### P0-AUCT-001: Formalize Auction Custody And State Machine

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [#22](https://github.com/6529-Collections/6529Stream/issues/22).
- Dependencies: [`P0-AUCT-ADR`](https://github.com/6529-Collections/6529Stream/issues/21), ADR 0002.

Problem:

- Auction settlement can fail if the auction contract lacks custody or approval
  for the token.

Current behavior:

- Auction minting and settlement imply token transfer authority that is not
  guaranteed end to end.

Intended behavior:

- Auction token custody is known at all times.
- Settlement ownership semantics are explicit for bid and no-bid cases.

Required code changes:

- Implement or document custody strategy: escrow by auction contract, dedicated
  custody address, or tested approval flow.
- Define whether cancellation exists before first bid, after first bid, or never.
- If approval-based custody is chosen, define whether seller/poster approval
  revocation can grief settlement and how the protocol prevents or surfaces it.
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

Required tests:

- Auction created.
- Token custody verified.
- Successful bid settlement.
- No-bid settlement.
- Cancellation behavior before first bid, after first bid, or rejection if no
  cancellation exists.
- Transfer approval failure.
- Approval revocation after auction creation if approval-based custody is chosen.
- Reverting ERC721 receiver.
- Repeated settlement attempt.
- Post-claim bid failure.

Required docs:

- `docs/auction-custody.md`.
- State-machine diagram.
- Event catalog.

Acceptance criteria:

- Auction token custody is known and asserted in tests.
- Settlement is idempotent.
- Failed NFT transfer cannot trap ETH or mark settlement complete.
- Implementation matches `docs/adr/0002-auction-custody.md`.

### P0-AUCT-002: Fix Auction Bidding Reentrancy And Refunds

- Priority/severity/type: `P0 / Critical / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [#12](https://github.com/6529-Collections/6529Stream/issues/12).
- Dependencies: [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), ADR 0002.

Problem:

- Outbid refunds use push `call` before bid state is fully updated, creating
  reentrancy and denial-of-service risk.

Current behavior:

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
  Add credit ledger storage and total-owed views.
- [`P0-PAY-003`](https://github.com/6529-Collections/6529Stream/issues/27):
  Convert fixed-price poster/platform payouts to credits.
- [`P0-PAY-004`](https://github.com/6529-Collections/6529Stream/issues/28):
  Convert auction outbid refunds to credits.
- [`P0-PAY-005`](https://github.com/6529-Collections/6529Stream/issues/29):
  Convert curator reward claims to credits.
- [`P0-PAY-006`](https://github.com/6529-Collections/6529Stream/issues/30):
  Add withdrawal functions and failed-withdrawal behavior.
- [`P0-PAY-007`](https://github.com/6529-Collections/6529Stream/issues/31):
  Bound emergency withdrawals by surplus.
- [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8):
  Add payment invariants and forced-ETH tests.

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

### P0-ADMIN-001: Fix Admin Selector And Permission Model

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34).
- Dependencies: [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33).

Problem:

- Function-level permissions can be misapplied when modifiers use the wrong
  selector. Collection admin permissions exist but are not consistently
  enforced.

Current behavior:

- `StreamCore.setCollectionData` is gated by
  `this.changeMetadataView.selector`.
- `StreamCore.updateCollectionInfo` is gated by
  `this.changeMetadataView.selector`; if this grouping is intended, the target
  implementation must replace it with an explicit named metadata role and tests.
- `StreamCuratorsPool.setMultipleMerkleRoots` is gated by
  `this.setMerkleRoot.selector`.
- Function-admin grants are keyed by address and selector only, not by target
  contract and selector.
- `IStreamAdmins` exposes collection-admin retrieval, but the implementation
  does not provide collection-admin storage or behavior.
- `StreamAdmins.tdhSigner` has no rotation path, so the current admin registrar
  can become stuck if the key is lost or compromised.

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
- Define global, function, collection, signer, guardian/pause, and owner roles.
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
- Signer lifecycle and cancellation controls match ADR 0004.
- Deployer has no lasting production authority after the admin ceremony.

### P0-ADMIN-002: Define Pause And Emergency Controls

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS+OPS`.
- Blocks: Gate C.
- Issue: [`P0-ADMIN-002`](https://github.com/6529-Collections/6529Stream/issues/35).
- Dependencies: [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33), [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24).

Problem:

- The roadmap mentions emergency withdrawals and runbooks, but does not define
  pause/guardian controls.

Current behavior:

- No clear pause policy for minting, bidding, settlement, withdrawals, or drop
  execution.
- Emergency withdrawals send full contract balances to `adminsContract.owner()`
  without proving owed/reserved balances are protected.

Intended behavior:

- Emergency response controls are explicit, minimal, monitored, and tested.
- Pause controls are domain-scoped and do not silently block unrelated flows.
- Emergency withdrawals are surplus-only according to ADR 0003.

Required code changes:

- Decide whether to add pause controls for minting, bidding, settlement,
  withdrawals, drop execution, and metadata mutation.
- If added, define who can pause, who can unpause, and whether pause actions are
  immediate or delayed.
- Ensure user withdrawals are paused only if explicitly accepted.
- Pause events should include scope: mint, bid, settlement, withdrawal, drop
  execution, or metadata.
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
- Pause behavior tested and monitored.
- Withdrawal pause, if implemented, is temporary, evented, and cannot erase
  credits.
- Emergency controls are bounded by `emergencyWithdrawable()` or equivalent
  surplus views.

### P0-RAND-001: Harden Randomizer Requests And Callbacks

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Issue: [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37).
- Dependencies: [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14), [ADR 0005](../docs/adr/0005-randomness.md), ADR 0003, ADR 0004.

Problem:

- Randomness callback validation and pending/failure states are not strong enough
  for production drops.

Current behavior:

- Randomizer adapters set token hashes with limited request lifecycle tracking.
- `StreamCore.setTokenHash` only checks the caller is the current collection
  randomizer and the token hash is still zero.
- `_safeMint` runs before `calculateTokenHash`, so receivers and indexers can
  observe a minted token while randomness is pending.
- Off-chain metadata returns a `pending` URI while the hash is zero; on-chain
  metadata currently embeds the zero hash directly.
- VRF and arRNG adapters keep provider-specific request mappings, but there is
  no canonical protocol request state, provider epoch, stale callback state, or
  callback-after-burn policy.
- `RandomizerNXT` and `XRandoms` use block-derived helper randomness that is
  out of production scope under ADR 0005.

Intended behavior:

- Fulfillment validates request ID, token, collection, and randomizer epoch.
- Pending and failed randomness are explicit states.
- Production drops use provider-backed async randomness only.
- Provider migration is observable and cannot silently fulfill stale requests.

Required code changes:

- Store `requestId => tokenId/collectionId/randomizerEpoch`.
- Fulfill by request ID, not arrival order.
- Reject stale callbacks from replaced randomizers.
- Reject duplicate fulfillments.
- Define whether fulfillment stores raw random words, derived token hash, or
  both.
- Define whether randomizer migration can happen while requests are pending.
- Record failed or stale post-processing for retry by a separate function if
  needed.
- Add a bounded manual-retry path only for deterministic post-processing
  failures, not for changing random output.
- Do not allow user-significant inputs after randomness request.
- Expose request lifecycle views by request ID and token ID.
- Emit request, fulfillment, stale, failure, retry, provider-update, and
  epoch-update events.
- Remove, isolate, or disable weak helper randomness for production deployment
  paths.
- Bind provider fees, refunds, and adapter balances to ADR 0003 reserve and
  surplus accounting.

Child tickets:

- [`P0-RAND-002`](https://github.com/6529-Collections/6529Stream/issues/38):
  Add request lifecycle storage and views.
- [`P0-RAND-003`](https://github.com/6529-Collections/6529Stream/issues/39):
  Add callback validation for request, token, collection, and randomizer epoch.
- [`P0-RAND-004`](https://github.com/6529-Collections/6529Stream/issues/40):
  Add pending, fulfilled, stale, and failed post-processing states.
- [`P0-RAND-005`](https://github.com/6529-Collections/6529Stream/issues/41):
  Define and test randomizer migration with pending requests.
- [`P0-RAND-006`](https://github.com/6529-Collections/6529Stream/issues/42):
  Add bounded manual retry for deterministic post-processing failures.
- [`P0-RAND-007`](https://github.com/6529-Collections/6529Stream/issues/43):
  Implement raw random words versus derived hash storage policy.

Required tests:

- Pending metadata.
- Fulfilled metadata.
- Duplicate fulfillment fails.
- Stale callback fails.
- Replaced randomizer callback fails.
- Randomizer migration with pending requests follows ADR.
- Manual retry cannot change random output.
- Callback after burn follows ADR behavior.
- Fulfillment does not revert in normal operation.
- Unknown request ID fails.
- Wrong provider fails.
- Wrong token fails.
- Wrong collection fails.
- Wrong randomizer epoch fails.
- Zero derived seed/hash fails.
- Weak helper randomizer cannot be configured for production collections or is
  fully outside production scope.
- Randomness reserves are not emergency-withdrawable surplus.

Required docs:

- Randomness lifecycle docs.
- Provider configuration docs.
- Stuck request runbook.
- Deployment manifest policy for production-eligible randomizers.
- Slither baseline update after `weak-prng` rows are fixed, scoped, or accepted
  with proof.

Acceptance criteria:

- Randomizer fulfillment validates request ID, token, collection, and randomizer
  epoch.
- Pending and failed states are documented.
- A valid provider callback produces exactly one terminal seed/hash.
- Unknown, duplicate, stale, wrong-provider, wrong-token, wrong-collection, and
  wrong-epoch callbacks fail with asserted custom errors.
- Fulfillment cannot finalize a zero derived seed/hash.
- Pending/final metadata behavior is explicit for both off-chain and on-chain
  metadata.
- Provider migration increments a collection-level randomizer epoch or stricter
  equivalent.
- Existing pending requests cannot be silently fulfilled by a replacement
  provider.
- Manual retry can only retry deterministic post-processing using the same
  provider output.
- `RandomizerNXT` and `XRandoms` are removed from production paths, moved to
  test/demo scope, or otherwise made impossible to configure for production
  drops.
- Provider fee refunds and adapter balances are covered by ADR 0003 reserve and
  emergency-withdrawable tests.

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
- Define burned-token metadata behavior.
- Decide whether token data, hash, image, and attributes are retained after burn.
- Decide whether burned tokens count toward final supply.

### Metadata, Scripts, And Dependency Registry

- Accept [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45)
  before metadata schema, freeze, dependency, burn, or ERC-4906 implementation.
- Resolve [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9)
  before any production dependency-script output depends on dynamic chunk
  composition.
- Implement [`P1-META-001`](https://github.com/6529-Collections/6529Stream/issues/46):
  metadata schema and golden-file tests.
- Implement [`P1-META-002`](https://github.com/6529-Collections/6529Stream/issues/47):
  collection freeze boundaries and immutable metadata state.
- Implement [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48):
  dependency registry versioning, immutability, and provenance.
- Implement [`P1-META-004`](https://github.com/6529-Collections/6529Stream/issues/49):
  ERC-4906 support and metadata update signaling.
- Implement [`P1-META-005`](https://github.com/6529-Collections/6529Stream/issues/50):
  burn metadata and supply semantics.
- Implement [`P1-META-006`](https://github.com/6529-Collections/6529Stream/issues/51):
  metadata escaping, size limits, and render-sandbox tests.
- Add metadata schema and golden-file tests for `name`, `description`, `image`,
  `attributes`, and `animation_url`.
- Escape quotes, backslashes, brackets, control characters, and untrusted token
  data.
- Decide raw UTF-8 JSON vs base64 JSON for on-chain metadata.
- Set size limits for collection scripts, dependency scripts, `tokenData`, image
  data, attributes, and `tokenURI`.
- Define dependency creation, update, versioning, deprecation, and immutability
  after freeze.
- Treat generated HTML as executable code.
- Add render sandbox tests.
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
- Review ERC721Enumerable necessity as P1 architecture, not P3 polish.
- Review supply model versus storage model:
  - Collection token ranges reserve up to 10 billion token IDs per collection.
  - ERC721Enumerable tracks every minted token globally and per owner.
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
- Characterize current fixed-price drop behavior.
- Characterize current auction creation/custody behavior; settlement remains
  missing until the auction ADR and P0 auction work.
- Characterize current admin guards.
- Characterize current payout behavior.
- Characterize current randomness/pending metadata behavior.
- Initial Gate A skeleton coverage: admin signer/global/function permissions,
  current `StreamDrops` packed drop ID encoding, signer-only drop execution,
  fixed-price minting to explicit recipients, drop replay rejection, mocked
  `StreamDrops` auction argument passing, real
  `StreamDrops -> StreamMinter -> StreamCore` auction mint custody to the
  payout address, auction status/end-time recording, current admin selector
  mismatch behavior, synchronous fixed-price payout plus poster, payout-address,
  and curators-pool rejection behavior, pending metadata, immediate randomizer fulfillment,
  configured-randomizer-only token hash setting, and one-time token hash
  immutability.
- Note: this Gate A list includes known-unsafe behavior, including
  signer-only drop execution and synchronous fixed-price payout rejection
  paths. These tests are regression tripwires before P0 rewrites, not
  endorsements of protocol correctness.

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

- Add Foundry deployment scripts for local/anvil, testnet, and fork dry runs.
- Add post-deploy wiring for admins, minter, drops, auctions, randomizers,
  dependency registry, payout, and curator pool.
- Add deployment manifest schema and JSON example with network, chain ID,
  addresses, constructor args, git commit, compiler version, Foundry version,
  ABI hashes, admin multisig addresses, and external dependencies.
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
- Add checksummed artifacts.
- Add build provenance attestation where practical.
- Add machine-readable release manifest.
- Add ABI diff checks for every release.
- Add interface ID catalog.
- Add storage layout snapshots if upgradeability is ever introduced.
- Add source verification artifact retention.

### Release Checklist

- All CI green.
- Slither baseline accepted.
- Gas snapshot accepted.
- Deployment rehearsal complete.
- Manifests generated.
- ABIs checksummed.
- Contracts verified.
- Changelog written.
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
- Interface IDs.
- Event topic catalog.
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
- Status: baseline captured, not accepted as a CI gate.
- Result: 530 findings, including 13 High and 26 Medium.

Impact summary:

| Impact | Count |
| --- | ---: |
| High | 13 |
| Medium | 26 |
| Low | 51 |
| Informational | 434 |
| Optimization | 6 |

High/medium detector summary:

| Detector | Impact | Count | Primary scope | Status | Issue | Required action |
| --- | --- | ---: | --- | --- | --- | --- |
| `arbitrary-send-eth` | High | 4 | first-party emergency withdrawals | Open | [#8](https://github.com/6529-Collections/6529Stream/issues/8) | Replace or bound with owed/surplus accounting |
| `encode-packed-collision` | High | 3 | drop authorization and dependency/script hashing | Open | [#9](https://github.com/6529-Collections/6529Stream/issues/9), [#10](https://github.com/6529-Collections/6529Stream/issues/10) | Replace ad hoc packed hashes with typed/domain-separated encoding; track dependency-script row as `P0-META-001` |
| `incorrect-exp` | High | 1 | vendored `Math.mulDiv` | Needs Issue | [#11](https://github.com/6529-Collections/6529Stream/issues/11) | Confirm likely false positive against pinned upstream or replace vendored library |
| `reentrancy-eth` | High | 1 | auction bidding | Open | [#12](https://github.com/6529-Collections/6529Stream/issues/12) | Move to pull credits and state-before-external-call flow |
| `uninitialized-state` | High | 2 | mint-accounting mappings | Open | [#13](https://github.com/6529-Collections/6529Stream/issues/13) | Initialize, remove, or complete design |
| `weak-prng` | High | 2 | word pool randomness helpers | Open | [#14](https://github.com/6529-Collections/6529Stream/issues/14) | ADR 0005 requires removal, test/demo scoping, or production-disablement before Gate C |
| `divide-before-multiply` | Medium | 9 | vendored math/base64 helpers | Needs Issue | [#11](https://github.com/6529-Collections/6529Stream/issues/11) | Confirm likely false positive against pinned upstream or replace vendored library |
| `locked-ether` | Medium | 1 | test-only rejection mock | Accepted | N/A | Keep scoped to test-only baseline |
| `uninitialized-local` | Medium | 11 open, 1 fixed | first-party and test helper locals | Open for remaining production rows; `StreamDrops.mintDrop` fixed in `P0-AUTH-002` | [#15](https://github.com/6529-Collections/6529Stream/issues/15) | Initialize or prove Solidity zero-value intent |
| `unused-return` | Medium | 4 | characterization tests | Accepted | N/A | Keep scoped to test-only baseline |

## Appendix B: Test Matrix

Status values: `Missing`, `Planned`, `In Progress`, `Passing`, `Blocked`.

| Finding | Required test | Intended test file | Status | Issue | Gate | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| `tx.origin` recipient bug | Contract executor submits a drop without `tx.origin` dependency | `test/StreamDropsCharacterization.t.sol` and `test/StreamDropsIntegrationCharacterization.t.sol` | Target-state explicit-recipient, contract-executor, non-zero auction-recipient rejection, and no-bid settlement tests added; full contract-signer validation remains under `P0-AUTH-003` | [`P0-AUTH-001`](https://github.com/6529-Collections/6529Stream/issues/18) | Gate C | TBD |
| Ad hoc drop authorization | EIP-712 valid, explicit digest encoding, replayed, expired, wrong chain, wrong contract, wrong signer, cancelled, stale epoch, malleable, zero recovered signer, token substitution, bad quantity, bad payer, and compact signature tests | `test/StreamDropsEIP712.t.sol` | Passing for EOA/EIP-2098 target state; ERC-1271 remains `P0-AUTH-003` | [`P0-AUTH-002`](https://github.com/6529-Collections/6529Stream/issues/10) | Gate C | TBD |
| ERC-1271 decision | ERC-1271 mock signer passes after implementation; interim contract signer rejection remains covered in EIP-712 tests | `test/StreamDropsERC1271.t.sol` | Missing implementation; explicit rejection covered by `test/StreamDropsEIP712.t.sol` | [`P0-AUTH-003`](https://github.com/6529-Collections/6529Stream/issues/19) | Gate B1/Gate C | TBD |
| Auction reentrancy | Malicious bidder cannot reenter bid/withdraw flows | `test/StreamAuctionReentrancy.t.sol` | Missing | [`P0-AUCT-002`](https://github.com/6529-Collections/6529Stream/issues/12) | Gate C | TBD |
| Outbid refund failure | Previous bidder credited even if receiver reverts | `test/StreamAuctionPayments.t.sol` | Missing | [`P0-AUCT-002`](https://github.com/6529-Collections/6529Stream/issues/12) | Gate C | TBD |
| Payment ledger totals | Poster, bidder, curator, curator reserve, protocol, total owed, surplus, and emergency-withdrawable views follow ADR 0003 | `test/StreamPayments.t.sol` | Missing | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C/Gate D | TBD |
| Withdrawal failure behavior | Failed withdrawal preserves account credit and category totals | `test/StreamPayments.t.sol` | Missing | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C | TBD |
| Emergency surplus boundary | Emergency withdrawal can withdraw only surplus and cannot withdraw owed or reserved funds | `test/StreamEmergencyWithdraw.t.sol` | Missing | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-007`](https://github.com/6529-Collections/6529Stream/issues/31), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C/Gate D | TBD |
| Randomness reserve accounting | Randomizer provider reserves are not emergency-withdrawable surplus | `test/StreamRandomizerPayments.t.sol` | Missing | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-007`](https://github.com/6529-Collections/6529Stream/issues/31), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8), [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14) | Gate C/Gate D | TBD |
| Auction custody failure | Auction settlement succeeds only with explicit custody/approval | `test/StreamAuctionCustody.t.sol` | Initial auction mint custody characterization exists in `test/StreamDropsCharacterization.t.sol` and `test/StreamDropsIntegrationCharacterization.t.sol`; settlement tests missing | [`P0-AUCT-001`](https://github.com/6529-Collections/6529Stream/issues/22) | Gate B1/Gate C | TBD |
| No-bid settlement ambiguity | No-bid settlement ownership follows ADR | `test/StreamAuctionSettlement.t.sol` | Missing | [`P0-AUCT-001`](https://github.com/6529-Collections/6529Stream/issues/22) | Gate B1/Gate C | TBD |
| Admin selector mismatch | Wrong function selector cannot authorize mutation; intentional grouped permissions use explicit named roles | `test/StreamAdminSelectors.t.sol` | Initial characterization exists in `test/StreamCoreAdminCharacterization.t.sol`; P0 fix tests missing | [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34) | Gate C | TBD |
| Function-admin target scope | Grant for one contract and selector cannot authorize another target with the same selector | `test/StreamAdminSelectors.t.sol` | Missing | [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34) | Gate C | TBD |
| Collection-admin support | Collection admin can mutate only explicitly allowed fields for one collection, or unsupported interface reverts clearly | `test/StreamCollectionAdmins.t.sol` | Missing | [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34) | Gate C | TBD |
| Signer lifecycle | Signer add, remove, epoch increment, stale epoch rejection, and per-drop cancellation follow ADR 0004 | `test/StreamSignerAdmin.t.sol` | Missing | [`P0-ADMIN-ADR`](https://github.com/6529-Collections/6529Stream/issues/33), [`P0-ADMIN-001`](https://github.com/6529-Collections/6529Stream/issues/34) | Gate B1/Gate C | TBD |
| Pause controls | Domain-specific pause blocks only the intended mint, bid, settlement, metadata, randomness-request, or drop-execution path | `test/StreamPauseControls.t.sol` | Missing | [`P0-ADMIN-002`](https://github.com/6529-Collections/6529Stream/issues/35) | Gate C | TBD |
| Admin emergency controls | Emergency admin can withdraw only surplus and cannot alter credits, reserves, custody, or consumed drop IDs | `test/StreamEmergencyWithdraw.t.sol` | Missing | [`P0-ADMIN-002`](https://github.com/6529-Collections/6529Stream/issues/35), [`P0-PAY-007`](https://github.com/6529-Collections/6529Stream/issues/31), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C/Gate D | TBD |
| Randomness request lifecycle | Request records expose token, collection, provider, request ID, epoch, state, request time, and fulfillment time | `test/StreamRandomizerLifecycle.t.sol` | Missing | [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37), [`P0-RAND-002`](https://github.com/6529-Collections/6529Stream/issues/38) | Gate C | TBD |
| Randomizer callback validation | Valid fulfillment accepts only the stored request ID, token, collection, provider, and randomizer epoch | `test/StreamRandomizerCallbacks.t.sol` | Missing | [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37), [`P0-RAND-003`](https://github.com/6529-Collections/6529Stream/issues/39) | Gate C | TBD |
| Randomizer stale callback | Replaced randomizer or stale-epoch fulfillment rejected | `test/StreamRandomizerCallbacks.t.sol` | Missing | [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37), [`P0-RAND-003`](https://github.com/6529-Collections/6529Stream/issues/39), [`P0-RAND-005`](https://github.com/6529-Collections/6529Stream/issues/41) | Gate C | TBD |
| Randomness lifecycle states | Pending, fulfilled, stale, and failed post-processing states drive metadata and views | `test/StreamRandomizerLifecycle.t.sol` | Missing | [`P0-RAND-004`](https://github.com/6529-Collections/6529Stream/issues/40) | Gate C/Gate D | TBD |
| Randomizer migration | Provider migration with pending requests is blocked or explicitly marks affected requests stale according to ADR 0005 | `test/StreamRandomizerMigration.t.sol` | Missing | [`P0-RAND-005`](https://github.com/6529-Collections/6529Stream/issues/41) | Gate C | TBD |
| Randomness retry | Manual retry reprocesses the same provider output and cannot redraw randomness | `test/StreamRandomizerRetry.t.sol` | Missing | [`P0-RAND-006`](https://github.com/6529-Collections/6529Stream/issues/42) | Gate C | TBD |
| Randomness seed storage | Derived seed/hash includes provider, request ID, collection, token, randomizer epoch, and raw-output hash | `test/StreamRandomizerSeed.t.sol` | Missing | [`P0-RAND-007`](https://github.com/6529-Collections/6529Stream/issues/43) | Gate C | TBD |
| Weak helper randomness | `RandomizerNXT` and `XRandoms` are removed, test/demo-scoped, or impossible to configure for production drops | `test/StreamRandomizerProductionScope.t.sol` | Missing | [`P0-RAND-ADR`](https://github.com/6529-Collections/6529Stream/issues/14), [`P0-RAND-001`](https://github.com/6529-Collections/6529Stream/issues/37) | Gate C/Gate F | TBD |
| Pending randomness metadata | Off-chain and on-chain `tokenURI` pending/final behavior is deterministic and never treats zero hash as finalized randomness | `test/StreamMetadata.t.sol` | Initial off-chain characterization exists in `test/StreamDropsIntegrationCharacterization.t.sol`; on-chain pending/final and golden-file tests missing | [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45), [`P1-META-001`](https://github.com/6529-Collections/6529Stream/issues/46), [`P0-RAND-004`](https://github.com/6529-Collections/6529Stream/issues/40) | Gate C/Gate D | TBD |
| Metadata schema golden files | Off-chain URI rules, on-chain pending JSON, on-chain final JSON, and generated HTML remain deterministic under the accepted schema | `test/StreamMetadataGolden.t.sol` | Missing | [`P1-META-001`](https://github.com/6529-Collections/6529Stream/issues/46) | Gate D | TBD |
| Metadata escaping and render safety | JSON, HTML, JavaScript, raw attributes, URI, and size-limit inputs are escaped, validated, or rejected | `test/StreamMetadataEscaping.t.sol` | Missing | [`P1-META-006`](https://github.com/6529-Collections/6529Stream/issues/51) | Gate D | TBD |
| Collection freeze boundary | Frozen collections cannot mutate collection fields, base URI, metadata mode, scripts, dependency references, token data, image, attributes, final supply, or live-token metadata state | `test/StreamMetadataFreeze.t.sol` | Missing | [`P1-META-002`](https://github.com/6529-Collections/6529Stream/issues/47) | Gate D | TBD |
| Dependency registry immutability | Dependency versions are immutable, pinned by key/version/content hash, and cannot change frozen collection output | `test/StreamDependencyRegistry.t.sol` | Missing | [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48) | Gate D | TBD |
| ERC-4906 metadata signaling | `supportsInterface(0x49064906)` succeeds and `MetadataUpdate` / `BatchMetadataUpdate` emit only when token JSON metadata changes | `test/StreamMetadataEvents.t.sol` | Missing | [`P1-META-004`](https://github.com/6529-Collections/6529Stream/issues/49) | Gate D | TBD |
| Dependency script packed encoding | Dependency script retrieval uses safe typed concatenation/hash encoding and cannot collide across script segments | `test/StreamMetadataEncoding.t.sol` | Missing | [`P0-META-001`](https://github.com/6529-Collections/6529Stream/issues/9), [`P1-META-003`](https://github.com/6529-Collections/6529Stream/issues/48) | Gate C/Gate D | TBD |
| Deployment redeployment rehearsal | Deployment manifests, ABI hashes, admin ceremony, signer setup, deprecation checks, and emergency redeployment rehearsal follow ADR 0007 | `test/StreamDeploymentManifest.t.sol` and `script/RehearseDeployment.s.sol` | Missing | [`P2-UPGRADE-ADR`](https://github.com/6529-Collections/6529Stream/issues/53) | Gate E/Gate G | TBD |
| Mint-accounting state | Mint counters initialize and update according to the accepted drop/mint accounting design | `test/StreamMintAccounting.t.sol` | Missing | [`P0-CORE-001`](https://github.com/6529-Collections/6529Stream/issues/13) | Gate C | TBD |
| Uninitialized local findings | First-party default-local behavior is explicit, removed, or covered by targeted regressions | `test/StreamInitialization.t.sol` | Missing | [`P0-INIT-001`](https://github.com/6529-Collections/6529Stream/issues/15) | Gate C | TBD |
| Curator double claim | Valid claim succeeds once and second claim fails | `test/StreamCuratorsPool.t.sol` | Missing | `P1-CURATOR-*` | Gate D | TBD |
| Merkle leaf ambiguity | Duplicate or ambiguous leaves cannot double claim | `test/StreamCuratorsMerkle.t.sol` | Missing | `P1-CURATOR-*` | Gate D | TBD |
| Burn accounting | Burned-token supply, unavailable `tokenURI`, retained audit state, and callback-after-burn behavior follow ADR 0006 | `test/StreamCoreBurn.t.sol` | Missing | [`P1-META-ADR`](https://github.com/6529-Collections/6529Stream/issues/45), [`P1-META-005`](https://github.com/6529-Collections/6529Stream/issues/50), [`P0-RAND-004`](https://github.com/6529-Collections/6529Stream/issues/40) | Gate D | TBD |
| Forced ETH accounting | Forced/direct ETH does not corrupt owed/surplus accounting | `test/StreamPaymentsInvariant.t.sol` | Missing | [`P0-PAY-ADR`](https://github.com/6529-Collections/6529Stream/issues/24), [`P0-PAY-008`](https://github.com/6529-Collections/6529Stream/issues/8) | Gate C/Gate D | TBD |

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
