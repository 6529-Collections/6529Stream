# Threat Model

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins.


6529Stream is a pre-audit local baseline and is not production-ready. This
threat model is not a security claim. It records the current assumptions,
assets, trust boundaries, controls, residual risks, and evidence links for
auditors reviewing the local baseline.

Read this document together with the [architecture](architecture.md), the
[external audit package](audit-package.md), the [project status](status.md),
the [known blockers](known-blockers.md), and
[`SECURITY.md`](../SECURITY.md).

## Maturity And Scope

This threat model covers:

- first-party production contracts in the local baseline;
- accepted ADR decisions for authorization, custody, payments, governance,
  randomness, metadata/freeze, and redeployment;
- local tests, invariants, Slither disposition, deployment rehearsal, release
  artifacts, ceremony evidence, and audit package checks.

It does not cover:

- fork, testnet, or mainnet deployment evidence;
- production signer custody;
- production detached signatures or signed Git tags;
- live provider funding and request-health evidence;
- a completed third-party audit report;
- marketplace, wallet, indexer, or browser behavior outside the committed
  local evidence checks.

## Assets

Protected assets include:

- NFT ownership and token existence state in `StreamCore`;
- signed drop authorization validity, consumed drop IDs, cancelled drop IDs, and
  signer epochs in `StreamDrops`;
- auction escrowed NFTs, active highest-bid escrow, bidder credits, terminal
  settlement state, and proceeds credits in `StreamAuctions`;
- fixed-price poster/protocol/curator-reserve credits in `StreamDrops`;
- curator reward credits in `StreamCuratorsPool`;
- randomizer request lifecycle state, raw-output hashes, derived seeds,
  provider epochs, and adapter reserve balances;
- dependency version source, content hashes, provenance, deprecation state, and
  collection dependency pins;
- metadata state, token data, image/attribute inputs, freeze manifest hashes,
  and burn audit state;
- admin, pause, signer-manager, and emergency-recipient authorities;
- release artifacts, manifests, address books, source verification inputs,
  ceremony evidence, release signature evidence, and checksums.

## Actors And Trust Boundaries

Trusted or privileged actors:

- protocol owner or Safe controlling `StreamAdmins` and `StreamCore`;
- global admins and target-scoped function admins;
- pause guardians and unpause admins;
- signer managers;
- dependency operators;
- release operators.

Semi-trusted actors:

- authorized drop signers;
- randomizer providers and coordinators;
- curators with Merkle reward proofs;
- deployment operators using broadcast tools;
- maintainers refreshing release evidence.

Untrusted actors:

- posters submitting signed drops;
- buyers and auction bidders;
- arbitrary ERC-721 receiver contracts;
- contracts attempting ERC-1271 validation edge cases;
- users attempting replay, front-running, malformed metadata, or withdrawal
  reentrancy;
- public contributors and external integrators;
- off-chain indexers, wallets, marketplaces, and browsers.

Trust boundaries include EIP-712 signatures, ERC-1271 contract signatures,
ETH transfers, ERC-721 transfers, randomizer callbacks, Merkle proofs,
metadata/rendering inputs, dependency source registration, deployment
broadcasts, generated release evidence, and security-report intake.

## Assumptions And Non-Goals

Assumptions:

- Solidity `0.8.19` arithmetic and type checks behave as specified.
- Foundry `v1.7.1` and the pinned Python/browser tooling can reproduce local
  evidence.
- Operators run the documented release/deployment commands before release.
- Production deployments will use real Safe/multisig, signer, provider, RPC,
  and verification infrastructure rather than local placeholders.
- External auditors will review the source, ADRs, tests, Slither disposition,
  and generated evidence before public security claims.

Non-goals:

- proving protocol correctness from smoke tests alone;
- guaranteeing marketplace rendering behavior;
- certifying arbitrary artist or dependency JavaScript as safe;
- migrating value or state across emergency redeployments by assumption;
- committing private keys, mnemonics, RPC URLs, API keys, or unreleased drop
  payloads.

## Threat Categories

| Category | Threats | Current controls | Residual risk |
| --- | --- | --- | --- |
| Authorization and replay | forged signer, wrong domain, replayed drop ID, cancelled drop reuse, stale signer, signature malleability, ERC-1271 edge cases | EIP-712 domain, consumed/cancelled storage, signer epochs, EOA and ERC-1271 tests | production signing examples and operational signer custody remain future work |
| Auction custody | NFT minted to wrong holder, lost escrow, repeated settlement, no-bid claimant failure, terminal-state drift | direct auction escrow mint, `IERC721Receiver` validation, explicit states, idempotent terminal guards, no-bid pending claim path | live ceremony and fork/testnet evidence remain future work |
| Payments | synchronous refund reentrancy, erased credit on failed withdrawal, owed/balance mismatch, emergency withdrawal of owed funds | pull-payment credits, failed-withdrawal preservation, local owed/reserved/surplus views, payment invariants | shared protocol-wide ledger remains optional future architecture |
| Admin controls | selector mismatch, overbroad grants, pause misuse, unpause authority confusion, signer self-management | target-scoped function admins, pause domains, separate unpause admins, signer-manager lifecycle controls | production Safe deployment ceremony and richer live governance evidence remain future work |
| Randomness | wrong request fulfillment, stale callback, provider migration while pending, raw output leakage, retry requesting new randomness | randomizer lifecycle storage, provider and epoch validation, pending migration block, stale state, bounded retry, raw-output hash storage | live provider funding and request-health evidence remain future work |
| Metadata and rendering | malformed JSON, unsafe URI, invalid UTF-8, script-boundary breakout, misleading freeze, burn/remint confusion | JSON escaping, URI/UTF-8/size guards, raw attribute schema, browser sandbox checks, freeze manifest hash, burn audit state | arbitrary artist/dependency JavaScript is not certified as safe |
| Dependency supply chain | ambiguous script chunks, mutable dependency output, missing source retention, unsafe migration | typed chunk/content hashes, immutable version records, collection pins, deprecation/runbook docs, dependency artifact manifest | production dependency ceremonies and live retention evidence remain future work |
| Deployment and release | deployment ceremony drift, wrong bytecode, wrong addresses, missing verification, stale artifacts, unsigned release bundle, secret leakage | local deployment rehearsal, manifests, address books, source verification inputs, checksum bundle, local placeholder release signatures, no-secret evidence schemas | fork/testnet/live broadcast evidence, explorer verification, and real signatures remain open |
| External integrations | indexer assumptions, wallet/marketplace metadata differences, browser execution differences, reorg assumptions | event catalog, metadata schema fixtures, release docs, known blocker separation | integration examples and live confirmation-depth evidence remain future Gate G work |

## MEV And Timing Model

Public transaction submission is not treated as private. Searchers can observe
or relay signed payloads, and the protocol guarantee is that typed payload
fields bind the actual recipient, payer, collection, token data, sale mode,
deadline, signer epoch, nonce, salt, and drop ID. Free signed drops may be
submitted by a third party, but the minted NFT must still go to the signed
recipient and the consumed drop ID must block replay. Paid fixed-price drops
additionally bind `payer` to `msg.sender`, so a third-party submitter cannot
spend their own ETH to redirect a signed paid mint.

Deadline checks are explicit protocol time-window logic. A drop with
`deadline == block.timestamp` is valid, while a drop submitted after the
deadline must fail without consuming the drop ID or minting a token. Auction
end-time checks are similarly explicit: bids at exactly `endTime` remain valid
and may trigger the documented extension window, while bids after `endTime`
must fail without changing custody, highest-bid state, bidder credits, escrow,
or contract balance.

These tests do not claim protection against private orderflow leakage,
validator ordering, RPC censorship, or wallet/indexer UX races. Frontends and
operators should still use bounded deadlines, confirmation-depth policy,
read-after-event checks, monitoring, and safe transaction replacement guidance.

## Existing Controls

Current evidence links include:

- [`docs/adr/0001-drop-authorization.md`](adr/0001-drop-authorization.md)
- [`docs/adr/0002-auction-custody.md`](adr/0002-auction-custody.md)
- [`docs/adr/0003-payment-accounting.md`](adr/0003-payment-accounting.md)
- [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
- [`docs/adr/0005-randomness.md`](adr/0005-randomness.md)
- [`docs/adr/0006-metadata-freeze.md`](adr/0006-metadata-freeze.md)
- [`docs/adr/0007-upgrade-redeployment.md`](adr/0007-upgrade-redeployment.md)
- [`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md)
- [`docs/slither.md`](slither.md)
- [`docs/deployment.md`](deployment.md)
- [`docs/release-policy.md`](release-policy.md)
- [`docs/release-signatures.md`](release-signatures.md)
- [`docs/randomizer-operations.md`](randomizer-operations.md)
- [`docs/dependency-operations.md`](dependency-operations.md)
- [`docs/metadata.md`](metadata.md)
- [`docs/auction-custody.md`](auction-custody.md)
- [`release-artifacts/latest/release-manifest.json`](../release-artifacts/latest/release-manifest.json)
- [`release-artifacts/latest/SHA256SUMS`](../release-artifacts/latest/SHA256SUMS)
- [`test/helpers/ProtocolStateMachine.sol`](../test/helpers/ProtocolStateMachine.sol)
- [`test/StreamProtocolStateMachine.t.sol`](../test/StreamProtocolStateMachine.t.sol)
- [`test/StreamMEVTiming.t.sol`](../test/StreamMEVTiming.t.sol)

## Residual Risks And Open Blockers

Accepted local-baseline dispositions are not production risk acceptance. They
include test-only Slither helper findings, documented vendored-library false
positives, local placeholder deployment evidence, local placeholder randomizer
operations evidence, and local placeholder release signature evidence.

Unresolved production blockers include:

- fork/testnet/live deployment rehearsals and broadcast retention;
- production address books and verified live addresses;
- live explorer verification;
- production detached checksum signatures and signed Git tags;
- production signer identity and custody documentation;
- fork/testnet/live metadata browser evidence;
- fork/testnet/live randomizer provider funding and request-health evidence;
- external audit completion and remediation tracking.

No production risk is accepted for public launch by this threat model.

## Evidence Links

Use these starting points during review:

- [README](../README.md)
- [architecture](architecture.md)
- [external audit package](audit-package.md)
- [project status](status.md)
- [known blockers](known-blockers.md)
- [roadmap](../ops/ROADMAP.md)
- [autonomous run state](../ops/AUTONOMOUS_RUN.md)
- [security policy](../SECURITY.md)
- [contributor guide](../CONTRIBUTING.md)
- [release artifact guide](../release-artifacts/README.md)
- [release checksum bundle](../release-artifacts/latest/release-checksums.json)
- [payment invariant tests](../test/StreamPaymentsInvariant.t.sol)
- [supply, replay, and freeze invariant tests](../test/StreamSupplyReplayFreezeInvariant.t.sol)
- [auction invariant tests](../test/StreamAuctionInvariant.t.sol)
- [protocol state-machine smoke harness](../test/StreamProtocolStateMachine.t.sol)
- [randomizer payment tests](../test/StreamRandomizerPayments.t.sol)
- [deployment manifest tests](../test/StreamDeploymentManifest.t.sol)
- [audit package checker](../scripts/check_audit_package.py)

## Maintenance

Update this document when a PR changes assets, trust assumptions, privileged
roles, signature semantics, custody, payment accounting, randomness lifecycle,
metadata rendering, dependency handling, deployment/release evidence, accepted
risks, or known blockers. If this file changes, run:

```sh
python scripts/test_architecture_threat_model.py
python scripts/check_architecture_threat_model.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```
