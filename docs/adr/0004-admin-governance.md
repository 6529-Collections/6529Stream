# ADR 0004: Admin And Governance

## Status

Accepted.

Implementation status: P0-ADMIN-001 implements target-scoped function-admin
permission checks for the current protected-function surface, fixes the
`setCollectionData`, `updateCollectionInfo`, and `setMultipleMerkleRoots`
selector mismatches, adds owner/root role-management recovery, and adds
regression coverage for wrong-selector, wrong-target, global-admin, revoked
admin, unauthorized, zero-address, and deferred collection-admin paths.
Remaining ADR work includes pause domains, signer lifecycle operations,
deployment ceremony/runbooks, final production Safe configuration, and any
expanded collection-admin role model.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-10 |
| Issue | [P0-ADMIN-ADR](https://github.com/6529-Collections/6529Stream/issues/33) |
| Blocks | [P0-ADMIN-001](https://github.com/6529-Collections/6529Stream/issues/34), [P0-ADMIN-002](https://github.com/6529-Collections/6529Stream/issues/35) |
| Related issues | [P0-PAY-007](https://github.com/6529-Collections/6529Stream/issues/31), [P0-PAY-008](https://github.com/6529-Collections/6529Stream/issues/8) |
| Related ADRs | [ADR 0001](0001-drop-authorization.md), [ADR 0002](0002-auction-custody.md), [ADR 0003](0003-payment-accounting.md) |
| Affected contracts | `smart-contracts/StreamAdmins.sol`, `smart-contracts/StreamCore.sol`, `smart-contracts/StreamMinter.sol`, `smart-contracts/StreamDrops.sol`, `smart-contracts/AuctionContract.sol`, `smart-contracts/StreamCuratorsPool.sol`, `smart-contracts/DependencyRegistry.sol`, `smart-contracts/RandomizerRNG.sol`, `smart-contracts/RandomizerVRF.sol`, `smart-contracts/RandomizerNXT.sol` |
| Work type | `DESIGN` |

## Problem

6529Stream needs a coherent admin and emergency-control model before P0
authorization, auction, payment, metadata, and randomness rewrites rely on it.
The current contracts mix `Ownable.owner()`, `tdhSigner`, global admins, and
selector-level function admins without a public-beta authority model.

Before public beta, the protocol needs to decide:

- which actor is the root authority for production deployments
- which actors can grant and revoke roles
- how global, function, collection, signer, pause, and emergency powers differ
- whether selector permissions are scoped to a target contract
- how signer compromise and signed-drop cancellation are handled
- which protocol flows can be paused, by whom, and for how long
- how emergency withdrawals interact with owed and reserved balances
- which events, views, and runbooks make admin changes observable

## Current Behavior And Remaining Gaps

Current source references, including the historical pre-P0-ADMIN-001 baseline:

- `smart-contracts/StreamAdmins.sol`: `tdhSigner` can register global admins
  and function admins. P0-ADMIN-001 also lets `owner()` manage those roles as a
  root recovery path without making `owner()` an implicit operational admin on
  protected protocol contracts.
- `smart-contracts/IStreamAdmins.sol`: exposes
  `retrieveCollectionAdmin(address,uint256)`. P0-ADMIN-001 implements the
  deferred path as an explicit `false` result; collection-admin mutation powers
  remain future work.
- `smart-contracts/StreamCore.sol`,
  `smart-contracts/StreamMinter.sol`, `smart-contracts/StreamDrops.sol`,
  `smart-contracts/AuctionContract.sol`, `smart-contracts/StreamCuratorsPool.sol`,
  `smart-contracts/DependencyRegistry.sol`, and randomizer contracts use
  `FunctionAdminRequired(bytes4)` with target-scoped function-admin checks and
  explicit global-admin bypass.
- Before P0-ADMIN-001, `StreamCore.setCollectionData` was guarded by
  `this.changeMetadataView.selector`; it now uses
  `this.setCollectionData.selector`.
- Before P0-ADMIN-001, `StreamCore.updateCollectionInfo` was guarded by
  `this.changeMetadataView.selector`; it now uses
  `this.updateCollectionInfo.selector`.
- Before P0-ADMIN-001, `StreamCuratorsPool.setMultipleMerkleRoots` was guarded
  by `this.setMerkleRoot.selector`; it now uses
  `this.setMultipleMerkleRoots.selector`.
- Emergency withdrawals now have surplus/reserve boundaries for the current
  first-party emergency-withdrawal surface; pause-specific emergency controls
  remain separate P0-ADMIN-002 work.
- `smart-contracts/StreamDrops.sol#updateTDHsigner` can replace the drop signer,
  but there is no signer epoch, cancellation, role-specific signer manager, or
  compromise runbook.
- `smart-contracts/StreamAdmins.sol#tdhSigner` still has no dedicated rotation
  path, but `owner()` can now recover role management if the registrar key is
  lost or compromised.
- There is no pause model for drop execution, minting, bidding, settlement,
  metadata mutation, randomness requests, randomness fulfillment, or
  withdrawals.
- `test/StreamCoreAdminCharacterization.t.sol` has been converted from a
  migration tripwire into target-state coverage for the fixed
  `setCollectionData` selector.

## Decision

6529Stream will use a Safe-rooted, role-scoped, observable admin model for
public beta.

The public-beta target design is:

1. `StreamAdmins` or its replacement is the single access-control source for
   first-party contracts.
2. The production root authority must be a Safe or equivalent multisig. EOAs may
   be used only during local tests, deployment rehearsal, or documented
   bootstrap ceremonies.
3. The deployer must not retain lasting production authority after the admin
   ceremony completes.
4. `owner()` is not the general operational admin. Production code must not rely
   on `owner()` as an implicit signer manager, pause guardian, function admin, or
   emergency-withdrawal recipient unless that behavior is explicitly wired to
   the governance root and documented.
5. Selector-level grants must be scoped by target contract and selector. A grant
   for `(targetA, selectorX)` must not authorize `(targetB, selectorX)`.
6. Every protected function must check its intended selector or a named role.
7. Global-admin bypass must remain possible only as a break-glass role and must
   be held by a Safe/multisig in production.
8. Function-admin grants are for narrow operational permissions and must be
   revocable.
9. Collection-admin powers, if implemented, are scoped to a single collection
   and to explicitly collection-safe functions.
10. Signer-management powers are separate from generic metadata, payment,
    randomness, and contract-wiring powers.
11. Pause powers are domain-scoped. Pausing one domain must not silently pause
    unrelated domains.
12. Emergency withdrawals must follow ADR 0003: only surplus is withdrawable.
    Owed balances, active bid escrow, curator reserves, protocol credits,
    randomness reserves, and other reserved balances are never emergency
    withdrawable.
13. Admin, signer, pause, and emergency changes must emit stable events with
    indexed fields that monitoring systems can consume.
14. The access-control implementation must expose enough read-only views for
    deployment checks, monitoring, docs, and tests to prove the active authority
    graph.

## Role Model

The implementation may choose exact Solidity names, but it must preserve these
roles or stricter equivalents.

| Role | Authority | Production holder | Notes |
| --- | --- | --- | --- |
| `GovernanceRoot` | Owns the admin contract, grants critical roles, can recover from compromised operational roles | Safe/multisig | Final authority after deployment ceremony |
| `GlobalAdmin` | Break-glass access to protected operational functions | Safe/multisig only | Must be minimized and monitored |
| `RoleManager` | Grants and revokes non-root roles according to the ADR | Safe/multisig or narrowly scoped operations Safe | May be the same as `GovernanceRoot` for P0 |
| `FunctionAdmin` | Calls one protected function on one target contract | Safe/multisig or documented operations wallet | Keyed by target contract and selector |
| `CollectionAdmin` | Mutates approved fields for one collection before freeze | Artist/team Safe, if used | Cannot affect other collections |
| `SignerManager` | Adds/removes drop signers, increments signer epochs, cancels signed drops | Safe/multisig | Separate from drop signer addresses |
| `PauseGuardian` | Immediately pauses approved domains | Safe/multisig or monitored hot wallet | Cannot unpause unless also granted unpause authority |
| `UnpauseAdmin` | Unpauses domains after incident review | Safe/multisig | May be `GovernanceRoot` |
| `EmergencyAdmin` | Executes surplus-only emergency withdrawals and documented emergency actions | Safe/multisig | Cannot withdraw owed or reserved funds |
| `DeploymentOperator` | Performs deployment-time wiring before ownership/role transfer | Temporary deployer wallet | Must be removed during ceremony |

### Governance Root

The governance root should be the admin contract owner or an equivalent root
authority. It must be set to a Safe/multisig before any production drop.

The governance root can:

- grant and revoke global admin, role manager, signer manager, unpause admin,
  and emergency admin roles
- transfer root authority through a two-step or scheduled process
- execute critical contract-wiring changes if no narrower role is assigned
- unpause domains after an incident review
- rotate compromised operational roles

The governance root should not be used for routine mint, metadata, auction, or
randomness operations.

### Function Admins

Function-admin grants must be keyed by:

```solidity
account
targetContract
selector
```

The existing `(account, selector)` shape is not sufficient for public beta
because the same selector can exist on multiple contracts and because tests need
to prove the target being authorized.

At minimum, P0 implementation must fix and test:

- `StreamCore.setCollectionData` uses `setCollectionData.selector`
- `StreamCore.updateCollectionInfo` uses `updateCollectionInfo.selector` or an
  explicit named metadata role that is documented and tested
- `StreamCuratorsPool.setMultipleMerkleRoots` uses
  `setMultipleMerkleRoots.selector`
- every other `FunctionAdminRequired(this.*.selector)` call maps to the intended
  function
- grants for one target contract do not authorize the same selector on another
  target contract

### Collection Admins

Collection-admin support is useful for artist/team operations, but it must be
strictly scoped.

Allowed P0 collection-admin candidates:

- update collection display info before freeze
- switch metadata view before freeze
- update token data for tokens in the assigned collection before freeze
- update token images and attributes for tokens in the assigned collection
  before freeze

Collection admins must not be able to:

- create arbitrary collections
- change admin, minter, drops, auction, dependency, payout, curator, or
  randomizer contract addresses
- set or extend sale phases unless explicitly granted by a function role
- set final supply
- freeze collections unless explicitly accepted by implementation docs
- mutate any collection for which they are not authorized
- bypass frozen metadata rules

If P0 implementation defers collection-admin support, the admin contract must
remove or revert the stale `retrieveCollectionAdmin` interface path or document
it as unsupported so integrations do not assume it works.

### Signer Lifecycle

ADR 0001 requires signer-aware, replay-safe drop authorization. This ADR assigns
the authority model for that lifecycle.

Required signer controls:

1. Only `SignerManager` or a stricter authority can add, remove, or rotate drop
   signers.
2. Drop signers are authorization identities, not operational admins.
3. A signer address must not receive admin privileges merely because it can sign
   drops.
4. Every signer has a current epoch, or the implementation has an equivalent
   epoch model that invalidates stale signed payloads.
5. Rotating or disabling a signer must invalidate future payloads from the old
   signer or stale epoch.
6. A specific `dropId` can be cancelled before execution.
7. A global drop-execution pause exists for signer compromise response.
8. Events must be emitted for signer added, signer removed, signer epoch
   changed, drop cancelled, and drop-execution pause changes.

Required compromise response:

1. Pause drop execution.
2. Remove or rotate the compromised signer.
3. Increment the affected signer epoch or equivalent invalidation state.
4. Cancel known exposed `dropId` values if needed.
5. Announce the incident scope and affected signer epoch in the operations log.
6. Unpause only after replacement signer configuration is verified.

## Pause Model

Pause controls are domain-specific. The implementation may encode domains as an
enum, bitmask, mapping, or separate booleans, but it must expose readable pause
state for each supported domain.

Required P0 pause domains:

| Domain | Pauses | Default policy |
| --- | --- | --- |
| `DropExecution` | Signed drop execution and `mintDrop` replacement path | Supported, guardian can pause, Safe unpauses |
| `Mint` | New fixed-price or auction mints through the minter path | Supported, guardian can pause, Safe unpauses |
| `AuctionBid` | New bids | Supported, guardian can pause, Safe unpauses |
| `AuctionSettlement` | Settlement execution after auction end | Supported only for incident response; settlement remains permissionless when unpaused |
| `MetadataMutation` | Mutable metadata/admin metadata changes before freeze | Supported, guardian can pause, Safe unpauses |
| `RandomnessRequest` | New randomness requests | Supported, guardian can pause, Safe unpauses |
| `RandomnessFulfillment` | Provider callbacks or fulfillment writes | Not generally paused; validate request ID, token, collection, and randomizer epoch instead |
| `Withdrawal` | User credit withdrawals | Not generally paused; see withdrawal policy below |

### Withdrawal Pause Policy

User withdrawals should remain available during ordinary pauses. A compromised
mint or auction path should not prevent users from withdrawing already-earned
credits.

If a withdrawal pause is implemented, it must:

- be a separate domain
- be controlled only by `GovernanceRoot` or `EmergencyAdmin`
- be temporary and evented
- preserve all credits and category totals
- never convert owed balances into surplus
- be documented with incident reason, start time, expected expiry, and owner

If the implementation cannot enforce a bounded pause on-chain, the public-beta
default is no withdrawal pause.

### Randomness Fulfillment Policy

Randomness fulfillment should be hardened by validation rather than broad pause.
ADR 0005 owns the callback design, but this ADR requires admin controls to be
compatible with:

- randomizer provider rotation
- randomizer epoch changes
- rejecting stale callbacks from previous providers or epochs
- keeping already pending request accounting visible
- preserving randomness fee reserves under ADR 0003

## Emergency Model

Emergency powers are narrow and accounting-aware.

Required emergency rules:

1. No emergency function may sweep a full contract balance unless the contract
   has no owed or reserved balances by construction and this is documented.
2. For payment-moving contracts, emergency withdrawal amount must be bounded by
   `emergencyWithdrawable()` or an equivalent surplus view from ADR 0003.
3. Emergency recipients must be explicit governance or treasury addresses.
   Silent payment to `owner()` is not enough for public beta.
4. Emergency actions must emit events that include caller, recipient, amount,
   target contract, domain, reason code or bytes32 incident ID, and resulting
   surplus where applicable.
5. Emergency actions must not alter user credits, active highest-bid escrow,
   curator reserves, protocol credits, randomness reserves, NFT custody, or
   consumed drop IDs except through a separate documented incident-specific
   state transition.
6. Emergency actions must be covered by tests that include direct and forced ETH
   surplus cases.

## Contract-Wiring Controls

Contract address updates are high-risk governance actions. Public-beta
implementation must classify and test each update path.

Critical wiring includes:

- admin contract updates
- core, minter, drops, auction, curator pool, dependency registry, and
  randomizer contract updates
- payout or treasury address updates
- curator pool address updates
- randomizer provider, key hash, subscription, request configuration, and cost
  updates
- dependency registry script/library updates
- sale phase and auction parameter changes

For production, critical wiring changes should use a two-step
propose/accept flow, a schedule/execute delay, or an explicit Safe transaction
review process documented in the deployment runbook. Immediate changes are
allowed only for local development, deployment rehearsal, or documented
break-glass incidents.

## Minimum Function Classification

P0 implementation must publish an access-control matrix in docs and encode the
same expectations in tests. The exact role names may differ, but the authority
boundaries must be at least this strict.

| Contract area | Functions | Minimum authority |
| --- | --- | --- |
| Admin contract | grant/revoke global, function, collection, signer, pause, and emergency roles | `GovernanceRoot` or `RoleManager` according to role criticality |
| Admin contract | rotate the current admin registrar or root authority | `GovernanceRoot`, two-step or scheduled where practical |
| Core collection creation | `createCollection` | `GovernanceRoot` or narrowly scoped collection factory role |
| Core collection configuration | `setCollectionData`, `addRandomizer`, `setFinalSupply` | target-scoped `FunctionAdmin`; collection admin only if explicitly accepted |
| Core metadata mutation | `updateCollectionInfo`, `changeMetadataView`, `changeTokenData`, `updateImagesAndAttributes` | `CollectionAdmin` for that collection or target-scoped metadata `FunctionAdmin` |
| Core freeze | `freezeCollection` | target-scoped `FunctionAdmin` or explicitly accepted collection admin |
| Core wiring | `updateContracts` | `GovernanceRoot` or critical wiring role |
| Drops signer and payout wiring | `updateTDHsigner`, payout, curator, admin, and minter updates | `SignerManager`, treasury role, or critical wiring role according to field |
| Minter sale controls | `setCollectionPhases`, `updateAuctionEndTime` | sale/auction `FunctionAdmin` |
| Minter wiring | `updateContracts` | `GovernanceRoot` or critical wiring role |
| Auction parameters | `updatePercentAndExtensionTime` | auction `FunctionAdmin` |
| Auction wiring and emergency | minter, admin, drops, payout, curator, and emergency functions | critical wiring role or `EmergencyAdmin` according to function |
| Curator pool | `setMerkleRoot`, `setMultipleMerkleRoots` | curator rewards `FunctionAdmin` scoped by target |
| Curator pool wiring and emergency | admin update and emergency functions | critical wiring role or `EmergencyAdmin` according to function |
| Randomizers | provider/config/cost updates | randomness `FunctionAdmin` plus ADR 0005 requirements |
| Randomizers wiring and emergency | admin/core updates and RNG emergency functions | critical wiring role or `EmergencyAdmin` according to function |
| Dependency registry | dependency script/library updates | dependency `FunctionAdmin` with metadata/freeze docs |
| Dependency registry wiring | admin update | `GovernanceRoot` or critical wiring role |

## Events And Views

The admin system must be observable.

Required events or stricter equivalents:

- `RoleGranted(account, role, target, selector, collectionId, admin)`
- `RoleRevoked(account, role, target, selector, collectionId, admin)`
- `GlobalAdminUpdated(account, enabled, admin)`
- `FunctionAdminUpdated(account, target, selector, enabled, admin)`
- `CollectionAdminUpdated(account, collectionId, enabled, admin)`
- `SignerUpdated(signer, enabled, signerEpoch, admin)`
- `SignerEpochIncremented(signer, signerEpoch, admin)`
- `DropCancelled(dropId, signer, signerEpoch, admin)`
- `PauseUpdated(domain, paused, admin, reason)`
- `EmergencyAction(target, recipient, amount, incidentId, admin)`
- `CriticalAddressUpdateProposed(target, field, oldValue, newValue, eta, admin)`
- `CriticalAddressUpdateExecuted(target, field, oldValue, newValue, admin)`

Required views or stricter equivalents:

- root authority
- role membership
- function-admin membership by account, target, and selector
- collection-admin membership by account and collection
- signer enabled/epoch state
- drop cancellation state
- pause state per domain
- emergency recipient
- emergency-withdrawable amount on value-holding contracts

## Implementation Requirements

P0 implementation must:

- replace or wrap the current `StreamAdmins` model so authority is root-owned
  and role-scoped
- remove the assumption that `tdhSigner` is the only role manager
- add a root-managed rotation path for any admin registrar or equivalent role
- separate drop signer identities from admin identities
- key function-admin grants by target contract and selector
- fix the `setCollectionData`, `updateCollectionInfo`, and
  `setMultipleMerkleRoots` selector mismatches or replace intentional grouping
  with explicit named roles
- audit every protected function for intended selector or role
- decide whether unsupported collection-admin interface methods revert or are
  fully implemented
- add custom errors for security-relevant access failures
- emit events for all admin, signer, pause, and emergency state changes
- expose read-only views needed by tests and deployment checks
- document the deployment admin ceremony
- keep payment emergency controls consistent with ADR 0003

## Tests Required

P0 tests must include:

- current admin characterization tests before rewrites
- selector-accurate authorization for every protected function
- wrong selector does not authorize mutation
- grant on one target contract does not authorize the same selector on another
  target contract
- global admin bypass succeeds only for the configured break-glass role
- function-admin grant, revoke, and negative paths
- collection-admin positive and negative paths if implemented
- unsupported collection-admin interface behavior if deferred
- signer add, remove, rotate, epoch increment, and stale epoch rejection
- per-drop cancellation
- drop-execution pause during signer compromise
- domain-specific pause and unpause authorization
- paused mint, bid, settlement, metadata, and randomness-request behavior
- withdrawal pause or non-pause behavior according to this ADR
- emergency withdrawal cannot withdraw owed or reserved balances
- emergency withdrawal can withdraw only surplus/direct/forced ETH where
  allowed by ADR 0003
- event assertions for role, signer, pause, cancellation, address update, and
  emergency events
- deployment ceremony test or script assertion that deployer privileges are
  removed and production roles point at Safe/multisig addresses

## Migration And Rollout

1. Keep characterization tests for current selector and authority behavior.
2. Implement the new admin model behind focused P0 admin issues.
3. Update dependent contracts to use target-scoped selector checks or named-role
   checks.
4. Add deployment rehearsal scripts that grant initial roles, transfer root
   authority, remove deployer powers, and verify role views.
5. Update protocol docs and runbooks with the final authority matrix.
6. Execute local and CI tests before enabling any production drop.

## Alternatives Considered

### Keep `tdhSigner` As Sole Admin Registrar

Rejected. The drop signer is an authorization signer, not a governance root.
Keeping signer and admin registrar authority coupled increases signer-compromise
blast radius and conflicts with ADR 0001 signer rotation.

### Use Only `Ownable`

Rejected. Single-owner administration is too coarse for production drops and
does not support selector-level, collection-level, pause, signer, and emergency
separation.

### Use Existing `(account, selector)` Function Grants

Rejected for public beta. Grants must include the target contract to prevent
cross-contract selector ambiguity and to make tests and deployment manifests
explicit.

### Make Every Pause Global

Rejected. Global pause is operationally blunt and can unnecessarily block
withdrawals, settlement, or randomness fulfillment. Domain-scoped pause gives a
clearer incident response while preserving user safety.

## Non-Goals

- Choosing the final Safe owners, threshold, or signers.
- Implementing a full DAO governance process.
- Adding upgradeable proxy governance. ADR 0007 owns upgrade/redeployment
  decisions.
- Finalizing randomness provider callback semantics. ADR 0005 owns callback
  validation while this ADR owns pause and authority compatibility.
- Implementing contract, test, or deployment changes in this ADR PR.

## Accepted Risks

- P0 may use direct Safe execution instead of an on-chain timelock if the
  deployment runbook documents the review process and the repo is still
  pre-audit.
- Collection-admin support may be deferred if the stale interface path is made
  explicit and no integration is told to rely on it.
- Withdrawal pause is intentionally narrow. Some incidents may require pausing
  payment-adjacent writes instead of withdrawals to preserve user access to
  owed funds.

## Open Follow-Ups

- Implement [P0-ADMIN-001](https://github.com/6529-Collections/6529Stream/issues/34).
- Implement [P0-ADMIN-002](https://github.com/6529-Collections/6529Stream/issues/35).
- Update deployment docs with concrete Safe addresses and thresholds before any
  production drop.
- Reconcile final pause implementation with ADR 0005 once randomness design is
  accepted.
