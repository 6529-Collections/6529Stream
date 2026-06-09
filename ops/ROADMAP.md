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
- Current CI proves only that the repo compiles and that the test command exits.
  It does not prove protocol correctness because there are no meaningful tests.
- Known P0 blockers include `tx.origin` drop execution, ad hoc authorization,
  auction custody ambiguity, auction reentrancy, push payments, untriaged static
  analysis findings, missing tests, and missing deployment discipline.
- Public docs must describe actual on-chain behavior, not intended product
  behavior.

### Verification Metadata

| Field | Value |
| --- | --- |
| Last verified | TBD |
| OS tested | Windows / Linux |
| Foundry version | `v1.7.1` |
| Solidity compiler version | `0.8.19` |
| Slither version | TBD |
| CI run | TBD |
| Command transcript location | TBD |

### Machine-Verifiable Baseline

| Area | Current status | Evidence | Required before public beta |
| --- | --- | --- | --- |
| Build | Passes with warnings when `forge` is invoked through the installed binary path | `forge build` | Build passes in CI and locally with warnings burned down or documented |
| Unit/integration tests | No meaningful tests | `forge test -vvv` | P0 regression and integration suite exists |
| Formatting | Fails broadly | `forge fmt --check smart-contracts` | Passing, or vendored exclusions documented |
| Static analysis | Runs with a large untriaged baseline | `slither . --foundry-compile-all` | High/medium findings fixed, accepted, or documented |
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

Status: Not Started.
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

Status: Not Started.
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

Status: Not Started.
Owner: TBD.
Blocking issues: TBD.
Evidence: TBD.

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
| Drop authorization | `P0-AUTH-ADR` | `docs/adr/0001-drop-authorization.md` | Gate B1, `P0-AUTH-*` | EIP-712 schema, recipient/payer policy, nonce model, replay protection, signer rotation, ERC-1271 stance |
| Auction custody | `P0-AUCT-ADR` | `docs/adr/0002-auction-custody.md` | Gate B1, `P0-AUCT-*` | Token custody, settlement actor, no-bid semantics, transfer method, cancellation |
| Payment accounting | `P0-PAY-ADR` | `docs/adr/0003-payment-accounting.md` | Gate B1, `P0-PAY-*` | Pull credits, owed balances, surplus, withdrawals, emergency withdrawal limits |
| Admin/governance | `P0-ADMIN-ADR` | `docs/adr/0004-admin-governance.md` | Gate B1, `P0-ADMIN-*` | Global/function/collection roles, signer lifecycle, pause controls, multisig expectations |
| Randomness | `P0-RAND-ADR` | `docs/adr/0005-randomness.md` | Gate B1, `P0-RAND-*` | Provider choice, pending state, callback validation, retries, stale callback handling |
| Metadata/freeze | `P1-META-ADR` | `docs/adr/0006-metadata-freeze.md` | Gate B2, `P1-META-*` | Pending/final metadata, frozen state, dependency immutability, burn metadata |
| Upgrade/redeployment | `P2-UPGRADE-ADR` | `docs/adr/0007-upgrade-redeployment.md` | Gate B2, deployment/release | Redeploy vs upgrade stance, migration expectations, versioning |

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
7. `P0-AUCT-ADR / P0/DESIGN`: ADR for auction custody.
8. `P0-PAY-ADR / P0/DESIGN`: ADR for payment accounting.
9. `P0-ADMIN-ADR / P0/DESIGN`: ADR for admin/governance.
10. `P0-RAND-ADR / P0/DESIGN`: ADR for randomness.
11. `P1-META-ADR / P1/DESIGN`: ADR for metadata/freeze.
12. `P2-UPGRADE-ADR / P2/DESIGN`: ADR for upgrade/redeployment.
13. `P0-AUTH-001 / P0/CODE+TEST+DOCS`: Remove `tx.origin`.
14. `P0-AUTH-002 / P0/CODE+TEST+DOCS`: Implement EIP-712 authorization.
15. `P0-AUTH-003 / P0/CODE+TEST+DOCS`: Add ERC-1271 support or explicitly reject contract signers.
16. `P0-AUCT-002 / P0/CODE+TEST+DOCS`: Refactor auction bidding to pull credits.
17. `P0-AUCT-001 / P0/CODE+TEST+DOCS`: Formalize auction custody and settlement.
18. `P0-ADMIN-001 / P0/CODE+TEST+DOCS`: Fix admin selector mismatch.
19. `P0-RAND-001 / P0/CODE+TEST+DOCS`: Harden randomizer callbacks.
20. `P1/TEST`: Add first invariant suite.
21. `P1/DOCS`: Add protocol spec and threat model.
22. `P2/OPS`: Add deployment scripts and manifest schema.

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

Current behavior:

- `StreamDrops` assigns fixed-price receiver and execution address from
  `tx.origin`.

Intended behavior:

- The intended recipient/execution address is explicit, signed, validated, and
  stored.
- `msg.sender` may be payer/relayer only according to the ADR policy.

Required code changes:

- Remove all `tx.origin` uses.
- Add explicit recipient/execution/settlement fields according to the ADR.
- Validate zero addresses and role/payer semantics.

Required tests:

- EOA execution.
- Contract wallet execution.
- Relayer execution if supported.
- Recipient different from payer if supported.
- Zero recipient rejection.
- Wrong recipient signature failure.

Required docs:

- `docs/drop-authorization.md`.
- README maturity/status update if behavior changes before full fix.

Acceptance criteria:

- No `tx.origin` remains in protocol source.
- Contract wallet execution test passes.
- Signed recipient/execution fields cannot be substituted.
- External docs describe payer, signer, poster, recipient, execution address, and
  settlement recipient semantics.

### P0-AUTH-002: Replace Drop Authorization With EIP-712

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Dependencies: `P0-AUTH-ADR`.

Problem:

- Current drop IDs are built with string concatenation and `abi.encodePacked`.
  Authorization does not provide a robust typed domain, nonce/deadline model, or
  replay protection.

Current behavior:

- Drop authorization is tied to a TDH signer call and ad hoc drop ID hashing.

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
- Decide whether EIP-2098 compact signatures are supported or explicitly
  rejected.
- Define front-running semantics: a third party may submit a signed drop only if
  recipient, price, token data, settlement recipient, and signed execution
  constraints cannot be redirected.

Child tickets:

- `P0-AUTH-002A`: Define and implement EIP-712 domain and typed schema.
- `P0-AUTH-002B`: Add nonce/drop ID consumed-state storage.
- `P0-AUTH-002C`: Add deadline, domain, chain, contract, signer, and field
  substitution checks.
- `P0-AUTH-002D`: Add malleability policy and EIP-2098 support/reject policy.
- `P0-AUTH-002E`: Add replay and front-running regression tests.

Required tests:

- EOA signature passes.
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

Required docs:

- EIP-712 schema.
- Nonce/drop ID policy.
- Signer rotation policy.
- Example payload fixtures.

Acceptance criteria:

- EIP-712 domain includes name, version, chain ID, and verifying contract.
- Replay protection is backed by consumed-state storage.
- All required negative tests pass.

### P0-AUTH-003: Decide And Implement ERC-1271 Support

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate B1 and Gate C.
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
- Blocks: Gate B1 and Gate C.
- Dependencies: `P0-AUCT-ADR`.

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

### P0-AUCT-002: Fix Auction Bidding Reentrancy And Refunds

- Priority/severity/type: `P0 / Critical / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Dependencies: `P0-PAY-ADR`.

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
- Dependencies: `P0-PAY-ADR`.

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

- Add accounting for poster credits, bidder credits, curator credits, protocol
  surplus, total poster owed, total bidder owed, total curator owed, total owed,
  and emergency withdrawable balance.
- Add withdrawal functions.
- Ensure failed withdrawal does not erase credit.

Child tickets:

- `P0-PAY-002`: Add credit ledger storage and total-owed views.
- `P0-PAY-003`: Convert fixed-price poster/platform payouts to credits.
- `P0-PAY-004`: Convert auction outbid refunds to credits.
- `P0-PAY-005`: Convert curator reward claims to credits.
- `P0-PAY-006`: Add withdrawal functions and failed-withdrawal behavior.
- `P0-PAY-007`: Bound emergency withdrawals by surplus.
- `P0-PAY-008`: Add payment invariants and forced-ETH tests.

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

- `totalOwed == totalPosterOwed + totalBidderOwed + totalCuratorOwed`.
- `address(this).balance >= totalOwed` except where forced ETH creates surplus.
- `emergencyWithdrawable == address(this).balance - totalOwed`.
- No withdrawal can reduce another user's owed balance.

### P0-ADMIN-001: Fix Admin Selector And Permission Model

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Dependencies: `P0-ADMIN-ADR`.

Problem:

- Function-level permissions can be misapplied when modifiers use the wrong
  selector. Collection admin permissions exist but are not consistently
  enforced.

Current behavior:

- `StreamCore.setCollectionData` is gated by
  `this.changeMetadataView.selector`.

Intended behavior:

- Every protected function is gated by the intended selector or role.
- Collection-scoped admin rules are explicit.

Required code changes:

- Fix selector mismatch.
- Audit all `FunctionAdminRequired(this.*.selector)` calls.
- Define global, function, collection, signer, guardian/pause, and owner roles.
- Make critical role changes two-step where practical: propose/accept or
  schedule/execute.
- Add events for grants, revocations, signer updates, ownership transfer, and
  sensitive address updates.
- Signer rotation events should include old signer, new signer, signer epoch,
  and effective block or time.

Required tests:

- Function admin can call only intended function.
- Wrong selector cannot authorize mutation.
- Global admin path.
- Collection admin path if implemented.
- Revoked admin path.
- Unauthorized caller path.
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

### P0-ADMIN-002: Define Pause And Emergency Controls

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS+OPS`.
- Blocks: Gate B1 and Gate C.
- Dependencies: `P0-ADMIN-ADR`.

Problem:

- The roadmap mentions emergency withdrawals and runbooks, but does not define
  pause/guardian controls.

Current behavior:

- No clear pause policy for minting, bidding, settlement, withdrawals, or drop
  execution.

Intended behavior:

- Emergency response controls are explicit, minimal, monitored, and tested.

Required code changes:

- Decide whether to add pause controls for minting, bidding, settlement,
  withdrawals, drop execution, and metadata mutation.
- If added, define who can pause, who can unpause, and whether pause actions are
  immediate or delayed.
- Ensure user withdrawals are paused only if explicitly accepted.
- Pause events should include scope: mint, bid, settlement, withdrawal, drop
  execution, or metadata.

Required tests:

- Pause/unpause authorization.
- Mint pause.
- Bid pause.
- Settlement pause.
- Drop execution pause.
- Metadata pause if implemented.
- Withdrawal pause or non-pause according to ADR.
- Events emitted and indexed.

Required docs:

- Emergency controls section in admin/governance docs.
- Incident runbook updates.

Acceptance criteria:

- Pause model accepted in ADR.
- Pause behavior tested and monitored.

### P0-RAND-001: Harden Randomizer Requests And Callbacks

- Priority/severity/type: `P0 / High / CODE+TEST+DOCS`.
- Blocks: Gate C.
- Dependencies: `P0-RAND-ADR`.

Problem:

- Randomness callback validation and pending/failure states are not strong enough
  for production drops.

Current behavior:

- Randomizer adapters set token hashes with limited request lifecycle tracking.

Intended behavior:

- Fulfillment validates request ID, token, collection, and randomizer epoch.
- Pending and failed randomness are explicit states.

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

Child tickets:

- `P0-RAND-002`: Add request lifecycle storage and views.
- `P0-RAND-003`: Add callback validation for request, token, collection, and
  randomizer epoch.
- `P0-RAND-004`: Add pending, fulfilled, stale, and failed states.
- `P0-RAND-005`: Define and test randomizer migration with pending requests.
- `P0-RAND-006`: Add bounded manual retry for deterministic post-processing
  failures.
- `P0-RAND-007`: Implement raw random words versus derived hash storage policy.

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

Required docs:

- Randomness lifecycle docs.
- Provider configuration docs.
- Stuck request runbook.

Acceptance criteria:

- Randomizer fulfillment validates request ID, token, collection, and randomizer
  epoch.
- Pending and failed states are documented.

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

- Appendix A Slither baseline table.
- Slither config after triage.

Acceptance criteria:

- Slither baseline table has detector, contract, function, source kind, source
  location, severity, confidence, status, resolution, required test, issue,
  gate, and owner.
- Every `Open` or `Needs Issue` finding has an issue link or `TBD` placeholder
  marked as blocking triage.
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
- Characterize current auction creation and settlement behavior.
- Characterize current admin guards.
- Characterize current payout behavior.
- Characterize current randomness/pending metadata behavior.

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

- Fixed-price drop happy path.
- Fixed-price drop replay failure.
- Fixed-price drop wrong signer failure.
- Fixed-price drop expired deadline failure after EIP-712 is introduced.
- Auction mint happy path.
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
- Add `slither.config.json` after triage.
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

Status values: `Open`, `Fixed`, `Accepted`, `False Positive`, `Needs Issue`.
Every row must record source file and line range, identify whether the finding
is first-party, vendored, generated, or test-only, and include an issue link for
each `Open` or `Needs Issue` row before Gate F.

| Detector | Contract | Function | Source kind | Source location | Severity | Confidence | Status | Resolution | Required test | Issue | Gate | Owner |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `arbitrary-send-eth` | TBD | emergency withdrawals / payouts | first-party | TBD | High | TBD | Open | Replace or bound with owed/surplus accounting | payment invariant + emergency withdrawal tests | TBD | Gate C | TBD |
| `reentrancy-eth` | `AuctionContract.sol` | `participateToAuction` | first-party | TBD | High | TBD | Open | Pull credits and state-before-call | malicious bidder regression | TBD | Gate C | TBD |
| `weak-prng` | `XRandoms.sol` / `RandomizerNXT.sol` | randomness helpers | first-party | TBD | High | TBD | Open | Demo-only or replace with production randomizer | randomness provider tests | TBD | Gate C | TBD |
| `encode-packed-collision` | `StreamDrops.sol` and script/dependency hashing paths | drop ID / concatenation | first-party | TBD | Medium/High | TBD | Open | Use typed `abi.encode` / EIP-712 | replay/collision tests | TBD | Gate C | TBD |
| `uninitialized-state` | TBD | mint-accounting mappings | first-party | TBD | Medium | TBD | Open | Remove, initialize, or complete design | harness regression | TBD | Gate C | TBD |
| vendored library warnings | `Math.sol`, `SignedMath.sol`, retained libraries | library functions | vendored | TBD | TBD | TBD | Open | Replace with pinned upstream or suppress with rationale | build/lint baseline | TBD | Gate F | TBD |

## Appendix B: Test Matrix

Status values: `Missing`, `Planned`, `In Progress`, `Passing`, `Blocked`.

| Finding | Required test | Intended test file | Status | Issue | Gate | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| `tx.origin` recipient bug | Contract wallet executes drop without `tx.origin` dependency | `test/StreamDropsAuth.t.sol` | Missing | `P0-AUTH-001` | Gate C | TBD |
| Ad hoc drop authorization | EIP-712 valid, replayed, expired, wrong chain, wrong contract, wrong signer | `test/StreamDropsEIP712.t.sol` | Missing | `P0-AUTH-002` | Gate C | TBD |
| ERC-1271 decision | ERC-1271 mock signer passes or contract signer rejected | `test/StreamDropsERC1271.t.sol` | Missing | `P0-AUTH-003` | Gate B1/Gate C | TBD |
| Auction reentrancy | Malicious bidder cannot reenter bid/withdraw flows | `test/StreamAuctionReentrancy.t.sol` | Missing | `P0-AUCT-002` | Gate C | TBD |
| Outbid refund failure | Previous bidder credited even if receiver reverts | `test/StreamAuctionPayments.t.sol` | Missing | `P0-AUCT-002` | Gate C | TBD |
| Auction custody failure | Auction settlement succeeds only with explicit custody/approval | `test/StreamAuctionCustody.t.sol` | Missing | `P0-AUCT-001` | Gate B1/Gate C | TBD |
| No-bid settlement ambiguity | No-bid settlement ownership follows ADR | `test/StreamAuctionSettlement.t.sol` | Missing | `P0-AUCT-001` | Gate B1/Gate C | TBD |
| Admin selector mismatch | Wrong function selector cannot authorize mutation | `test/StreamAdminSelectors.t.sol` | Missing | `P0-ADMIN-001` | Gate C | TBD |
| Randomizer stale callback | Replaced randomizer fulfillment rejected | `test/StreamRandomizer.t.sol` | Missing | `P0-RAND-001` | Gate C | TBD |
| Pending randomness metadata | `tokenURI` pending/final behavior is deterministic | `test/StreamMetadata.t.sol` | Missing | `P1-META-*` | Gate D | TBD |
| Curator double claim | Valid claim succeeds once and second claim fails | `test/StreamCuratorsPool.t.sol` | Missing | `P1-CURATOR-*` | Gate D | TBD |
| Merkle leaf ambiguity | Duplicate or ambiguous leaves cannot double claim | `test/StreamCuratorsMerkle.t.sol` | Missing | `P1-CURATOR-*` | Gate D | TBD |
| Burn accounting | Burned-token supply and metadata follow ADR | `test/StreamCoreBurn.t.sol` | Missing | `P1-META-*` | Gate D | TBD |
| Forced ETH accounting | Forced/direct ETH does not corrupt owed/surplus accounting | `test/StreamPaymentsInvariant.t.sol` | Missing | `P0-PAY-008` | Gate C/Gate D | TBD |

## Appendix C: ADR Index

| ADR | Issue | Status | File | Blocks |
| --- | --- | --- | --- | --- |
| 0001 Drop authorization | `P0-AUTH-ADR` | Missing | `docs/adr/0001-drop-authorization.md` | Gate B1, `P0-AUTH-*` |
| 0002 Auction custody | `P0-AUCT-ADR` | Missing | `docs/adr/0002-auction-custody.md` | Gate B1, `P0-AUCT-*` |
| 0003 Payment accounting | `P0-PAY-ADR` | Missing | `docs/adr/0003-payment-accounting.md` | Gate B1, `P0-PAY-*` |
| 0004 Admin/governance | `P0-ADMIN-ADR` | Missing | `docs/adr/0004-admin-governance.md` | Gate B1, `P0-ADMIN-*` |
| 0005 Randomness | `P0-RAND-ADR` | Missing | `docs/adr/0005-randomness.md` | Gate B1, `P0-RAND-*` |
| 0006 Metadata/freeze | `P1-META-ADR` | Missing | `docs/adr/0006-metadata-freeze.md` | Gate B2, `P1-META-*` |
| 0007 Upgrade/redeployment | `P2-UPGRADE-ADR` | Missing | `docs/adr/0007-upgrade-redeployment.md` | Gate B2, deployment/release |

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
