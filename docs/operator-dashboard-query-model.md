# Operator Dashboard Query Model

This `GOV-010` query model is a pre-audit local baseline for teams building a
6529Stream operator dashboard, monitoring console, indexer view, or internal
6529.io operations surface. It is not production-ready, not a security claim,
and does not replace fork/testnet/live evidence, reviewed deployment evidence,
external audit, production signer custody evidence, or a maintained monitoring
service.

The goal is to translate the `GOV-009` protocol monitoring specification into
dashboard panels and query contracts: which question each panel answers, which
release artifacts and chain sources it reads, how stale data is detected, which
severity it maps to, and what an operator is allowed to do next. No secrets,
private keys, mnemonics, RPC URLs, API keys, webhook URLs, signer-service
credentials, raw signatures, Safe signing secrets, or unreleased drop payloads
belong in dashboard configuration, telemetry, screenshots, or retained evidence.

## Maturity And Scope

Current maturity:

- Repository status: pre-audit local baseline.
- Dashboard implementation status: specification only; no maintained
  dashboard, hosted monitoring service, alert-provider integration, Safe app,
  signer custody implementation, RPC provider, indexer backend, or production
  telemetry pipeline is committed.
- Evidence status: local and retained fork-mainnet rehearsal artifacts exist,
  while reviewed testnet/live dashboard evidence remains missing.
- Release posture: public beta and production remain blocked until the
  release-readiness dashboard accepts the required non-local evidence.

This model covers dashboard panel intent, query inputs, source artifacts,
contract reads, event sources, freshness checks, severity mapping,
read-after-event queues, incident handoff, and no-secret telemetry boundaries.
It does not choose a database schema, frontend framework, alert vendor, RPC
provider, 6529.io deployment, or final production thresholds.

## Source Of Truth

Dashboard consumers must read committed release artifacts and checked docs, not
hand-maintained copies:

- [README.md](../README.md)
- [docs/monitoring.md](monitoring.md)
- [docs/release-readiness.md](release-readiness.md)
- [docs/incident-response.md](incident-response.md)
- [docs/non-local-release-evidence.md](non-local-release-evidence.md)
- [docs/integrations/README.md](integrations/README.md)
- [docs/integrations/operator-admin-ui.md](integrations/operator-admin-ui.md)
- [docs/integrations/events-and-indexing.md](integrations/events-and-indexing.md)
- [docs/integrations/contract-flows.md](integrations/contract-flows.md)
- [docs/integrations/auction-flows.md](integrations/auction-flows.md)
- [docs/integrations/withdrawals-and-credits.md](integrations/withdrawals-and-credits.md)
- [docs/integrations/wallets-and-signatures.md](integrations/wallets-and-signatures.md)
- [docs/integrations/metadata-rendering.md](integrations/metadata-rendering.md)
- [docs/drop-authorization-signing.md](drop-authorization-signing.md)
- [docs/signer-custody-readiness.md](signer-custody-readiness.md)
- [docs/randomizer-operations.md](randomizer-operations.md)
- [docs/dependency-operations.md](dependency-operations.md)
- [docs/deployment.md](deployment.md)
- [docs/release-policy.md](release-policy.md)
- [docs/public-beta-evidence.md](public-beta-evidence.md)
- [release-artifacts/latest/release-manifest.json](../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/SHA256SUMS](../release-artifacts/latest/SHA256SUMS)
- [release-artifacts/latest/release-checksums.json](../release-artifacts/latest/release-checksums.json)
- [release-artifacts/latest/bytecode-release-proof.json](../release-artifacts/latest/bytecode-release-proof.json)
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
- [smart-contracts/StreamCuratorsPool.sol](../smart-contracts/StreamCuratorsPool.sol)
- [smart-contracts/StreamRandomizerLifecycle.sol](../smart-contracts/StreamRandomizerLifecycle.sol)
- [smart-contracts/StreamCore.sol](../smart-contracts/StreamCore.sol)
- [smart-contracts/DependencyRegistry.sol](../smart-contracts/DependencyRegistry.sol)
- [test/StreamEventReconstructability.t.sol](../test/StreamEventReconstructability.t.sol)
- [test/StreamPauseControls.t.sol](../test/StreamPauseControls.t.sol)
- [test/StreamSignerAdmin.t.sol](../test/StreamSignerAdmin.t.sol)
- [test/StreamAuctionPayments.t.sol](../test/StreamAuctionPayments.t.sol)
- [test/StreamRandomizerLifecycle.t.sol](../test/StreamRandomizerLifecycle.t.sol)
- [test/StreamPaymentsInvariant.t.sol](../test/StreamPaymentsInvariant.t.sol)

## Dashboard Data Contract

Every dashboard row should expose a common data contract:

| Field | Requirement |
| --- | --- |
| `chainId` | Chain ID for the selected deployment namespace |
| `deploymentVersion` | Deployment manifest version or retained evidence ID |
| `releaseManifestHash` | SHA-256 or release manifest digest used by the view |
| `addressBookHash` | Address book digest used for emitter and contract allowlists |
| `contractAddress` | Address from the selected address book, never pasted as an unchecked default |
| `blockNumber` | Block number used for the latest event or read-after-event call |
| `blockHash` | Block hash used for reorg detection |
| `transactionHash` | Transaction hash when the row is event-derived |
| `logIndex` | Log index when the row is event-derived |
| `eventSignature` | Event signature from `event-topic-catalog.json` when present |
| `normalizedLogIdentity` | `(chainId, blockHash, transactionHash, logIndex)` for confirmed logs |
| `freshnessStatus` | `fresh`, `optimistic`, `stale`, `reorg-risk`, `missing-evidence`, or `error` |
| `severity` | `Critical`, `High`, `Medium`, `Low`, or `Info` using `docs/monitoring.md` |
| `operatorActionBoundary` | View-only, prepare Safe transaction, pause, incident handoff, or evidence update |

Dashboard rows must make local, fork, testnet, and live evidence visibly
different. A local passing check is not public beta or production readiness.

## Common Query Inputs

Every panel accepts these common query inputs:

- chain ID;
- deployment version;
- release manifest path and hash;
- release checksum bundle hash;
- address book path and hash;
- deployment manifest path and hash;
- contract address allowlist;
- event topic catalog hash;
- ABI checksum hash;
- interface IDs hash;
- confirmation depth;
- reorg rollback horizon;
- start block and end block;
- environment maturity: local, fork, testnet, or live;
- evidence status: template, missing, reviewed, waived, failed, or expired; and
- requester role: auditor, operator, integrator, release lead, or incident lead.

If any common input is missing or mismatched, the dashboard should fail closed
before presenting high-risk actions.

## Panel Catalog

The minimum operator dashboard panels are:

| Panel | Primary question | Default severity |
| --- | --- | --- |
| Environment And Release Snapshot | Which release, deployment, address book, checksum bundle, and evidence state is selected? | High when mismatched |
| Admin And Governance | Who can change roles, pause domains, update emergency recipients, or transfer ownership? | Critical |
| Signer And Drop Authorization | Which signer, signer epoch, cancellations, consumed drop IDs, EIP-712 domain, and ERC-1271 path are active? | Critical |
| Fixed-Price Drop Execution | Are signed fixed-price drops executing, crediting, and minting as expected? | High |
| Auction Health | Is each auction state, token custody, bid, settlement, and no-bid path coherent? | Critical |
| Randomizer Lifecycle | Are requests pending, fulfilled, stale, failed, retried, and provider-bound correctly? | Critical |
| Payment And Credit Solvency | Do owed balances, category credits, contract balance, surplus, and emergency withdrawable amount reconcile? | Critical |
| Metadata And Dependency State | Are frozen state, ERC-4906 signals, dependency pins, deprecations, contract metadata, and cache updates coherent? | High |
| Release Evidence And Blockers | Which public beta and production blockers remain open, waived, failed, or complete? | High |
| Incident Drill And Handoff | Which alerts require incident response, retained evidence, pause action, or reviewer handoff? | High |

Each panel must list query inputs, source artifacts, contract views, event
sources, freshness expectations, severity mapping, and operator action
boundaries. A panel that cannot meet this shape should be marked incomplete.

## Environment And Release Snapshot Panel

Purpose: prove the dashboard is reading one coherent release namespace.

Required query inputs:

- chain ID, deployment version, release manifest hash, address book hash,
  deployment manifest hash, checksum bundle hash, event topic catalog hash,
  ABI checksum hash, interface IDs hash, public-beta evidence status, and risk
  register hash.

Source artifacts:

- `release-artifacts/latest/release-manifest.json`;
- `release-artifacts/latest/release-checksums.json`;
- `release-artifacts/latest/SHA256SUMS`;
- `release-artifacts/latest/public-beta-evidence.json`;
- `release-artifacts/latest/risk-register.json`;
- selected deployment manifest and address book.

Freshness expectations:

- refresh on every app start, release change, address book change, checksum
  drift, and readiness report change;
- treat a stale checksum, missing artifact, wrong chain ID, wrong deployment
  version, or mismatched address book as High severity.

Operator action boundary: view-only until artifacts match. The dashboard can
link to release readiness but must not auto-correct release artifacts.

## Admin And Governance Panel

Purpose: show privileged authority, selector coverage, and pause/emergency
control state.

Contract views and event sources:

- `GlobalAdminUpdated`, `FunctionAdminUpdated`, `PauseGuardianUpdated`,
  `UnpauseAdminUpdated`, `SignerManagerUpdated`,
  `SignerLifecycleTargetUpdated`, `PauseUpdated`,
  `EmergencyRecipientUpdated`, and `OwnershipTransferred`;
- read-after-event calls for `retrieveGlobalAdmin`,
  `retrieveFunctionAdmin`, pause guardian, unpause admin, signer manager,
  signer lifecycle target, `isPaused(domain)`, emergency recipient, and owner.

Freshness expectations:

- update on every admin event;
- refresh every selected pause domain on dashboard load;
- mark unknown selectors, unexpected EOAs, zero addresses, or address-book
  mismatches as Critical.

Severity mapping:

- Critical: unreviewed role grant, signer lifecycle authority drift,
  emergency recipient change, owner change, or pause-domain mismatch;
- High: missing Safe or multisig ceremony evidence;
- Medium: stale post-state read.

Operator action boundary: prepare Safe or multisig ceremony only. Direct raw
contract buttons are out of scope for high-risk actions.

## Signer And Drop Authorization Panel

Purpose: make drop signing state and replay controls visible before any drop
execution or incident response.

Contract views and event sources:

- `DropSignerChanged`, `SignerEpochChanged`,
  `DropAuthorizationCancelled`, `DropAuthorizationConsumed`;
- reads for `tdhSigner()`, `signerEpoch()`, consumed drop IDs, cancelled drop
  IDs, signer custody evidence status, EIP-712 domain, and ERC-1271 support
  status.

Required row fields:

- signer, signer epoch, drop ID, nonce or salt, deadline, collection ID,
  poster, recipient, sale mode, chain ID, verifying contract, EOA or ERC-1271
  path, Safe status, cancellation status, consumed-state storage, and replay
  protection state.

Freshness expectations:

- refresh on every signer event, drop execution, or cancellation;
- mark accepted payloads from wrong domain, wrong signer, expired deadline,
  stale signer epoch, cancelled drop, replayed drop, or unexpected ERC-1271
  failure as Critical.

Operator action boundary: view, incident handoff, and ceremony preparation.
The dashboard must not expose private keys, raw signatures, signer-service
credentials, or unreleased drop payloads.

## Fixed-Price Drop Execution Panel

Purpose: track signed fixed-price drops from authorization through mint,
credits, and withdrawal readiness.

Contract views and event sources:

- `DropAuthorizationConsumed`, ERC-721 `Transfer`,
  `FixedPriceCreditCreated`, `FixedPriceCreditWithdrawn`, and relevant pause
  events;
- reads for consumed drop ID, token owner, collection supply, poster credits,
  protocol credits, curator reserve, total fixed-price owed, total reserved,
  surplus, and pause state for `DROP_EXECUTION` and `MINT`.

Freshness expectations:

- update on every drop execution, mint transfer, fixed-price credit, withdrawal,
  and pause change;
- mark mismatched mint recipient, missing credit, unpaid owed balance, failed
  withdrawal without retained credit, or paused execution bypass as High or
  Critical depending on fund impact.

Operator action boundary: view, incident handoff, or pause preparation. It
should not generate signed drop payloads.

## Auction Health Panel

Purpose: prove auction state, custody, bids, refunds, and settlement are
coherent.

Canonical states:

- `None`;
- `Created`;
- `Active`;
- `EndedNoBid`;
- `EndedWithBid`;
- `SettledNoBid`;
- `SettledWithBid`;
- `Cancelled`.

Contract views and event sources:

- `AuctionRegistered`, `AuctionCustodyConfirmed`, `AuctionStatusChanged`,
  `AuctionExtended`, `AuctionCancelled`, `Participate`, `ClaimAuction`,
  `NoBidSettlementPending`, `NoBidTokenClaimed`, `OutbidCreditCreated`,
  `BidderCreditWithdrawn`, `AuctionProceedsCreditCreated`, and
  `ProceedsCreditWithdrawn`;
- reads for auction record, highest bid, highest bidder, end time, auction
  status, token owner/custody, no-bid claimant, bidder credits, poster
  proceeds, protocol proceeds, curator proceeds, total owed, surplus, and
  `AUCTION_BID` / `AUCTION_SETTLEMENT` pause domains.

Freshness expectations:

- update on every auction event and derive ended states from current time plus
  historical read policy;
- mark unknown token custody, double settlement, missing previous bidder
  credit, settlement after cancellation, stale minter bridge end time, or owed
  balance mismatch as Critical.

Operator action boundary: view, settlement readiness explanation, incident
handoff, pause preparation, and retained evidence. The panel must distinguish
outbid refund, poster proceeds, curator proceeds, protocol surplus, and
emergency-withdrawable surplus.

## Randomizer Lifecycle Panel

Purpose: expose randomness request health, provider binding, stale/failed
states, and post-processing status.

Contract views and event sources:

- `RandomnessRequested`, `RandomnessFulfilled`,
  `RandomnessRequestMarkedStale`, `RandomnessPostProcessingFailed`,
  `RandomnessPostProcessingRetried`, `RandomnessPostProcessingRetryFailed`,
  `BurnedTokenRandomnessRecorded`, provider `RequestFulfilled`, and
  `CollectionRandomizerUpdated`;
- reads for request ID, collection ID, token ID, randomizer address,
  randomizer epoch, provider funding, reserve status, pending age, fulfilled
  state, stale state, failed state, retry count, token metadata state, and
  `RANDOMNESS_REQUEST` pause domain.

Freshness expectations:

- update on every protocol or provider randomness event;
- mark wrong request ID, wrong token, wrong collection, stale provider,
  stale randomizer epoch, duplicate callback, missing provider funding, or
  failed post-processing as Critical or High.

Operator action boundary: view, randomizer operations evidence link, incident
handoff, and pause preparation. Local randomizer evidence is not live provider
readiness proof.

## Payment And Credit Solvency Panel

Purpose: reconcile all owed balances, credits, surplus, and emergency
withdrawable amounts.

Contract views and event sources:

- fixed-price credit events, auction credit events, curator credit events,
  withdrawal events, failed-withdrawal preserving-credit behavior, and
  `EmergencyWithdrawal`;
- reads for poster credits, bidder credits, curator credits, protocol surplus,
  total owed, total reserved, contract balance, surplus,
  `emergencyWithdrawable()`, and configured `emergencyRecipient`.

Required invariants:

- total owed equals the sum of category owed balances;
- contract balance covers owed balances;
- failed withdrawal does not erase credit;
- emergency withdrawal cannot withdraw owed funds;
- forced ETH becomes surplus, not hidden owed funds.

Freshness expectations:

- update after every credit, withdrawal, bid, settlement, reward, and
  emergency withdrawal event;
- mark uncovered owed balances, negative surplus, unexpected emergency
  withdrawal, or erased failed-withdrawal credit as Critical.

Operator action boundary: view, withdrawal readiness display, incident handoff,
and emergency-withdrawal ceremony preparation only when surplus-bounded.

## Metadata And Dependency State Panel

Purpose: show collector-visible state, freeze status, dependency pins,
contract metadata, cache signals, and marketplace/indexer evidence posture.

Contract views and event sources:

- `MetadataUpdate`, `BatchMetadataUpdate`, `CollectionFrozen`,
  `PermanentURI`, `DependencyVersionCreated`,
  `DependencyVersionDeprecated`, `DependencyVersionPinned`,
  `ContractURIUpdated`, and `TokenBurned`;
- reads for token metadata state, token URI, collection freeze manifest hash,
  dependency version state, contract URI, contract URI hash, interface IDs, and
  marketplace/indexer evidence status.

Freshness expectations:

- update after every metadata, dependency, freeze, burn, contract metadata, or
  marketplace/indexer evidence change;
- mark metadata mutation after freeze, JSON change without expected ERC-4906
  signal, dependency deprecation without retained operation evidence, or
  marketplace readiness claim without reviewed evidence as High.

Operator action boundary: view, cache-invalidation explanation, dependency
operation evidence link, metadata incident handoff, and freeze ceremony
preparation.

## Release Evidence And Blocker Panel

Purpose: make public beta and production blockers visible without overstating
readiness.

Source artifacts and event sources:

- public-beta evidence status from the generated readiness artifacts;
- `release-artifacts/latest/public-beta-evidence.json`;
- `release-artifacts/latest/risk-register.json`;
- `release-artifacts/latest/release-evidence-packet-index.md`;
- `release-artifacts/latest/public-beta-blockers.md`;
- `release-artifacts/latest/production-release-blockers.md`;
- release evidence issue links, issue body sync, live audit archive, release
  manifest, checksum bundle, bytecode proof, source verification inputs,
  signed release evidence, signed tag evidence, explorer verification evidence,
  and verified-addresses evidence.

Freshness expectations:

- refresh after every release-impacting PR, evidence issue update, release
  manifest change, checksum change, or readiness report generation;
- mark completed evidence without reviewed retained artifact, closed tracker
  issue without accepted evidence, missing signature, missing audit, missing
  explorer verification, or checksum drift as High or Critical.

Operator action boundary: view, issue navigation, release evidence update, and
release-mode CI trigger. It must not mark public beta or production ready by
itself.

## Incident Drill And Handoff Panel

Purpose: route Critical and High dashboard findings to runbooks and retained
evidence.

Source artifacts and event sources:

- `docs/incident-response.md`;
- `release-artifacts/evidence/incident-drills/incident-drill-retained-artifact-template.md`;
- admin, pause, signer, randomizer, auction, metadata, dependency, payment,
  and release evidence events from the panels above.

Freshness expectations:

- update when an alert changes severity, reviewer state, mitigation state,
  retained evidence status, or reopened-blocker state;
- mark missing incident owner, missing reviewer, missing post-state read,
  missing retained evidence, or unresolved Critical alert as High or Critical.

Operator action boundary: incident handoff, pause preparation, evidence
attachment, blocker reopening, and post-state read collection. It must never
store private incident secrets in public retained artifacts.

## Freshness And Reorg Model

Every event-derived dashboard row should use the events and indexing guide:

- process new logs as optimistic;
- store block number, block hash, transaction hash, and log index;
- mark state final only after configured confirmation depth;
- retain a rollback horizon longer than the confirmation depth;
- compare block hashes inside the rollback horizon;
- roll back from the first divergent block;
- replay from the last confirmed ancestor; and
- re-run read-after-event reconciliation for affected rows.

Rows that cannot perform historical reads must be marked `read-derived` or
`repair-needed`; they must not silently present current reads as historical
truth.

## No-Secret Telemetry

Dashboard logging, telemetry, screenshots, evidence exports, and bug reports
must not contain:

- private keys;
- mnemonics;
- RPC URLs;
- API keys;
- webhook URLs;
- Slack or PagerDuty tokens;
- signer-service credentials;
- Safe signing secrets;
- raw signatures;
- unreleased drop payloads;
- local keystore paths; or
- private collector data beyond what is already public on-chain.

Use redacted values, public addresses, release artifact hashes, transaction
hashes, block numbers, and retained evidence IDs instead.

## Validation Commands

Run the focused dashboard query model checks:

```sh
python scripts/test_operator_dashboard_query_model.py
python scripts/check_operator_dashboard_query_model.py
```

Run the surrounding documentation and release checks:

```sh
python scripts/test_monitoring_spec.py
python scripts/check_monitoring_spec.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_readme.py
python scripts/check_readme.py
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
make operator-dashboard-query-model-check
make check
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

These commands validate documentation structure and release artifact
traceability only. They do not prove public beta or production dashboard
readiness.

## Maintenance

Update this model when any of these change:

- `GOV-009` monitoring categories, severities, or incident handoff rules;
- operator admin UI workflows, Safe or multisig ceremony guidance, or pause
  domains;
- event signatures, indexed fields, read-after-event calls, or indexer
  reconstruction policy;
- release manifest, checksum, bytecode proof, public-beta evidence, risk
  register, or release evidence issue artifacts;
- admin, signer, drop authorization, auction, randomizer, payment, metadata,
  dependency, or emergency withdrawal behavior;
- chain-specific confirmation depth or reorg policy;
- dashboard no-secret telemetry expectations; or
- public beta or production readiness status.

Regenerate the release manifest and checksum bundle after changing this file,
because it is a governance document in the release evidence package.
