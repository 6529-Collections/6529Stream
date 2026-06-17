# Protocol Monitoring Specification

This `GOV-009` specification is a pre-audit local baseline for monitoring
6529Stream operations. It is not production-ready, not a security claim, and
does not replace fork/testnet/live evidence, reviewed deployment evidence,
external audit, production signer custody evidence, or a maintained monitoring
service.

The goal is to make the expected monitoring surface explicit before public beta:
which events, reads, artifacts, invariants, and incident runbooks operators and
integrators must connect when a real dashboard or alerting system is built.
No secrets, private keys, mnemonics, RPC URLs, API keys, webhook URLs, Slack
tokens, PagerDuty tokens, signer-service credentials, or unreleased drop
payloads belong in this file or in any retained monitoring evidence.

## Maturity And Scope

Current maturity:

- Repository status: pre-audit local baseline.
- Monitoring implementation status: specification only; no maintained
  monitoring service, hosted dashboard, alert provider integration, Safe app,
  signer custody implementation, or production indexer is committed.
- Evidence status: local and retained fork-mainnet rehearsal artifacts exist,
  while reviewed testnet/live monitoring evidence remains missing.
- Release posture: public beta and production remain blocked until the
  release-readiness dashboard accepts the required non-local evidence.

This document covers monitor design, source artifacts, event/read expectations,
alert categories, dashboard/query requirements, and incident handoff. It does
not define production thresholds for a specific RPC provider, indexer, alert
vendor, or 6529.io deployment.

## Source Of Truth

Monitoring consumers must read committed release artifacts and checked docs,
not hand-maintained copies:

- [README.md](../README.md)
- [docs/release-readiness.md](release-readiness.md)
- [docs/non-local-release-evidence.md](non-local-release-evidence.md)
- [docs/incident-response.md](incident-response.md)
- [docs/integrations/README.md](integrations/README.md)
- [docs/integrations/events-and-indexing.md](integrations/events-and-indexing.md)
- [docs/integrations/operator-admin-ui.md](integrations/operator-admin-ui.md)
- [docs/operator-dashboard-query-model.md](operator-dashboard-query-model.md)
- [docs/integrations/auction-flows.md](integrations/auction-flows.md)
- [docs/integrations/withdrawals-and-credits.md](integrations/withdrawals-and-credits.md)
- [docs/drop-authorization-signing.md](drop-authorization-signing.md)
- [docs/signer-custody-readiness.md](signer-custody-readiness.md)
- [docs/randomizer-operations.md](randomizer-operations.md)
- [docs/dependency-operations.md](dependency-operations.md)
- [docs/metadata.md](metadata.md)
- [docs/deployment.md](deployment.md)
- [docs/protocol-surface.md](protocol-surface.md)
- [docs/custom-errors.md](custom-errors.md)
- [docs/release-policy.md](release-policy.md)
- [release-artifacts/latest/release-manifest.json](../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/event-topic-catalog.json](../release-artifacts/latest/event-topic-catalog.json)
- [release-artifacts/latest/interface-ids.json](../release-artifacts/latest/interface-ids.json)
- [release-artifacts/latest/protocol-surface-report.json](../release-artifacts/latest/protocol-surface-report.json)
- [release-artifacts/latest/custom-error-catalog.json](../release-artifacts/latest/custom-error-catalog.json)
- [release-artifacts/latest/risk-register.json](../release-artifacts/latest/risk-register.json)
- [release-artifacts/latest/public-beta-evidence.json](../release-artifacts/latest/public-beta-evidence.json)
- [release-artifacts/latest/release-evidence-packet-index.md](../release-artifacts/latest/release-evidence-packet-index.md)
- [deployments/schema/deployment-manifest.schema.json](../deployments/schema/deployment-manifest.schema.json)
- [deployments/schema/address-book.schema.json](../deployments/schema/address-book.schema.json)
- [deployments/address-books/anvil-6529stream-v0.1.0-001.json](../deployments/address-books/anvil-6529stream-v0.1.0-001.json)
- [deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json](../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json)
- [smart-contracts/StreamAdmins.sol](../smart-contracts/StreamAdmins.sol)
- [smart-contracts/StreamDrops.sol](../smart-contracts/StreamDrops.sol)
- [smart-contracts/AuctionContract.sol](../smart-contracts/AuctionContract.sol)
- [smart-contracts/StreamMinter.sol](../smart-contracts/StreamMinter.sol)
- [smart-contracts/StreamRandomizerLifecycle.sol](../smart-contracts/StreamRandomizerLifecycle.sol)
- [smart-contracts/RandomizerRNG.sol](../smart-contracts/RandomizerRNG.sol)
- [smart-contracts/RandomizerVRF.sol](../smart-contracts/RandomizerVRF.sol)
- [smart-contracts/StreamCore.sol](../smart-contracts/StreamCore.sol)
- [test/StreamEventReconstructability.t.sol](../test/StreamEventReconstructability.t.sol)
- [test/StreamPauseControls.t.sol](../test/StreamPauseControls.t.sol)
- [test/StreamAuctionPayments.t.sol](../test/StreamAuctionPayments.t.sol)
- [test/StreamRandomizerLifecycle.t.sol](../test/StreamRandomizerLifecycle.t.sol)
- [test/StreamRandomizerPayments.t.sol](../test/StreamRandomizerPayments.t.sol)
- [test/StreamSignerAdmin.t.sol](../test/StreamSignerAdmin.t.sol)

## Data Sources

The monitoring source of truth is a reconciliation of:

- chain logs decoded through `release-artifacts/latest/event-topic-catalog.json`;
- deployment manifests and address books for emitter allowlists and chain IDs;
- read-after-event calls against release-tracked contracts;
- release artifacts, checksums, ABI hashes, runtime bytecode hashes, and
  interface IDs;
- non-local release evidence envelopes when fork/testnet/live monitoring
  evidence exists;
- incident-response and deployment runbooks for escalation and retained
  evidence.

Use the checked `GOV-010` operator dashboard query model when turning these
monitor categories into concrete environment/release, admin, signer,
fixed-price, auction, randomizer, payment, metadata/dependency, release
blocker, and incident drill panels.

Every monitor must include chain ID, deployment version, contract address,
block number, block hash, transaction hash, log index, event signature, and
normalized log identity. Indexers must keep a confirmation depth and reorg
rollback policy consistent with the event and indexer reconstruction spec.

## Event Coverage

Every external state transition that matters to operations should be observable
through either an event, a read-after-event call, or an explicit known gap in
the events and indexing guide. The monitoring catalog must include stable IDs
and commonly queried indexed fields for these families:

| Family | Required examples | Stable identity |
| --- | --- | --- |
| Admin and roles | `GlobalAdminUpdated`, `FunctionAdminUpdated`, `PauseGuardianUpdated`, `UnpauseAdminUpdated`, `SignerManagerUpdated`, `SignerLifecycleTargetUpdated`, `EmergencyRecipientUpdated` | admin domain, selector, account, role, transaction |
| Signer and drop authorization | `DropSignerChanged`, `SignerEpochChanged`, `DropAuthorizationCancelled` | collection, drop, signer, signer epoch, cancel scope |
| Pause and emergency | `PauseUpdated`, `EmergencyWithdrawal` | pause domain, account, recipient, amount |
| Auction | auction creation, bid, settlement, cancellation, token custody, previous bidder credit | collection, token, auction, bidder, settlement transaction |
| Payments and credits | owed-balance changes, withdrawal attempts, failed withdrawal credit retention, emergency-withdrawable surplus | beneficiary, credit category, amount, token/collection where relevant |
| Randomizer | randomizer registration, request, fulfillment, stale or failed fulfillment, provider epoch | collection, token, request ID, randomizer, randomizer epoch |
| Metadata and dependency | `CollectionFrozen`, `PermanentURI`, ERC-4906 metadata update, `DependencyVersionCreated`, `DependencyVersionDeprecated`, `DependencyVersionPinned` | collection, token, dependency, version, URI hash |
| Release evidence | release manifest, checksum bundle, address book, bytecode proof, evidence packet index | release version, deployment version, artifact path, artifact hash |

When an expected event does not exist yet, the monitor design must record the
read model and the residual risk rather than pretending the event is available.

## Admin And Role Monitoring

Admin monitoring covers owner changes, global admin grants, function admin
grants, signer manager grants, signer lifecycle target grants, pause guardian
grants, unpause admin grants, emergency recipient changes, and any selector
permission mismatch.

Required monitors:

- alert on any role change outside an approved Safe or multisig ceremony;
- alert on role grants to zero address, unexpected EOA, unexpected contract,
  or address not present in the reviewed address book;
- alert on selector coverage drift for `DROP_EXECUTION`, `MINT`,
  `AUCTION_BID`, `AUCTION_SETTLEMENT`, `METADATA_MUTATION`,
  `RANDOMNESS_REQUEST`, and emergency withdrawal domains;
- alert on admin ceremony evidence that is missing reviewer metadata,
  post-state reads, or retained artifact hashes;
- record two-person review, calldata decoding, simulation or dry-run, and
  post-state read evidence for every privileged transition.

The operator admin UI may display these monitors, but this specification is not
a maintained operator dashboard commitment.

## Signer And Drop Authorization Monitoring

Signer and drop authorization monitoring covers `updateTDHsigner`,
`incrementSignerEpoch`, `cancelDrop`, EIP-712 domain changes, ERC-1271 support
status, per-drop cancellation, per-signer nonce invalidation, signer epoch
rotation, and signer compromise response.

Required monitors:

- alert on signer rotation without matching signer custody readiness evidence;
- alert on signer compromise drill evidence that is missing pause,
  rotation/revocation, epoch invalidation, cancellation, stale-payload
  rejection, recovered payload, monitoring handoff, reviewer, or redaction
  proof from
  `release-artifacts/evidence/incident-drills/signer-compromise-drill-retained-artifact-template.md`;
- alert on signer epoch increments, drop cancellations, or signer lifecycle
  target changes outside approved incident or ceremony windows;
- alert on any accepted drop authorization whose chain ID, verifying contract,
  signer, signer epoch, deadline, nonce, drop ID, or consumed-state storage
  does not match the expected source of truth;
- track EOA, ERC-1271, and Safe signature paths separately so contract signer
  support is visible rather than assumed;
- retain no secrets and no unreleased drop payloads in monitoring logs.

EIP-712 is encoding and signing only. Replay protection still requires domain,
deadline, nonce or drop ID, signer rotation, and consumed-state storage.

## Auction Monitoring

Auction monitoring covers the canonical states `None`, `Created`, `Active`,
`EndedNoBid`, `EndedWithBid`, `SettledNoBid`, `SettledWithBid`, and
`Cancelled`.

Required monitors:

- token custody is known at all times for every auctioned token;
- a previous bidder refund becomes withdrawable credit when outbid;
- settlement is idempotent and does not double-send token or ETH value;
- stuck auctions are flagged when state, end time, token custody, and owed
  balances disagree;
- alert on stuck auction drill evidence that is missing auction identity,
  stuck condition, custody snapshot, pause/unpause proof, terminal settlement
  or cancellation, bidder/proceeds credit proof, withdrawal availability,
  emergency-surplus boundary, monitoring handoff, reviewer, or redaction proof
  from
  `release-artifacts/evidence/incident-drills/stuck-auction-drill-retained-artifact-template.md`;
- bid pause and settlement pause domains are monitored separately;
- failed settlement, failed refund, and failed withdrawal paths preserve
  credits rather than erasing balances;
- frontends and indexers can reconstruct current auction state from events plus
  read-after-event calls.

Alerting must distinguish outbid refund credit, poster proceeds, curator
rewards, protocol surplus, and emergency-withdrawable surplus.

## Randomizer Monitoring

Randomizer monitoring covers provider registration, request creation,
fulfillment, stale requests, provider funding, provider reserve, request ID,
collection, token, randomizer address, and randomizer epoch.

Required monitors:

- fulfillment validates request ID, token, collection, randomizer address, and
  randomizer epoch;
- fulfillment from an unexpected provider, stale epoch, stale request, wrong
  token, wrong collection, or duplicate callback is critical;
- provider funding and reserve status are visible before mint windows that
  depend on randomness;
- failed randomness and pending request age thresholds trigger the incident
  response runbook;
- public beta and production release monitors should alert if no reviewed
  failed-randomness drill retained artifact exists at
  `release-artifacts/evidence/incident-drills/failed-randomness-drill-retained-artifact-template.md`;
- randomizer changes are tied to deployment manifests, address books, and
  reviewed randomizer operations evidence before public beta or production.

## Payment And Credit Monitoring

Payment monitoring covers poster credits, bidder credits, curator credits,
protocol surplus, total owed views, emergency withdrawable balance, failed
withdrawals, and ETH balance coverage.

Required invariants:

- total owed equals the sum of category owed balances;
- contract balance covers owed balances;
- failed withdrawal does not erase credit;
- emergency withdrawal cannot withdraw owed funds;
- auction proceeds, outbid refunds, fixed-price proceeds, curator rewards, and
  surplus are displayed as separate categories;
- every withdrawal attempt records beneficiary, category, amount, success or
  failure, and resulting credit.

Any mismatch between owed views and contract balance is a critical alert until
triaged.

## Metadata And Dependency Monitoring

Metadata and dependency monitoring covers collection freeze, token URI
finality, ERC-4906 metadata update events, dependency version creation,
dependency deprecation, dependency pinning, contract metadata updates, renderer
dependencies, and marketplace/indexer refresh evidence.

Required monitors:

- alert on metadata mutation after collection freeze unless the contract
  explicitly allows and documents the transition;
- alert when JSON metadata changes without the expected ERC-4906 or equivalent
  cache-invalidation signal;
- alert on dependency deprecation or pin changes that do not have retained
  dependency operation evidence;
- public beta and production release monitors should alert if no reviewed bad
  metadata/dependency drill retained artifact exists at
  `release-artifacts/evidence/incident-drills/bad-metadata-dependency-drill-retained-artifact-template.md`;
- link collector-facing 1/1 provenance and permanence claims to reviewed
  artifacts before production display.

## Release Evidence Monitoring

Release monitoring covers release manifest drift, checksum drift, ABI checksum
changes, event topic catalog changes, interface ID changes, source verification
inputs, bytecode proof, public-beta evidence status, risk register, release
evidence packet index, release evidence issue links, and blocker reports.

Required monitors:

- alert when a release-impacting PR changes a covered artifact without
  changelog, release manifest, bytecode proof, and checksum updates;
- alert when public-beta or production evidence is marked complete without a
  reviewed non-local evidence envelope;
- alert when a tracker issue is closed before the release evidence issue
  closure checker accepts the underlying evidence status;
- alert when a production-ready claim appears without CI, checksum bundle,
  signatures, signed tag, verified addresses, explorer verification, audit, and
  post-audit remediation evidence.

## Alert Severity Model

Use four severities until a production monitoring service chooses concrete
routing:

| Severity | Meaning | Examples |
| --- | --- | --- |
| Critical | Potential fund loss, unauthorized admin action, signer compromise, invalid custody, randomness spoofing, or release-readiness false positive | owed balance not covered, unexpected signer epoch, wrong randomizer fulfillment, emergency withdrawal touching owed funds |
| High | User-visible failure or blocked settlement/mint requiring operator action | stale randomizer request, stuck auction, failed withdrawals accumulating, missing reviewed evidence for a planned release claim |
| Medium | Degraded observability or integration inconsistency | missing read-after-event refresh, unindexed field needed by dashboards, stale address book in a non-production environment |
| Low | Documentation, dashboard, or evidence hygiene issue | missing runbook cross-link, stale display label, outdated local evidence comment |

Critical and High alerts require incident-response handoff and retained
evidence. Medium and Low alerts can follow normal release or documentation
maintenance unless they accumulate into a launch blocker.

## Dashboard And Query Model

A future operator dashboard or indexer query model should expose:

- deployment selector: chain ID, deployment version, release manifest hash,
  address book hash, and contract address allowlist;
- admin activity: role grants/revokes, selector domains, pause domains,
  emergency recipient, and Safe transaction references;
- signer activity: active signer, signer epoch, per-drop signer, cancellations,
  EIP-712 domain, ERC-1271 status, and signer custody evidence status;
- auction health: state, token custody, highest bidder, previous bidder credit,
  end time, settlement status, pause status, and stuck-state reason;
- randomizer health: provider, epoch, funding, request ID, pending age,
  fulfillment status, stale request status, and reserve status;
- payments and credits: poster owed, bidder owed, curator owed, protocol
  surplus, total owed, contract balance, emergency withdrawable, and failed
  withdrawals;
- metadata and dependency state: frozen status, latest URI hash, ERC-4906 event
  activity, dependency pins, deprecations, and marketplace/indexer evidence;
- release evidence: public-beta status, production status, blockers, issue
  links, CI run, checksum bundle, signatures, and signed tag status.

Dashboard rows must never require private keys, mnemonics, signer-service
credentials, RPC URLs, API keys, webhook URLs, or unreleased drop payloads.

## Incident Handoff

Critical and High alerts route to [docs/incident-response.md](incident-response.md)
and should retain no-secret evidence using
[docs/non-local-release-evidence.md](non-local-release-evidence.md) when the
incident affects fork/testnet/live readiness.

Minimum retained evidence:

- alert name, severity, monitor version, chain ID, deployment version, contract
  address, block number, transaction hash, log index, and normalized log ID;
- decoded event payload or read-after-event diff with secrets redacted;
- reviewer, second reviewer for privileged actions, and incident owner;
- runbook section used, mitigation taken, and post-state read;
- links to any GitHub issue, release evidence record, deployment manifest,
  address book, release manifest, checksum bundle, and CI run.

## Validation Commands

Run the focused monitoring checks:

```sh
python scripts/test_monitoring_spec.py
python scripts/check_monitoring_spec.py
python scripts/test_operator_dashboard_query_model.py
python scripts/check_operator_dashboard_query_model.py
```

Run the surrounding documentation checks:

```sh
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_readme.py
python scripts/check_readme.py
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
python scripts/check_changelog.py
make monitoring-spec-check
make check
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update this specification when any of the following change:

- admin, signer, auction, randomizer, payment, metadata, dependency, or release
  evidence events;
- deployment manifests, address books, ABI hashes, event topic catalogs,
  interface IDs, custom errors, or release artifact names;
- launch gates, release-mode evidence requirements, incident runbooks, signer
  custody evidence, randomizer operations evidence, or non-local release
  evidence intake rules;
- public beta or production readiness status.

Regenerate the release manifest and checksum bundle after changing this file,
because it is a governance document in the release evidence package.
