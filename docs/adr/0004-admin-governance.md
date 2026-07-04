# ADR 0004: Admin And Governance

## Status

Accepted.

Implementation status: P0-ADMIN-001 implements target-scoped function-admin
permission checks for the current protected-function surface, fixes the
`setCollectionData`, `updateCollectionInfo`, and `setMultipleMerkleRoots`
selector mismatches, adds owner/root role-management recovery, and adds
regression coverage for wrong-selector, wrong-target, global-admin, revoked
admin, unauthorized, zero-address, and deferred collection-admin paths.
P0-ADMIN-002 implements domain-scoped pause state for `DropExecution`, `Mint`,
`AuctionBid`, `AuctionSettlement`, `MetadataMutation`, and
`RandomnessRequest`, keeps user credit withdrawals unpaused by default, adds
pause guardian/unpause admin roles, and replaces implicit owner-based emergency
withdrawal recipients with an explicit `emergencyRecipient()` on
`StreamAdmins`. P0-ADMIN-003 adds root-managed signer managers, owner-approved
signer-lifecycle targets, removes the drop signer's implicit role-management
authority, and covers signer lifecycle grants, rotation, epoch invalidation,
and per-drop cancellation. Remaining ADR work includes deployment
ceremony/runbooks, final production Safe configuration, and any expanded
collection-admin role model.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-10 |
| Issue | [P0-ADMIN-ADR](https://github.com/6529-Collections/6529Stream/issues/33) |
| Blocks | [P0-ADMIN-001](https://github.com/6529-Collections/6529Stream/issues/34), [P0-ADMIN-002](https://github.com/6529-Collections/6529Stream/issues/35), [P0-ADMIN-003](https://github.com/6529-Collections/6529Stream/issues/79) |
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

- `smart-contracts/StreamAdmins.sol`: `owner()` manages global admins,
  function admins, pause guardians, unpause admins, emergency recipients, and
  signer managers as the root recovery path without making `owner()` an
  implicit operational admin on protected protocol contracts.
- Drop-signing identities are no longer role registrars or global admins by
  default. Root-managed signer managers can grant only the exact
  `StreamDrops` signer-lifecycle selectors on owner-approved signer-lifecycle
  targets: `updateTDHsigner`, `incrementSignerEpoch`, and `cancelDrop`.
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
  first-party emergency-withdrawal surface and send withdrawable surplus to the
  explicit `StreamAdmins.emergencyRecipient()` instead of implicitly using
  `owner()`.
- `smart-contracts/StreamDrops.sol#updateTDHsigner` can replace the drop signer
  and increments `signerEpoch`, while `incrementSignerEpoch` and `cancelDrop`
  support signer compromise response. P0-ADMIN-003 covers these paths through
  explicit signer-manager grants on approved signer-lifecycle targets.
- `smart-contracts/StreamAdmins.sol#tdhSigner` remains a readable constructor
  signer reference for compatibility, but it is not a role-management authority.
- `StreamAdmins` exposes readable domain pause state for drop execution,
  minting, bidding, settlement, metadata mutation, and randomness requests.
  Randomness fulfillment remains unpaused by policy and must be hardened by ADR
  0005 validation work. User credit withdrawals remain unpaused by default.
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

## Future-Proof Governance Extensions

The accepted P0 admin model is the immediate launch baseline. The broader
Stream specs also rely on the following long-term governance requirements for
revenue, metadata, entropy, minting, finality, and successor declarations.

Governance principles:

1. Tightening can be fast; loosening must be delayed.
2. Terminal freezes are irreversible.
3. Every admin mutation emits an event.
4. Pointer changes use two-step staging and timelock.
5. Collection-scoped admins cannot weaken global invariants.
6. Emergency powers must preserve owed funds and historical truth.
7. Governance contracts are part of the protocol surface and must be monitored.
8. No admin system may rely on a single long-lived EOA.
9. Immutable contracts are replaced through new deployment lines and explicit
   pointer governance, not hidden implementation replacement.

Long-term action classes:

```text
IMMEDIATE_TIGHTENING
DELAYED_LOOSENING
TERMINAL_FREEZE
POINTER_REPLACEMENT
FUNDS_RECOVERY
SUCCESSOR_DECLARATION
```

Launch may simplify this into a two-tier delay model:

```text
IMMEDIATE tightening actions only, 0 delay
DELAYED all other material actions, at least 48 hours
```

Three action families keep explicit longer launch floors even under the
two-tier model:

```text
FUNDS_RECOVERY          at least 14 days
SUCCESSOR_DECLARATION   at least 30 days
TERMINAL_FREEZE         guardian/veto window or at least 24 hours
```

Critical pointer changes must be staged with old address, new address, code
hash, interface evidence where practical, activation time, expiry, and reason
hash. Required pointer surfaces include:

```text
StreamCore.metadataRouter         one-way freezable
StreamCore.collectionMetadata     one-way freezable
StreamCore.entropyCoordinator     one-way freezable
StreamCore.mintManager            one-way freezable
StreamCore.revenueResolver        one-way freezable
MetadataRouter.defaultRenderer    collection-freeze aware
MetadataRouter.dependencyRegistry one-way freezable
RevenueResolver.splitFactory      versioned by factory line
RevenueResolver.labelRegistry     descriptive only
MintManager.ledger                phase-freeze aware
MintManager.moduleRegistry        codehash checked
```

Pointer operation IDs must be domain-separated by chain ID, governance
contract, nonce, pointer ID, module type, expected interface ID, old target,
new target, new code hash, target manifest hash, activation window, and reason
hash. `reasonURI` is display data; `reasonHash` is the durable commitment.
Pointer freeze events must include the pointer ID, frozen target, operation ID
when the freeze is tied to a staged action, frozen target code hash, and frozen
manifest hash so indexers can reconstruct the exact frozen state.

### Scheduled Action State

Governance must be inspectable from onchain reads, not only reconstructed from
logs.

```solidity
enum GovernanceActionStatus {
    NONE,
    SCHEDULED,
    CANCELLED,
    EXECUTED,
    EXPIRED,
    VETOED
}

struct GovernanceAction {
    GovernanceActionStatus status;
    uint8 actionClass;
    address target;
    uint256 value;
    bytes4 selector;
    bytes32 callHash;
    bytes32 scopeHash;
    bytes32 oldValueHash;
    bytes32 newValueHash;
    uint64 notBefore;
    uint64 expiresAfter;
    address proposer;
    address executor;
    address canceller;
    address vetoer;
    bytes32 reasonHash;
    string reasonURI;
    bytes32 manifestHash;
}

function governanceAction(bytes32 actionId)
    external
    view
    returns (GovernanceAction memory);

struct GovernanceActionRequest {
    uint8 actionClass;
    address target;
    uint256 value;
    bytes4 selector;
    bytes callData;
    bytes32 scopeHash;
    bytes32 oldValueHash;
    bytes32 newValueHash;
    uint64 notBefore;
    uint64 expiresAfter;
    bytes32 reasonHash;
    string reasonURI;
    bytes32 manifestHash;
}

function governanceNonce() external view returns (uint256);

function minimumDelay(uint8 actionClass) external view returns (uint64);

function scheduleGovernanceAction(GovernanceActionRequest calldata request)
    external
    returns (bytes32 actionId);

function cancelGovernanceAction(bytes32 actionId, bytes32 reasonHash) external;

function executeGovernanceAction(bytes32 actionId, bytes calldata callData)
    external
    payable;

function materializeExpiredAction(bytes32 actionId) external;
```

`EXPIRED` may be materialized by a state-changing cleanup call or returned
virtually by the read when `status == SCHEDULED && block.timestamp >
expiresAfter`. Expired actions cannot execute. They must be cancelled or
rescheduled with a new nonce and new action ID.

### Canonical Action ID And Batch Execution [GOV-ACTION-ID]

Amended by ADR 0010 (decisions D3.4 and D7.1). This section is the single
normative home of the governance action identity that every Stream spec
cites; no other document may restate the preimage.

A governance action is an atomic batch of one or more calls. Single-call
actions are batches of length one; cross-contract updates that must land
together (pointer plus catalog plus manifest cache) execute as one batch.

```solidity
struct GovernanceCall {
    address target;
    uint256 value;
    bytes4 selector;
    bytes32 callDataHash; // keccak256(callData)
}

bytes32 constant STREAM_GOVERNANCE_CALLS_V1 =
    0x51c60c7ea5577cbf0c5157f544a7de1a186ae82b6fc4df6a626b9c8d1d3a0b61;
    // keccak256("6529STREAM_GOVERNANCE_CALLS_V1")

bytes32 callsHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_CALLS_V1,
    calls
));

bytes32 constant STREAM_GOVERNANCE_ACTION_V1 =
    0xda01e91bb5de11674cef69c6774002280d75bcb43cd9c78413c4b94d5d14249b;
    // keccak256("6529STREAM_GOVERNANCE_ACTION_V1")

bytes32 actionId = keccak256(abi.encode(
    STREAM_GOVERNANCE_ACTION_V1,
    uint256(block.chainid),
    address(this),            // the governance contract
    uint8(actionClass),
    callsHash,
    bytes32(scopeHash),
    bytes32(oldValueHash),
    bytes32(newValueHash),
    uint256(nonce),
    uint64(notBefore),
    uint64(expiresAfter),
    bytes32(reasonHash),
    bytes32(manifestHash)
));
```

Explicit batch ABI (ADR 0011 decision R10):

```solidity
function scheduleGovernanceBatch(
    uint8 actionClass,
    GovernanceCall[] calldata calls,
    bytes32 scopeHash,
    bytes32 oldValueHash,
    bytes32 newValueHash,
    uint64 notBefore,
    uint64 expiresAfter,
    bytes32 reasonHash,
    string calldata reasonURI,
    bytes32 manifestHash
) external returns (bytes32 actionId);

function executeGovernanceBatch(
    bytes32 actionId,
    GovernanceCall[] calldata calls,
    bytes[] calldata callDatas
) external payable;
```

Batch rules [GOV-BATCH]:

1. Execution supplies the full ordered `GovernanceCall[]` plus each call's
   `callData`; every `callDataHash` must match, and the recomputed
   `callsHash` and `actionId` must match the stored action.
2. Batch execution is atomic: every call succeeds or the whole action
   reverts. Partial application is never observable.
3. The single-call `GovernanceAction` storage shape remains valid: it
   stores `callsHash` in `callHash` for batches, and the stored
   `target`/`selector` are those of the first call for indexing.
4. Subsystem specs that stage governed operations (pointer moves, catalog
   updates, GGP changes, registry lifecycle) fold their fields into
   `scopeHash`/`newValueHash` and this one preimage; defining a second
   staged-operation preimage is nonconformant (ADR 0010 decision D3.4).

### Material Actions And Holder Classes [GOV-MATERIAL]

Amended by ADR 0011 (decision R10). "Material actions" are: any staged
governance action class; Core satellite pointer moves; registry lifecycle
changes; GGP changes; freeze, finality, and recovery operations; asset
policy transitions; role grants and revocations; successor declarations;
and treasury or endowment movements. Material actions must be executable
by Safe multisigs and governor contracts. EOA-class holders may hold
material-action roles only during a time-boxed deployment bootstrap whose
sunset (transfer of every material role to Safe or governor holders) is a
deployment gate recorded in the ceremony evidence.

### ERC-1271 Wallet Class [GOV-1271-CLASS]

Amended by ADR 0011 (decision R10). The supported contract-wallet class,
cited by every layer that verifies signatures (mint tickets, sale
authorizations, payment intents, release authorizations, artist and
attestation flows, owner records): any wallet whose `isValidSignature`
completes within the verifying layer's Governed Gas Parameter, with each
verifier's genesis value and floor sized from the measured heaviest named
class — nested Safe n-of-m, pure-Solidity P-256/WebAuthn verifiers, and
governor contracts — and recorded in the release manifest. Verifying
layers cite this class; none defines its own.

### Governance Window Floors And Unpause [GOV-WINDOWS]

Amended by ADR 0010 (decisions D7.2). Windows are sized for multisig and
governor-contract latency, not for fast single signers:

1. Delayed action classes must keep an open-to-execute window
   (`expiresAfter - notBefore`) of at least 7 days.
2. Emergency classes must be executable by role-redundant holders and
   assume at least 4 hours of coordination latency; no emergency path may
   presume a single hot key. The terminal-freeze veto window floor is 72
   hours (ADR 0011 decision R10) so governor-contract holders can
   realistically exercise it.
3. Unpause is a dedicated operational class: a distinct `ROLE_UNPAUSE`
   (grantable to a Safe or governor contract) executes unpause with no
   timelock and an evented reason. Pause guardians cannot unpause; unpause
   holders cannot pause. The two-tier delay model does not apply to
   unpause.

Execution rules:

1. `scheduleGovernanceAction` allocates the next nonce, computes the canonical
   action ID, stores the action, and emits `GovernanceActionScheduled`.
2. `notBefore` must be at least `block.timestamp + minimumDelay(actionClass)`
   unless the action is `IMMEDIATE_TIGHTENING` and the implementation's
   tightening classifier proves it cannot loosen policy.
3. `expiresAfter` must be greater than `notBefore` and within a launch-pinned
   maximum action lifetime.
4. The stored `callHash` is `keccak256(callData)`. Execution must require the
   supplied `callData` hash to equal the stored hash, `msg.value` to equal
   `value`, `target` to have code unless the action explicitly targets native
   ETH transfer to an approved governance receiver, and `block.timestamp` to be
   within `[notBefore, expiresAfter]`.
   For non-empty calldata, `bytes4(callData[0:4])` must equal the stored
   `selector`.
5. Anyone may execute a scheduled action after `notBefore` unless the action
   class requires a named executor in the manifest. Permission to schedule and
   cancel remains role-gated.
6. Execution rechecks every subsystem-specific invariant named in the action
   manifest, including old value hash, new value hash, pointer code hash,
   registry eligibility, interface ID, freeze state, owed-funds boundary, and
   terminal-freeze veto status where applicable.
7. Execution uses the stored `target`, `value`, `selector`, and `callHash`; it
   must not execute arbitrary calldata supplied by the caller.
8. A successful execution stores `EXECUTED`, records `executor`, emits
   `GovernanceActionExecuted`, and cannot be replayed.
9. Cancellation is allowed only while `SCHEDULED` and before execution; it
   stores `CANCELLED`, records `canceller`, and emits
   `GovernanceActionCancelled`.
10. `materializeExpiredAction` may be called by anyone after `expiresAfter` to
    store `EXPIRED` and make the virtual expiry explicit.

Transition table:

```text
NONE       -> SCHEDULED   schedule valid action
SCHEDULED  -> EXECUTED    execute after notBefore and before expiresAfter
SCHEDULED  -> CANCELLED   authorized cancellation before execution
SCHEDULED  -> VETOED      terminal-freeze guardian veto before deadline
SCHEDULED  -> EXPIRED     virtual or materialized after expiresAfter
CANCELLED  -> terminal
EXECUTED   -> terminal
EXPIRED    -> terminal
VETOED     -> terminal
```

The release manifest must include a machine-readable governance action policy
catalog. Each protected selector is mapped to role, action class, minimum delay,
tightening/loosening classifier, old/new value predicate, emergency eligibility,
and whether permissionless execution after delay is allowed. Governance code
and CI use this catalog as the conformance target; prose examples are not
authority.

Terminal freeze actions require an explicit guardian/veto surface:

```solidity
function terminalFreezeVetoGuardian(bytes32 scopeHash)
    external
    view
    returns (address guardian, uint64 vetoDeadline);

function vetoTerminalFreeze(bytes32 actionId, bytes32 reasonHash) external;
```

The guardian can only veto while the action is scheduled and before the veto
deadline. It cannot edit the action, execute a different action, sweep funds,
or unfreeze an already executed terminal freeze.

### Role Vocabulary [GOV-ROLES]

Amended by ADR 0010 (decision D7.4). This subsection is the single home of
the protocol-wide `ROLE_*` constant vocabulary. Long-lived authorities in
every Stream spec are `bytes32` role references resolved through the admin
registry at call time, never raw frozen addresses. A subsystem spec may
reference only roles enumerated here; introducing a new role constant
amends this table.

Each `ROLE_*` constant is `keccak256` of its own name. Grant classes:
`root` roles are granted and revoked only by `GovernanceRoot`;
`operational` roles are grantable by `RoleManager`. Every holder is a
Safe/multisig or governance contract per the Role Model above.

| Role constant | Authority | Grant class | Normative home |
| --- | --- | --- | --- |
| `ROLE_UNPAUSE` | Executes unpause with no timelock and an evented reason; disjoint from pause guardians | root | this ADR, [GOV-WINDOWS].3 |
| `ROLE_COLLECTION_FINALITY_ADMIN` | Executes `finalizeCollectionArtwork` / scoped finality subject to component verification | root | [`docs/stream-long-term-architecture.md`](../stream-long-term-architecture.md) (Artwork Finality Freeze [LTA-FINALITY]) |
| `ROLE_TERMINAL_FREEZE_VETO` | Per-scope terminal-freeze veto guardian resolved through `terminalFreezeVetoGuardian`; independent of scheduling roles | root | this ADR ([GOV-WINDOWS] veto surface); [`docs/stream-long-term-architecture.md`](../stream-long-term-architecture.md) [LTA-FREEZE] rule 4 |
| `ROLE_ENTROPY_INCIDENT_DECLARER` | Declares entropy requests unrecoverable under the fresh-recovery policy | operational | [`docs/stream-entropy-coordinator.md`](../stream-entropy-coordinator.md) [EC-INCIDENT-ROLE] |
| `ROLE_ENTROPY_REVEAL_OWNER` | Holds the declared reveal-request obligation for `ASYNC` collections within the reveal SLO (ADR 0011 decision R8) | operational | [`docs/stream-entropy-coordinator.md`](../stream-entropy-coordinator.md) [EC-REVEAL] |
| `ROLE_ARTIST_REGISTRY_ADMIN` | Proposes artist bindings, declares platform works, withdraws unaccepted proposals | operational | [`docs/stream-artist-authority.md`](../stream-artist-authority.md) [AA-ROLES] |
| `ROLE_ATTRIBUTION_ARBITER` | Governed arbiter for attribution disputes and post-revocation rebinding approval | root | [`docs/stream-artist-authority.md`](../stream-artist-authority.md) [AA-DISPUTE] |
| `ROLE_ARTIST_DORMANCY_ADMIN` | Initiates and completes the governed artist-dormancy procedure | root | [`docs/stream-artist-authority.md`](../stream-artist-authority.md) [AA-DORMANCY] |

The legacy CamelCase names in the Role Model table (for example
`UnpauseAdmin`, `PauseGuardian`) are the P0 authority descriptions; where a
production surface binds an authority into storage, an event, or a policy
hash, it binds the `ROLE_*` constant, and the registry maps the constant to
its current holder. Pause-guardian authority remains a Role Model grant and
gains no `ROLE_*` storage binding in v1 because no spec stores it.

### Future Governance Events

Every admin mutation must emit an event. At minimum:

```solidity
event GovernanceActionScheduled(
    uint16 schemaVersion,
    bytes32 indexed actionId,
    uint8 indexed actionClass,
    address indexed target,
    uint256 value,
    bytes4 selector,
    bytes32 callHash,
    bytes32 scopeHash,
    bytes32 oldValueHash,
    bytes32 newValueHash,
    uint64 notBefore,
    uint64 expiresAfter,
    uint256 nonce,
    address proposer,
    bytes32 reasonHash,
    string reasonURI,
    bytes32 manifestHash
);

event GovernanceActionExecuted(
    uint16 schemaVersion,
    bytes32 indexed actionId,
    uint8 indexed actionClass,
    address indexed target,
    uint256 value,
    bytes4 selector,
    bytes32 callHash,
    bytes32 scopeHash,
    bytes32 oldValueHash,
    bytes32 newValueHash,
    address executor,
    bytes32 manifestHash
);

event GovernanceActionCancelled(
    uint16 schemaVersion,
    bytes32 indexed actionId,
    uint8 indexed actionClass,
    address indexed target,
    bytes4 selector,
    bytes32 callHash,
    bytes32 scopeHash,
    address canceller,
    bytes32 reasonHash,
    string reasonURI
);

event GovernanceActionVetoed(
    uint16 schemaVersion,
    bytes32 indexed actionId,
    uint8 indexed actionClass,
    address indexed vetoer,
    bytes32 scopeHash,
    bytes32 reasonHash
);

event ProtocolPointerScheduled(
    uint16 schemaVersion,
    bytes32 indexed pointerId,
    bytes32 indexed actionId,
    address indexed newAddress,
    address oldAddress,
    bytes32 newCodeHash,
    uint64 executeAfter,
    bytes32 reasonHash
);

event ProtocolPointerUpdated(
    uint16 schemaVersion,
    bytes32 indexed pointerId,
    bytes32 indexed actionId,
    address indexed newAddress,
    address oldAddress,
    bytes32 newCodeHash
);

event ProtocolPointerFrozen(
    uint16 schemaVersion,
    bytes32 indexed pointerId,
    bytes32 indexed actionId
);

event AdminPermissionUpdated(
    uint16 schemaVersion,
    bytes32 indexed permissionId,
    address indexed account,
    uint256 indexed collectionId,
    bytes4 selector,
    bool enabled,
    address actor
);
```

Implementation may split events by subsystem, but indexers must be able to
reconstruct every admin permission, pointer, delay, and freeze change from
events.
`permissionId` is the durable role, action, or permission constant. `selector`
is contextual ABI evidence only and must not be the durable permission key.

Implementation manifests must map every protected operation to an explicit
durable role constant or action ID. A cardinality test must fail if unrelated
protected functions share an authorization key. Selector aliases such as
`this.X.selector` must not become durable permission identifiers for unrelated
functions.

Every admin event either includes a `schemaVersion` field from v1 or has its
single accepted meaning pinned in the machine-readable event catalog. If a
future deployment line changes event shapes, indexers must union old and new
streams rather than reinterpret old events.

Key-management and succession posture:

1. Launch governance is controlled by a Safe or equivalent contract wallet, not
   by a single EOA.
2. Genesis artifacts publish role assignments, pointer settings, delay
   configuration, event catalog hash, and transaction hashes.
3. No single EOA can execute material actions at genesis.
4. Signer rotation, signer loss, emergency pause, and terminal freeze runbooks
   are public where possible without exposing private signer details.
5. Quorum-degradation simulations prove the system degrades to "frozen but
   honest": transfers, ownership reads, `royaltyInfo`, `tokenURI` or its
   documented fallback, split-wallet `release`, and permissionless
   `flushEscrow` continue without admin intervention.
6. A successor Core, if ever needed, is declared through
   `SUCCESSOR_DECLARATION`; it does not mutate old token ownership history.
7. Successor manifests include old chain ID, old Core, new chain ID, new Core,
   snapshot URI/hash, ownership snapshot hash, collection snapshot hashes,
   event-history snapshot hash, old-Core status, and activation statement.

Long-lived funds policy:

1. Owed funds are never emergency surplus.
2. Rounding dust is not ordinary surplus.
3. Unsupported ERC-20 assets may be quarantined per asset without blocking
   native ETH or other approved assets.
4. Any future decommissioning or recovery path must be delayed,
   event-complete, optically obvious, and unable to seize balances that remain
   economically claimable.

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

- P0-ADMIN-001, P0-ADMIN-002, and
  [P0-ADMIN-003](https://github.com/6529-Collections/6529Stream/issues/79)
  implementation coverage has landed for the current role, pause, emergency,
  and signer-lifecycle surfaces.
- Update deployment docs with concrete Safe addresses and thresholds before any
  production drop.
- Keep pause implementation docs aligned with ADR 0005 callback policy as
  metadata and deployment work lands.
