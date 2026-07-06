# Operator Admin UI Specification

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](../spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

This is the INT-010 integration guide for teams building a 6529.io operator UI
or internal admin dashboard around 6529Stream. It is a pre-audit local baseline,
not production-ready, and not a security claim. Local evidence does not replace
fork/testnet/live evidence for public beta or production use.

The guide is documentation-only. It does not add an operator UI, Safe app,
multisig transaction builder, backend service, role-management package,
monitoring service, signer custody implementation, deployment tooling, or
production readiness claim to this contracts repository.

## Maturity And Scope

Use this guide when designing an operator UI that prepares, reviews, submits,
tracks, and reconciles 6529Stream administration actions.

Current scope:

- operator personas and permission boundaries;
- deployment artifact, address book, release manifest, ABI checksum, event
  topic catalog, interface IDs, risk register, and public-beta evidence inputs;
- StreamAdmins owner, global admin, function admin, pause guardian, unpause
  admin, signer manager, and signer lifecycle target flows;
- signer lifecycle flows for `updateTDHsigner`, `incrementSignerEpoch`, and
  `cancelDrop`;
- pause-domain operations for DROP_EXECUTION, MINT, AUCTION_BID,
  AUCTION_SETTLEMENT, METADATA_MUTATION, and RANDOMNESS_REQUEST;
- metadata freeze, dependency, randomizer, emergency withdrawal, and deployment
  ceremony workflows;
- Safe and multisig review, batching, simulation, and evidence capture; and
- monitoring, incident response, post-state reads, and release-readiness links.

Current non-scope:

- a maintained operator dashboard commitment;
- a production Safe app, transaction service, or wallet connector;
- final mainnet Safe owners, owner threshold, signer set, or operational
  staffing model;
- live RPC, private key, mnemonic, API key, or signer-service configuration;
- public beta, production, live deployment, explorer verification, or live
  admin ceremony approval; and
- replacing the governance, deployment, incident, randomizer, signer custody,
  or non-local evidence runbooks.

## Source Of Truth

Start from committed release artifacts and governance docs before designing an
admin surface:

- [docs/integrations/README.md](README.md)
- [docs/integrations/contract-flows.md](contract-flows.md)
- [docs/integrations/auction-flows.md](auction-flows.md)
- [docs/integrations/wallets-and-signatures.md](wallets-and-signatures.md)
- [docs/integrations/events-and-indexing.md](events-and-indexing.md)
- [docs/integrations/metadata-rendering.md](metadata-rendering.md)
- [docs/integrations/frontend-reference-architecture.md](frontend-reference-architecture.md)
- [docs/integrations/mobile-walletconnect.md](mobile-walletconnect.md)
- [docs/integrations/electron-security-wallets.md](electron-security-wallets.md)
- [docs/deployment.md](../deployment.md)
- [docs/incident-response.md](../incident-response.md)
- [docs/signer-custody-readiness.md](../signer-custody-readiness.md)
- [docs/randomizer-operations.md](../randomizer-operations.md)
- [docs/drop-authorization-signing.md](../drop-authorization-signing.md)
- [docs/metadata.md](../metadata.md)
- [docs/dependency-operations.md](../dependency-operations.md)
- [docs/release-readiness.md](../release-readiness.md)
- [docs/non-local-release-evidence.md](../non-local-release-evidence.md)
- [docs/public-beta-evidence.md](../public-beta-evidence.md)
- [docs/architecture.md](../architecture.md)
- [docs/threat-model.md](../threat-model.md)
- [docs/adr/0004-admin-governance.md](../adr/0004-admin-governance.md)
- [docs/adr/0005-randomness.md](../adr/0005-randomness.md)
- [docs/adr/0006-metadata-freeze.md](../adr/0006-metadata-freeze.md)
- [docs/adr/0007-upgrade-redeployment.md](../adr/0007-upgrade-redeployment.md)
- [release-artifacts/latest/release-manifest.json](../../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/abi-checksums.json](../../release-artifacts/latest/abi-checksums.json)
- [release-artifacts/latest/event-topic-catalog.json](../../release-artifacts/latest/event-topic-catalog.json)
- [release-artifacts/latest/interface-ids.json](../../release-artifacts/latest/interface-ids.json)
- [release-artifacts/latest/risk-register.json](../../release-artifacts/latest/risk-register.json)
- [release-artifacts/latest/public-beta-evidence.json](../../release-artifacts/latest/public-beta-evidence.json)
- [deployments/schema/deployment-manifest.schema.json](../../deployments/schema/deployment-manifest.schema.json)
- [deployments/schema/address-book.schema.json](../../deployments/schema/address-book.schema.json)
- [deployments/config/sepolia-6529stream-v0.1.0-001.template.json](../../deployments/config/sepolia-6529stream-v0.1.0-001.template.json)
- [deployments/address-books/anvil-6529stream-v0.1.0-001.json](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json)
- [deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json)
- [smart-contracts/StreamAdmins.sol](../../smart-contracts/StreamAdmins.sol)
- [smart-contracts/StreamPauseDomains.sol](../../smart-contracts/StreamPauseDomains.sol)
- [smart-contracts/StreamDrops.sol](../../smart-contracts/StreamDrops.sol)
- [smart-contracts/StreamCore.sol](../../smart-contracts/StreamCore.sol)
- [smart-contracts/AuctionContract.sol](../../smart-contracts/AuctionContract.sol)
- [smart-contracts/StreamMinter.sol](../../smart-contracts/StreamMinter.sol)
- [smart-contracts/StreamCuratorsPool.sol](../../smart-contracts/StreamCuratorsPool.sol)
- [smart-contracts/DependencyRegistry.sol](../../smart-contracts/DependencyRegistry.sol)
- [smart-contracts/RandomizerRNG.sol](../../smart-contracts/RandomizerRNG.sol)
- [smart-contracts/RandomizerVRF.sol](../../smart-contracts/RandomizerVRF.sol)
- [smart-contracts/StreamRandomizerLifecycle.sol](../../smart-contracts/StreamRandomizerLifecycle.sol)
- [test/StreamAdmins.t.sol](../../test/StreamAdmins.t.sol)
- [test/StreamAdminSelectors.t.sol](../../test/StreamAdminSelectors.t.sol)
- [test/StreamCoreAdminCharacterization.t.sol](../../test/StreamCoreAdminCharacterization.t.sol)
- [test/StreamSignerAdmin.t.sol](../../test/StreamSignerAdmin.t.sol)
- [test/StreamPauseControls.t.sol](../../test/StreamPauseControls.t.sol)
- [test/StreamEmergencyWithdraw.t.sol](../../test/StreamEmergencyWithdraw.t.sol)
- [test/StreamMetadataFreeze.t.sol](../../test/StreamMetadataFreeze.t.sol)
- [test/StreamDependencyRegistry.t.sol](../../test/StreamDependencyRegistry.t.sol)
- [test/StreamRandomizerLifecycle.t.sol](../../test/StreamRandomizerLifecycle.t.sol)

The operator UI must load contract addresses from an address book and deployment
manifest, then verify the release manifest, ABI checksum, event topic catalog,
interface IDs, risk register, and public-beta evidence for the selected
environment. Do not let operators paste arbitrary contract addresses into
high-risk flows without an explicit break-glass path and retained evidence.

## Non-Goals

This guide is not a maintained operator dashboard commitment and does not define
a supported 6529 operations stack.

This PR intentionally does not:

- add a Safe app, multisig transaction builder, wallet connector, backend API,
  monitoring agent, or generated SDK;
- choose final mainnet Safe owners, owner threshold, signer identities, pause
  guardians, unpause admins, deployer policy, or reviewer roster;
- implement transaction simulation, Tenderly, Defender, Safe Transaction
  Service, hardware wallet, or cloud signer integrations;
- commit private keys, mnemonics, RPC URLs, API keys, signer-service
  credentials, Safe signing secrets, local keystore paths, raw signatures, or
  unreleased drop payloads;
- claim that local Anvil or fork evidence is public beta or production admin
  ceremony evidence; or
- replace incident response, deployment, randomizer operations, signer custody,
  or non-local evidence retained-artifact procedures.

## Operator Personas

An operator UI should model people and systems by responsibility, not by private
key location.

| Persona | Responsibility | UI boundary |
| --- | --- | --- |
| Release lead | Selects release commit, artifact bundle, deployment manifest, and readiness posture | Can prepare but should not unilaterally execute high-risk actions |
| Protocol maintainer | Reviews contract call, selector, domain, event, and post-state expectations | Must review signer, pause, freeze, randomizer, dependency, and emergency actions |
| Safe signer | Approves Safe or multisig transactions | Sees human-readable calldata, risk label, simulation result, and evidence link |
| Operations maintainer | Executes allowed deployment, pause, randomizer, monitoring, and evidence procedures | Uses no-secret runbooks and retained public artifacts |
| Incident lead | Owns severity, containment, recovery, communications, and reopening criteria | Can request pause or recovery actions but still needs ceremony approval |
| Reviewer | Confirms pre-state, transaction, post-state, and retained evidence | Must be independent for high-risk actions |

Do not make the browser, Electron renderer, mobile app, or operator UI the
protocol drop signer. DropAuthorization signing remains a signer custody and
backend signing-service concern unless a future accepted decision explicitly
changes that boundary.

## Environment And Artifacts

Every operator session starts with a selected environment and artifact bundle.

Required environment inputs:

- chain ID and network name;
- address book path and hash;
- deployment manifest path and hash;
- release manifest path and hash;
- ABI checksum and ABI surface version;
- event topic catalog version;
- interface IDs version;
- risk register status;
- public-beta evidence status;
- expected Safe or multisig address;
- expected deployer or broadcaster address;
- expected drop signer, signerEpoch, and signer custody evidence status;
- expected randomizer provider, provider funding, and randomizer epoch status;
  and
- evidence-retention destination for post-state reads, transaction hashes, and
  reviewer signoff.

The UI should show a red readiness banner when the selected environment is
template-only, local-only, fork-only, missing explorer verification, missing
admin ceremony evidence, missing signer custody evidence, missing randomizer
operations evidence, missing public-beta evidence, or missing production
signature evidence.

## Permissions And Role Model

The current admin surface is centered on `StreamAdmins` and `Ownable`.

Important role concepts:

- `owner`: controls `StreamAdmins` root administration and selected Ownable
  contracts;
- `global admin`: can satisfy function-admin checks across target contracts;
- `function admin`: can call a specific target contract selector;
- `pause guardian`: can pause a domain through `setPaused`;
- `unpause admin`: can unpause a domain through `setPaused`;
- `signer manager`: can grant or revoke signer lifecycle function admins;
- `signer lifecycle target`: marks a target contract where signer lifecycle
  selectors can be delegated; and
- `emergencyRecipient`: receives permitted surplus emergency withdrawals.

The UI must treat these roles as distinct. A signer manager is not a drop
signer. A pause guardian is not automatically an unpause admin. A global admin
is a high-risk break-glass role and should be surfaced separately from
selector-scoped function admin grants.

## Workflow Matrix

Each operator workflow should be represented as a reviewed action card with a
pre-state read, a simulation or dry-run when available, a Safe transaction or
approved signer path, an event expectation, a post-state read, and retained
evidence.

| Workflow | Contract call or source | Preconditions | Expected event or post-state | Risk label |
| --- | --- | --- | --- | --- |
| Root admin grant | `StreamAdmins.registerAdmin` | Safe/multisig owner, nonzero account, two-person review | `GlobalAdminUpdated` and `retrieveGlobalAdmin(account) == true` | Critical |
| Function admin grant | `StreamAdmins.registerFunctionAdmin` or `registerBatchFunctionAdmin` | Safe owner, target address from manifest, selector from ABI checksum | `FunctionAdminUpdated` and `retrieveFunctionAdmin(account,target,selector)` | Critical |
| Signer manager grant | `StreamAdmins.registerSignerManager` | Safe owner, no-secret signer custody plan | `SignerManagerUpdated` | Critical |
| Signer lifecycle target grant | `StreamAdmins.registerSignerLifecycleTarget` | Safe owner, target is the expected `StreamDrops` address | `SignerLifecycleTargetUpdated` | Critical |
| Signer function grant | `registerSignerFunctionAdmin` or `registerBatchSignerFunctionAdmin` | Owner or signer manager, selector is signer lifecycle only | `FunctionAdminUpdated` for `updateTDHsigner`, `incrementSignerEpoch`, or `cancelDrop` | Critical |
| Pause role grant | `registerPauseGuardian` or `registerUnpauseAdmin` | Safe owner and incident-response reviewer | `PauseGuardianUpdated` or `UnpauseAdminUpdated` | High |
| Pause domain update | `setPaused(domain, paused, reason)` | Domain selected from known constants and reason recorded | `PauseUpdated` and `isPaused(domain)` | High |
| Emergency recipient update | `updateEmergencyRecipient` | Safe owner, nonzero recipient, evidence path | `EmergencyRecipientUpdated` | Critical |
| Drop signer rotation | `StreamDrops.updateTDHsigner` | New signer custody reviewed, old/new signer recorded | `DropSignerChanged` and active signer read | Critical |
| Signer epoch increment | `StreamDrops.incrementSignerEpoch` | Compromise or rotation reason retained | `SignerEpochChanged` and stale signed payloads rejected | Critical |
| Drop cancellation | `StreamDrops.cancelDrop` | `dropId` confirmed, not consumed, reason retained | `DropAuthorizationCancelled` and `isDropCancelled(dropId)` | High |
| Metadata freeze | `StreamCore.freezeCollection` | Freeze eligibility, manifest preview, dependency state reviewed | `CollectionFrozen` and freeze manifest hash read | Critical |
| Randomizer update | `StreamCore.addRandomizer` | Provider address, provider funding, epoch, and callbacks reviewed | `CollectionRandomizerUpdated` and randomizer epoch read | Critical |
| Dependency create or deprecate | `DependencyRegistry.addDependency`, `addDependencyWithProvenance`, `addDependencyScriptIndex`, or `deprecateDependencyVersion` | Source/provenance retained and content hash reviewed | `DependencyVersionCreated`, `DependencyVersionDeprecated`, or `DependencyVersionPinned` | High |
| Emergency withdrawal | `emergencyWithdrawable` then `emergencyWithdraw` | Owed/reserved funds covered, surplus amount bounded | `EmergencyWithdrawal` and post-state balance read | Critical |

Operator UI cards should never show high-risk calls as raw contract buttons.
They should show why the action exists, who approved it, which Safe transaction
or signer path will execute it, what changes in state, what event should fire,
and where the retained evidence will live.

## Safe And Multisig Ceremony

Safe and multisig execution is first-class. For public beta and production, a
high-risk action should be built as a Safe transaction or approved multisig
ceremony unless the runbook explicitly records a reviewed exception.

The operator UI should require:

- Safe address match against deployment manifest and address book;
- owner threshold display before transaction creation;
- calldata decoded against the checked ABI checksum;
- target contract address match against the release manifest;
- selector display using the human-readable function name;
- batch preview when multiple role grants or ownership transfers are grouped;
- simulation or dry-run result when available;
- reviewer signoff before proposing the Safe transaction;
- transaction hash, Safe transaction ID, block number, and confirmation depth
  after execution; and
- post-state reads proving role, signer, pause, randomizer, freeze, dependency,
  or emergency state changed as expected.

Batching can reduce ceremony risk for deployment setup, but it can also hide
dangerous side effects. The UI should split batches by risk class and show a
human-readable diff for every target, selector, account, domain, and recipient.

## Signer Lifecycle

Signer lifecycle flows are security-critical and should be separated from
ordinary admin actions.

Required signer screens:

- current `tdhSigner`, signerEpoch, signer custody readiness status, and active
  signer type;
- pending drop authorizations affected by the action;
- consumed and cancelled drop-state lookup for any specific `dropId`;
- proposed `updateTDHsigner` target, with EOA or ERC-1271 contract status;
- proposed `incrementSignerEpoch` action, with stale-payload impact language;
- proposed `cancelDrop` action, with drop ID, signer, epoch, nonce, salt,
  deadline, poster, collection, sale mode, and tokenDataHash summary; and
- incident response link for signer compromise.

The UI should state that EIP-712 is encoding and signing only. Replay protection
depends on `consumedDropIds`, `cancelledDropIds`, signerEpoch, deadline, and the
signer-service nonce/salt policy. Operator screens must not display private
keys, mnemonics, raw signatures, signer-service credentials, or unreleased drop
payloads.

## Pause And Incident Controls

Pause controls must be domain-specific. Do not present a single generic pause
button.

Supported domains:

- DROP_EXECUTION for drop execution and compromised signer containment;
- MINT for mint flow containment;
- AUCTION_BID for new auction bids;
- AUCTION_SETTLEMENT for settlement paths;
- METADATA_MUTATION for metadata mutation and freeze-related changes; and
- RANDOMNESS_REQUEST for new randomness requests.

Every pause action should require:

- domain selected from known constants;
- proposed paused value;
- reason hash or reason text converted to retained evidence;
- incident severity and incident lead;
- expected impact on user flows;
- withdrawal availability statement;
- unpause owner or unpause admin path; and
- post-state read from `StreamAdmins.isPaused(domain)`.

The UI should link to incident response before execution and should keep
withdrawal behavior explicit. A pause is containment, not data deletion.

## Metadata And Dependency Operations

Metadata and dependency actions affect collector-visible output and marketplace
cache behavior.

Required UI checks:

- show collection ID, current metadata mode, minted supply, dependency version,
  and freeze status;
- preview `previewCollectionFreezeManifestHash` before `freezeCollection`;
- show `collectionFreezeManifestHash` after `CollectionFrozen`;
- confirm dependency source retention before `addDependency` or
  `addDependencyWithProvenance`;
- show script chunk count and content hash before and after dependency changes;
- show `DependencyVersionCreated`, `DependencyVersionDeprecated`, and
  `DependencyVersionPinned` event expectations;
- warn that metadata freeze is intended to be irreversible; and
- link to metadata rendering and cache guidance for marketplace/indexer
  invalidation.

The operator UI must distinguish a metadata preview from a final freeze. A
freeze flow should include two-person review, a dry-run, and a post-state read.

## Randomizer Operations

Randomizer operations require provider evidence, provider funding, callback
health, and randomizer epoch awareness.

Required UI checks:

- show the current collection randomizer contract from
  `viewCollectionRandomizerContract`;
- show current randomizer epoch from `viewRandomizerEpoch`;
- show provider funding and request-health status from retained randomizer
  operations evidence;
- show pending, stale, failed, and retry state where the current randomizer
  supports lifecycle reads;
- simulate or dry-run randomizer assignment where possible;
- retain provider address, provider epoch, callback policy, and post-state
  evidence; and
- link to the randomizer incident runbook for stale or failed requests.

The UI should not mark a provider production-ready because local randomizer
evidence passed. Provider funding and live callback health are external
evidence requirements.

## Emergency Withdrawals And Surplus

Emergency withdrawal actions are critical and must be surplus-bounded.

For each contract exposing `emergencyWithdrawable` and `emergencyWithdraw`, the
UI should show:

- current contract balance;
- total owed, total reserved, or equivalent owed-balance views;
- computed emergency-withdrawable surplus;
- requested withdrawal amount;
- configured `emergencyRecipient`;
- expected `EmergencyWithdrawal` event;
- post-state balance and owed-balance reads; and
- incident or release evidence link.

The UI must not allow operators to sweep owed bidder, poster, curator,
protocol, mint, or randomizer reserved funds. If a contract reports
`emergencyWithdrawable() == 0`, the action should be disabled unless a reviewed
incident runbook records a new contract-level recovery path.

## Monitoring Events And Indexer Reads

Operator actions should be monitored through events and read-after-event checks.

Core events:

- `GlobalAdminUpdated`;
- `FunctionAdminUpdated`;
- `PauseGuardianUpdated`;
- `UnpauseAdminUpdated`;
- `SignerManagerUpdated`;
- `SignerLifecycleTargetUpdated`;
- `PauseUpdated`;
- `EmergencyRecipientUpdated`;
- `DropSignerChanged`;
- `SignerEpochChanged`;
- `DropAuthorizationCancelled`;
- `CollectionRandomizerUpdated`;
- `CollectionFrozen`;
- `DependencyVersionCreated`;
- `DependencyVersionDeprecated`;
- `DependencyVersionPinned`; and
- `EmergencyWithdrawal`.

For every event, the UI should show the expected indexed fields, the block and
transaction source, and the read-after-event call that proves the final state.
Use the event topic catalog rather than hard-coded topics.

## UI Confirmation Model

High-risk operator actions require a consistent confirmation model.

Minimum confirmation sequence:

1. Artifact check: release manifest, address book, deployment manifest, ABI
   checksum, event topic catalog, interface IDs, risk register, and
   public-beta evidence are loaded for the selected environment.
2. Pre-state read: current owner, role, signer, pause, dependency, metadata,
   randomizer, owed-balance, or emergency state is displayed.
3. Risk classification: Critical, High, Medium, or Informational.
4. Simulation or dry-run: result is retained when available.
5. Human-readable diff: target, selector, account, domain, collection, signer,
   epoch, recipient, amount, and reason are shown without raw secret material.
6. Two-person review: reviewer records approval or rejection.
7. Safe transaction: Safe or multisig execution path is recorded when required.
8. Post-state read: final state is read from contracts.
9. Evidence attachment: transaction hash, block number, confirmation depth,
   command or UI transcript, reviewer, and SHA-256 digest are retained.

Rejected or failed actions should preserve the draft evidence and must not
erase prior state, reviewer comments, or incident links.

## Testing Strategy

The guide does not add Solidity behavior. Operator UI implementers should still
base their product tests on existing protocol tests and local evidence:

- `StreamAdmins.t.sol` for admin role behavior;
- `StreamAdminSelectors.t.sol` for selector-level permission regressions;
- `StreamCoreAdminCharacterization.t.sol` for current admin update behavior;
- `StreamSignerAdmin.t.sol` and `StreamSignerCompromiseFuzz.t.sol` for signer
  lifecycle and compromise coverage;
- `StreamPauseControls.t.sol` for pause behavior;
- `StreamEmergencyWithdraw.t.sol` for surplus boundaries;
- `StreamMetadataFreeze.t.sol` for freeze behavior;
- `StreamDependencyRegistry.t.sol` for dependency content and deprecation; and
- `StreamRandomizerLifecycle.t.sol` for randomizer lifecycle expectations.

Frontend product tests should include permission rendering, calldata decoding,
artifact mismatch handling, Safe transaction preview, pause-domain selection,
signer-rotation warnings, freeze confirmation, emergency-withdrawable
disabling, post-state polling, and no-secret telemetry.

## Validation Commands

Run these checks after changing this guide or its wiring:

```sh
python scripts/test_operator_admin_ui.py
python scripts/check_operator_admin_ui.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

These commands validate documentation structure and release artifact
traceability only. They do not prove public beta or production operator UI
readiness.

## Maintenance

Update this guide when:

- `StreamAdmins` roles, events, selectors, or pause domains change;
- signer lifecycle, DropAuthorization, or signer custody policy changes;
- deployment manifests, address books, or Safe ceremony docs change;
- randomizer provider lifecycle or provider funding evidence changes;
- metadata freeze or dependency registry behavior changes;
- emergency withdrawal accounting changes;
- the event topic catalog or ABI checksum baseline changes; or
- a retained fork/testnet/live admin ceremony updates public readiness.

When the guide changes, update the checker, integration README, release
readiness dashboard, release manifest coverage, changelog, and autonomous run
state in the same PR.
