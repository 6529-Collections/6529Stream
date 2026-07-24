# ADR 0004: Admin And Governance

## Status

Accepted.

[ADR 0017](0017-raise-only-parameter-governance.md) supersedes this ADR's
`[GOV-EMERGENCY-RESTORATION]` launch design and the class-`6` portions of
`[GOV-WINDOWS]`. The active launch action classes are exactly IDs `0..5`.
ID `6` is reserved `retired_pre_genesis`, forbidden at scheduling and
execution, and never reusable. The superseded section remains below only as
historical design evidence and is not a target interface or release input.

Implementation status (labeled non-normative implementation evidence:
this paragraph records the as-built P0-ADMIN baseline, and the normative
sections below win wherever the baseline diverges — ADR 0012 decision
T9): P0-ADMIN-001 implements target-scoped function-admin
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
2. The production root authority must be a Safe, an equivalent multisig, or
   a governor contract satisfying [GOV-1271-CLASS] and [GOV-MATERIAL]
   (ADR 0013 decision U5). EOAs may
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
roles or stricter equivalents. Production-holder classes follow
[GOV-MATERIAL] (ADR 0013 decision U5): a Safe multisig and a governor
contract satisfying [GOV-1271-CLASS] are equally valid holders for every
row below, EOA-class holders appear only under the [GOV-MATERIAL]
time-boxed bootstrap with its recorded sunset, and latency-sensitive
roles size their holders against [GOV-WINDOWS] and the guardian-module
rules of [LTA-GUARDIAN].

| Role | Authority | Production holder | Notes |
| --- | --- | --- | --- |
| `GovernanceRoot` | Owns the admin contract, grants critical roles, can recover from compromised operational roles | Safe multisig or governor contract | Final authority after deployment ceremony |
| `GlobalAdmin` | Break-glass access to protected operational functions | Safe multisig or governor contract | Must be minimized and monitored |
| `RoleManager` | Grants and revokes non-root roles according to the ADR | Safe multisig or governor contract; may be a narrowly scoped operations Safe | May be the same as `GovernanceRoot` for P0 |
| `FunctionAdmin` | Calls one protected function on one target contract | Safe multisig, governor contract, or documented operations wallet | Keyed by target contract and selector |
| `CollectionAdmin` | Mutates approved fields for one collection before freeze | Artist/team Safe, if used | Cannot affect other collections |
| `SignerManager` | Adds/removes drop signers, increments signer epochs, cancels signed drops | Safe multisig or governor contract | Separate from drop signer addresses |
| `PauseGuardian` | Immediately pauses approved domains | Safe multisig, governor contract, or a registered governance-guardian module per [LTA-GUARDIAN]; a monitored hot wallet only as a documented bootstrap exception with a recorded sunset | Cannot unpause unless also granted unpause authority |
| `UnpauseAdmin` | Unpauses domains after incident review | Safe multisig or governor contract | May be `GovernanceRoot` |
| `EmergencyAdmin` | Executes surplus-only emergency withdrawals and documented emergency actions | Safe multisig or governor contract | Cannot withdraw owed or reserved funds |
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

### Control-Plane Scheduling Boundary

After seal, a registered proposer may schedule ordinary governed target calls;
registration does not delegate `GovernanceRoot` authority over governance's own
control plane. The Executor scans every call descriptor at scheduling and again
at execution. The stored proposer must equal the live governance root for every
Executor self-call and every call to the permanently owned RoleRegistry. The
only self-call exception is the exact pre-seal bootstrap seal proposed by
`genesisBootstrapAuthority`; that exception disappears permanently at seal.
Changing the root after scheduling therefore invalidates every still-pending
control-plane action proposed by the former root.

The root-only Executor selectors are `rotateGovernanceRoot`,
`registerProposer`, `registerCanceller`, `setTighteningCall`,
`registerFreezeSelector`, `setApprovedNativeReceiver`,
`registerEmergencyRestorationEligibility`, and
`registerSystemManifestTailTrigger`. Every Executor-mediated RoleRegistry call
is also root-only. Ordinary role mutations and manager enablement use
`DELAYED_LOOSENING` (`1`). The sole immediate exception is
`registerRoleManager(account, false)`: the Executor canonically decodes that
exact target/selector/value/calldata at scheduling and execution and requires
`IMMEDIATE_TIGHTENING` (`0`). Manager enablement through the same selector
remains class `1`; no other RoleRegistry selector enters the immediate,
terminal-freeze, emergency-restoration, or manifest-tail classifier lanes. A
registered `RoleManager` may still call the RoleRegistry directly for
operational-class grants and revocations; it cannot mutate root or scoped
terminal-veto roles or any manager-config chain.

Every RoleRegistry mutation originating from its permanently owning Executor
also enforces the exact Governance V2 per-call context target-side. The action
ID is nonzero, the class is the transition-specific class above, and the scope
is:

```solidity
keccak256(abi.encode(
    STREAM_ROLE_MUTATION_SCOPE_V1,
    block.chainid,
    address(roleRegistry),
    roleKey,
    holder
))
```

The old and new commitments are respectively:

```solidity
keccak256(abi.encode(
    STREAM_ROLE_MUTATION_STATE_V1,
    block.chainid,
    address(roleRegistry),
    scopeHash,
    granted,
    roleMutationChain,
    roleMutationRevision,
    globalRoleMutationChain,
    globalRoleMutationRevision
))
```

The new commitment uses the post-write membership, both incremented `uint64`
revisions, and both next chain hashes. Direct operational-manager grants and
revocations use the same append-only audit chains, so an intervening manager
write invalidates a stale scheduled ordinary role transition.

The per-role next chain is:

```solidity
keccak256(abi.encode(
    STREAM_ROLE_MUTATION_V1,
    priorRoleMutationChain,
    block.chainid,
    address(roleRegistry),
    roleKey,
    holder,
    newGranted,
    nextRoleMutationRevision
))
```

The global next chain is:

```solidity
keccak256(abi.encode(
    STREAM_GLOBAL_ROLE_MUTATION_V1,
    priorGlobalRoleMutationChain,
    block.chainid,
    address(roleRegistry),
    roleKey,
    holder,
    newGranted,
    nextGlobalRoleMutationRevision
))
```

Manager configuration has a separate liveness-safe commitment. The closed
internal role key remains `keccak256("6529STREAM_ROLE_MANAGER_CONFIG_V1")`, but
each manager address has its own chain and revision, exposed by
`roleManagerConfigMutationState(account)`. The exact state is:

`registerRoleManager(address,bool)` and that account-scoped getter are both
part of the canonical `IStreamRoleRegistry` ERC-165 surface. The complete
pre-genesis interface ID is `0xd77ee305`; omitting the writer from an otherwise
successful interface probe is nonconformant.

```solidity
keccak256(abi.encode(
    STREAM_ROLE_MANAGER_CONFIG_STATE_V1,
    block.chainid,
    address(roleRegistry),
    scopeHash,
    enabled,
    accountConfigChain,
    accountConfigRevision
))
```

Its next chain is:

```solidity
keccak256(abi.encode(
    STREAM_ROLE_MANAGER_CONFIG_MUTATION_V1,
    priorAccountConfigChain,
    block.chainid,
    address(roleRegistry),
    account,
    newEnabled,
    nextAccountConfigRevision
))
```

The target updates that address-scoped chain and then appends the same mutation
to the shared pseudo-role/global audit chains. Those audit chains remain a
complete execution-ordered history but are deliberately excluded from the
pre-scheduled manager-config state: otherwise a compromised manager could
front-run every removal with a cheap operational grant/revoke and censor its
own revocation forever. Independent address-scoped chains also let the root
disable multiple compromised managers in any order. Roles previously granted
by those managers persist; incident response disables every compromised
manager first, then executes the ordinary delayed role cleanup after the
manager-controlled mutation surface is gone. No-op manager writes reject.

The only non-executing owner exception is the initial
`ROLE_TERMINAL_FREEZE_VETO` population inside the one-way bootstrap bind, while
the Executor reports this exact registry but `bound == false` and
`sealed == false`. That exception is unreachable once bind returns.

The seven exact domains are:

| Domain | Preimage | Value |
| --- | --- | --- |
| `STREAM_ROLE_MUTATION_V1` | `6529STREAM_ROLE_MUTATION_V1` | `0xa8dba5d6fcfd6e5b3cd0487118fc42e1d598c9ba0fb59aefad69b419212bc91e` |
| `STREAM_GLOBAL_ROLE_MUTATION_V1` | `6529STREAM_GLOBAL_ROLE_MUTATION_V1` | `0x2da8f94be4b1e85c976aae097d48589ff562492679ebc2842c866ba5b986d39c` |
| `STREAM_ROLE_MUTATION_SCOPE_V1` | `6529STREAM_ROLE_MUTATION_SCOPE_V1` | `0x51943e9f337cf7f50fc89b1f37701a670f4477d8d6e3efbd34d986b27f35d271` |
| `STREAM_ROLE_MUTATION_STATE_V1` | `6529STREAM_ROLE_MUTATION_STATE_V1` | `0xf80e0ae6730f5e4e48b5a6c1b46bfb06af297aefb0eaa569f87f095a7f99153d` |
| `STREAM_ROLE_MANAGER_CONFIG_V1` | `6529STREAM_ROLE_MANAGER_CONFIG_V1` | `0x6b7160b8472382fb5a6b7cad94720fd10007c4124b0b0d405aa6523763ad0fe7` |
| `STREAM_ROLE_MANAGER_CONFIG_STATE_V1` | `6529STREAM_ROLE_MANAGER_CONFIG_STATE_V1` | `0x00ef486fa9550ecdc9851c2df1073c1c991e7d56e6a0d388357ba5f5a89c4263` |
| `STREAM_ROLE_MANAGER_CONFIG_MUTATION_V1` | `6529STREAM_ROLE_MANAGER_CONFIG_MUTATION_V1` | `0xbd1ca24b4e56b656dee2d7ca30433716550c54ab67aab3e6b9eba46ac0ff79d6` |

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

The production action-class IDs are append-only. Existing IDs `0` through `5`
never change meaning. ADR 0017 retires ID `6` before genesis; the row remains
reserved so it can never acquire a different meaning:

| Numeric ID | Action class | Minimum scheduling delay | Launch status |
| --- | --- | --- | --- |
| `0` | `IMMEDIATE_TIGHTENING` | `0` | active |
| `1` | `DELAYED_LOOSENING` | at least 48 hours | active |
| `2` | `TERMINAL_FREEZE` | at least 48 hours plus the independent veto floor below | active |
| `3` | `POINTER_REPLACEMENT` | at least 48 hours | active |
| `4` | `FUNDS_RECOVERY` | the 14-day floor below | active |
| `5` | `SUCCESSOR_DECLARATION` | the 30-day floor below | active |
| `6` | `EMERGENCY_RESTORATION` | not applicable | `retired_pre_genesis`; forbidden; never reuse |

The implementation keeps the two ordinary delay tiers — zero delay for
proved tightening and at least 48 hours for every other ordinary material
action — plus the named exception floors. `EMERGENCY_RESTORATION` is not an
executable tier: the class validator, scheduler, executor, policy catalog, and
every target reject numeric ID `6`.

Three action families keep explicit longer launch floors even under the
two-tier model:

```text
FUNDS_RECOVERY          at least 14 days
SUCCESSOR_DECLARATION   at least 30 days
TERMINAL_FREEZE         guardian/veto window of at least 72 hours
                        ([GOV-WINDOWS] floor; ADR 0013 decision U5)
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
expiresAfter`. Expired actions cannot execute. They must be materialized or
rescheduled with a new nonce and new action ID. Cancellation is intentionally
closed after `expiresAfter`: an expired action remains virtually `EXPIRED`
until permissionless materialization and cannot be rewritten to `CANCELLED`.

### Normative Homes (Current)

Everything from here through [GOV-ROLES] is owner-designated current
normative content (ADR 0014 decision V9): the Permanent governance homes
the specification set cites. Sections above this banner are the P0-era
decision record and baseline description; where they carry as-built
implementation status they are non-normative evidence per
[`docs/spec-policy.md`](../spec-policy.md), and where they conflict with
the homes below, the homes win.

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
    bytes32 scopeHash;    // target-specific transition scope
    bytes32 oldValueHash; // target-specific pre-state commitment
    bytes32 newValueHash; // target-specific post-state commitment
}

bytes32 constant STREAM_GOVERNANCE_CALLS_V2 =
    0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70;
    // keccak256("6529STREAM_GOVERNANCE_CALLS_V2")

bytes32 callsHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_CALLS_V2,
    calls
));

bytes32 constant STREAM_GOVERNANCE_BATCH_SCOPE_V2 =
    0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c;
    // keccak256("6529STREAM_GOVERNANCE_BATCH_SCOPE_V2")

bytes32 constant STREAM_GOVERNANCE_BATCH_OLD_STATE_V2 =
    0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7;
    // keccak256("6529STREAM_GOVERNANCE_BATCH_OLD_STATE_V2")

bytes32 constant STREAM_GOVERNANCE_BATCH_NEW_STATE_V2 =
    0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b;
    // keccak256("6529STREAM_GOVERNANCE_BATCH_NEW_STATE_V2")

bytes32[] memory callScopeHashes = new bytes32[](calls.length);
bytes32[] memory callOldValueHashes = new bytes32[](calls.length);
bytes32[] memory callNewValueHashes = new bytes32[](calls.length);
for (uint256 i; i < calls.length; ++i) {
    callScopeHashes[i] = calls[i].scopeHash;
    callOldValueHashes[i] = calls[i].oldValueHash;
    callNewValueHashes[i] = calls[i].newValueHash;
}

bytes32 scopeHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_BATCH_SCOPE_V2,
    callsHash,
    callScopeHashes
));
bytes32 oldValueHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_BATCH_OLD_STATE_V2,
    callsHash,
    callOldValueHashes
));
bytes32 newValueHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_BATCH_NEW_STATE_V2,
    callsHash,
    callNewValueHashes
));

bytes32 constant STREAM_GOVERNANCE_ACTION_V2 =
    0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b;
    // keccak256("6529STREAM_GOVERNANCE_ACTION_V2")

bytes32 actionId = keccak256(abi.encode(
    STREAM_GOVERNANCE_ACTION_V2,
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

The pre-genesis V2 domains replace the transitional V1 action/calls domains.
V2 is required because each `GovernanceCall` now commits its target-specific
scope and state transition; retaining the V1 domain after changing that typed
preimage would make signed/scheduled evidence schema-ambiguous. V1 actions are
not accepted by the target executor and cannot be replayed into V2.
The three action-level transition hashes are not caller-authored summaries:
the executor derives them from the ordered call descriptors with the exact
formulas above and rejects any scheduling arguments that differ. Including
`callsHash` in each aggregate binds target, value, selector, calldata, and all
three per-call commitments. A one-call wrapper constructs the same one-element
arrays and therefore stores the same aggregate fields and produces the same
`actionId` as the equivalent batch.

V2 cutover gate [GOV-V2-CUTOVER]. This migration is the first implementation
slice and a hard precondition to every new Core writer. Before a pointer,
collection-freeze, burn-block, manifest-publication, facade-governance, or
Core-hosted GGP writer can merge, one atomic governance cutover must:

1. replace the executor and `IStreamGovernanceExecutor` call descriptor with
   the seven-word `GovernanceCall`, the six-return `currentAction()`, and the V2
   action/calls domains and selectors below; retain active classes `0..5`,
   reserve ID `6` as `retired_pre_genesis`, and make every class validator,
   scheduler, executor, policy catalog, and target reject ID `6`;
2. update the governance call-data publisher, action-ID builder, Safe/governor
   transaction builder, monitoring decoder, and release checker to derive V2
   descriptors and per-call contexts from the same published bytes; migrate
   every existing GGP/GTP host to independent class-`1` action/context
   enforcement for its raise-only writer;
3. add golden tests for every selector, domain, and numeric action-class ID,
   including rejection of retired ID `6` and every unknown ID above it,
   per-call context rotation and clearing, one-call-wrapper equivalence,
   SSTORE2 publication and decoding, batch atomicity/value conservation, V1
   rejection, and target-side forged-context rejection;
4. rehearse each active material class from every supported holder class and
   the delayed class-`1` parameter raise path; regenerate the governance
   ABI/interface artifact, selector and event catalogs, numeric-ID/domain
   catalogs (including the reserved retired row for ID `6`),
   deployment inputs, release manifest, and checksum bundle; and
5. retire the V1 structs, V1 action/calls domains, V1 executor entrypoints, and
   every pending V1 action. There is no compatibility wrapper that schedules or
   executes V1, and a development action that was scheduled under V1 must be
   cancelled or abandoned and rescheduled under V2.

The cutover gate tests the executor against target-interface harnesses before
any target writer exists on Core. A PR that adds a Core writer while any item
above is incomplete is out of order even if its target-side checks are correct.

With the seven-word V2 `GovernanceCall` tuple, the production batch selectors
are `0x9c954144` for
`scheduleGovernanceBatch(uint8,(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)[],bytes32,bytes32,bytes32,uint64,uint64,bytes32,string,bytes32)`
and `0x2eccc33e` for
`executeGovernanceBatch(bytes32,(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)[],bytes[])`.

Explicit batch ABI (ADR 0011 decision R10):

```solidity
function publishGovernanceCallData(bytes[] calldata callDatas)
    external
    returns (address pointer);

function publishedCallData(bytes32 callDataKey)
    external
    view
    returns (address pointer);

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

function currentAction()
    external
    view
    returns (
        bool executing,
        bytes32 actionId,
        uint8 actionClass,
        bytes32 scopeHash,
        bytes32 oldValueHash,
        bytes32 newValueHash
    );

function scheduledCallDataPointer(bytes32 actionId)
    external
    view
    returns (address pointer);

function scheduledCallData(bytes32 actionId)
    external
    view
    returns (bytes[] memory callDatas);
```

The batch entrypoints are the canonical scheduling and execution ABI
(ADR 0013 decision U5): a single-call action is the batch of one, and
`scheduleGovernanceAction`/`executeGovernanceAction` are thin wrappers that
must produce byte-identical action IDs to the equivalent one-call batch.
Tooling and specs cite the batch ABI.
`currentAction()` has selector `0x546ea281`. During each batch call it exposes
the fixed-width action ID/class plus that `GovernanceCall` entry's three
target-specific hashes. The executor sets the per-call context immediately
before the call and clears it immediately afterward; outside execution all six
returns are zero. The first three returns preserve the shipped development
interface and the three hashes are trailing compatibility outputs, so an older
decoder may ignore them. A target must not trust the executor's selector
classifier alone when the target can irreversibly freeze or redirect state; it
checks this in-flight per-call context against the subsystem-owned hash
formulas. The action-level `scopeHash`/`oldValueHash`/`newValueHash` retained in
`GovernanceAction` describe the batch's composite transition for scheduling and
review; they are not substituted for a target's call-level commitments. The
dynamic reason URI and other display evidence remain available through
`governanceAction(actionId)` and are intentionally absent from this bytecode-
constrained target path.

The call-data publication ABI is also production-exact. Selectors are
`0x5447021f` for `publishGovernanceCallData(bytes[])`, `0x95a2b189` for
`publishedCallData(bytes32)`, `0x38f8ce24` for
`scheduledCallDataPointer(bytes32)`, and `0x72a3c7b8` for
`scheduledCallData(bytes32)`. Publication is permissionless and
content-addressed:

```solidity
bytes32[] memory callDataHashes = new bytes32[](callDatas.length);
for (uint256 i; i < callDatas.length; ++i) {
    callDataHashes[i] = keccak256(callDatas[i]);
}
bytes32 callDataKey = keccak256(abi.encodePacked(callDataHashes));
bytes memory payload = abi.encode(callDatas);
```

The SSTORE2 runtime code is exactly `0x00 || payload`: byte zero is `STOP`, and
the read is `extcodecopy(pointer, ..., 1, extcodesize(pointer) - 1)`. The
publisher rejects an empty outer array, an invalid or non-canonical decoded
payload, runtime code whose first byte is not `0x00`, and
`payload.length > 24_575`, so the runtime never exceeds the EIP-170
24,576-byte limit. An empty `bytes` element remains valid for the canonical
approved-native-receiver case; it is not an empty publication. It stores one immutable
pointer at `publishedCallData[callDataKey]`; republishing byte-identical content
is idempotent and returns the existing pointer. A new publication emits
schema-v1 `GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed
callDataKey, address pointer, address publisher)`, topic
`0x5922e6285b4b955740f916aa25accf8dcd9f75131e4bde259347d27adfaf1cce`.

`scheduleGovernanceBatch` does not accept a second copy of `callDatas`. It
derives `callDataKey` from the ordered descriptors, requires the pointer to
exist, reads and ABI-decodes the blob, requires equal array lengths, and for
each position rechecks the decoded byte hash and leading selector against the
corresponding `GovernanceCall` before storing that pointer for the action. An
element is valid in exactly one of two shapes: empty bytes require
`selector == bytes4(0)`, `value > 0`, and an exact approved native receiver;
otherwise its length is at least four and its leading four bytes equal
`selector`. Class `6` rejects the empty/native shape regardless of receiver.
`scheduleGovernanceAction` carries its sole call-data preimage, publishes
`abi.encode(oneElementBytesArray)` internally, and then schedules the same
one-call descriptor, producing the byte-identical V2 action ID. Execution
repeats pointer format, decode, hash, selector, and descriptor checks before
the first target call; the supplied execution bytes must equal the scheduled
content, not merely collide at an action-level composite.

#### Executor Control-Plane Commitments

Executor self-configuration is never classified by a mutable selector-wide
registry. Scheduling and execution both decode the exact canonical ABI for the
five self-configuration selectors, require zero call value, and require an
isolated one-call batch proposed by the live governance root. Non-canonical
address, `bool`, or `bytes4` words reject. The two selector-pair registries
also reject `target == address(executor)`, because neither mutable registry may
classify the Executor's own hard-coded control plane.

The address-keyed configuration scope and state are:

```solidity
bytes32 scopeHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_CONFIG_SCOPE_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    configKind,
    key
));

bytes32 stateHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_CONFIG_STATE_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    configKind,
    key,
    enabled,
    uint64(revision)
));
```

The selector-keyed variants append `bytes4 selector` to the scope and append
`bytes4 selector, bool enabled, bytes32 targetCodeHash, uint64 revision` after
`target` in the state. Enabling a selector-keyed rule records the target's
current nonzero runtime code hash; disabling requires that recorded hash still
match and stores zero. Every successful mutation increments its exact-key
`uint64` revision, rejects overflow and no-op writes, and requires the per-call
old/new commitments to use the pre/post values exactly.

| Selector | `configKind` preimage | `true` class | `false` class |
| --- | --- | --- | --- |
| `registerProposer(address,bool)` | `6529STREAM_GOVERNANCE_CONFIG_PROPOSER` | `DELAYED_LOOSENING` (`1`) | `IMMEDIATE_TIGHTENING` (`0`) |
| `registerCanceller(address,bool)` | `6529STREAM_GOVERNANCE_CONFIG_CANCELLER` | `IMMEDIATE_TIGHTENING` (`0`) | `DELAYED_LOOSENING` (`1`) |
| `setApprovedNativeReceiver(address,bool)` | `6529STREAM_GOVERNANCE_CONFIG_NATIVE_RECEIVER` | `DELAYED_LOOSENING` (`1`) | `IMMEDIATE_TIGHTENING` (`0`) |
| `setTighteningCall(address,bytes4,bool)` | `6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL` | `DELAYED_LOOSENING` (`1`) | `IMMEDIATE_TIGHTENING` (`0`) |
| `registerFreezeSelector(address,bytes4,bool)` | `6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR` | `IMMEDIATE_TIGHTENING` (`0`) | `DELAYED_LOOSENING` (`1`) |

Governance-root rotation is an isolated `POINTER_REPLACEMENT` (`3`) self-call.
Scheduling and execution both require zero call value, exactly 68 calldata
bytes for `rotateGovernanceRoot(address,bytes32)`, a canonical nonzero address
word, and a nonzero expected code hash. Trailing calldata, a noncanonical
address word, any other class, or a multi-call batch rejects before an action
is recorded. Its exact scope and state are:

```solidity
bytes32 scopeHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_ROOT_SCOPE_V1,
    uint256(block.chainid),
    address(governanceExecutor)
));

bytes32 stateHash = keccak256(abi.encode(
    STREAM_GOVERNANCE_ROOT_STATE_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    governanceRoot,
    governanceRootCodeHash,
    uint64(revision)
));
```

The root runtime code hash is rechecked on every sealed schedule and execution.
A root rotation increments the revision, rejects a no-op or invalid holder,
and every Executor/RoleRegistry control-plane action snapshots the nonzero root
revision at schedule time. Execution requires both the live root address and
that exact revision, so an address rotation `A -> B -> A` cannot revive an
action queued under the first `A` epoch. The expected revision reconstructs
from the action-schedule and root-rotation event streams.

Every action scheduled by a registered non-root proposer likewise snapshots
that proposer's nonzero configuration revision. Disabling the proposer or a
disable/re-enable address ABA permanently invalidates the queued action at
execution; governance-root and bootstrap actions use their separate authority
rules. A registered canceller may cancel ordinary queued actions, but cannot
cancel an isolated `registerCanceller(account,false)` removal unless it is also
the live root or that action's proposer. Thus a compromised canceller cannot
entrench itself across the delayed-removal window.

The exact domain and durable configuration-key values are:

| Constant | String preimage | Value |
| --- | --- | --- |
| `STREAM_GOVERNANCE_CONFIG_SCOPE_V1` | `6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1` | `0x3c84722ce639aca105835269de227cc0ffea495f13383068c46ec2e7aae88016` |
| `STREAM_GOVERNANCE_CONFIG_STATE_V1` | `6529STREAM_GOVERNANCE_CONFIG_STATE_V1` | `0x05000ed56f03029aee74f99fd9d1a7319ad482fa3148ae863053ea955d1e9a4b` |
| `STREAM_GOVERNANCE_ROOT_SCOPE_V1` | `6529STREAM_GOVERNANCE_ROOT_SCOPE_V1` | `0x6aadc831e79f225350483abeae2839b877650539b2bbb4a19c70ade78ea2e42c` |
| `STREAM_GOVERNANCE_ROOT_STATE_V1` | `6529STREAM_GOVERNANCE_ROOT_STATE_V1` | `0xd9975385cd3dcefe66cfc6e447a2c92f84d20f043e1198e1b6f5c65be5805d90` |
| `GOVERNANCE_CONFIG_PROPOSER` | `6529STREAM_GOVERNANCE_CONFIG_PROPOSER` | `0x3159801de288c136cc45c5fbc40879c4e5a4c7bba9806400495d2120cd681905` |
| `GOVERNANCE_CONFIG_CANCELLER` | `6529STREAM_GOVERNANCE_CONFIG_CANCELLER` | `0x334c6d45b3bad249a3f870b97f4a79b845676c102c028972e94f21b49628217b` |
| `GOVERNANCE_CONFIG_NATIVE_RECEIVER` | `6529STREAM_GOVERNANCE_CONFIG_NATIVE_RECEIVER` | `0x19222bb517f28c7f9a05615c9b0fac13b5258c5b61fcaec4605f5b56aa239cf4` |
| `GOVERNANCE_CONFIG_TIGHTENING_CALL` | `6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL` | `0xc3f9be103fb546fd998001a0d6447e98378926dd86bc995bb06019fd4eac50cf` |
| `GOVERNANCE_CONFIG_FREEZE_SELECTOR` | `6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR` | `0x034b6f0b02fadd47ce4775cbf1d72a3b570a62a973efcec85059bf135bf5da91` |

These configuration keys are durable permission identifiers, not replaceable
display labels. The machine governance action-policy catalog required by
[GOV-WINDOWS] must carry these exact rows and must also cover every downstream
protected selector before any downstream ownership is transferred to the
Executor. Until that closed-world catalog, target enforcement, deployment
checker, and release evidence exist, Governance V2 foundation code does not
satisfy [GOV-V2-CUTOVER] and no production ownership cutover is permitted.

The security-critical Governance V2 error ABI added by this foundation is
exact:

| Error signature | Selector |
| --- | --- |
| `GovernanceRootProposerRequired(address,address,address,bytes4)` | `0x572c5e0b` |
| `RoleRegistryDelayedActionRequired(uint8)` | `0x5e6cae4c` |
| `InvalidExecutorConfigCall(address,bytes4)` | `0x988f5a6d` |
| `ExecutorConfigActionClassMismatch(address,bytes4,bool,uint8,uint8)` | `0x53eb2651` |
| `ExecutorControlActionClassMismatch(address,bytes4,uint8,uint8)` | `0x25f6871f` |
| `GovernanceSelfCallContextRequired()` | `0xd13ef67d` |
| `GovernanceRootRevisionMismatch(bytes32,uint64,uint64)` | `0xfdd2ef9e` |
| `GovernanceProposerAuthorizationDrift(bytes32,address,uint64,uint64,bool)` | `0x18cd5aee` |
| `TighteningCallSelfTargetForbidden(bytes4)` | `0x67bbddf4` |
| `FreezeSelectorSelfTargetForbidden(bytes4)` | `0x500fc8d8` |
| `GovernanceCallReturndataTooLarge(bytes32,uint256,uint256,uint256)` | `0x29111b54` |
| `GovernanceActionExpiredWindow(bytes32,uint64)` | `0xc797754c` |
| `TerminalFreezeGuardianConfigDrift(bytes32,bytes32,bytes32)` | `0x3ef646fd` |
| `TerminalFreezeLiveActionCapExceeded(bytes32,uint256)` | `0xed1b395d` |
| `TerminalFreezeNonRootLiveActionCapExceeded(bytes32,uint256)` | `0x441113a4` |
| `TerminalFreezeProposerLiveActionCapExceeded(bytes32,address,uint256)` | `0xea2c035f` |
| `TerminalFreezePageCursorOutOfBounds(bytes32,uint256,uint256)` | `0x204cb92b` |
| `TerminalFreezePageLimitExceeded(uint256,uint256)` | `0x83beaacb` |

Batch rules [GOV-BATCH]:

1. Execution supplies the full ordered `GovernanceCall[]` plus each call's
   `callData`; every `callDataHash` must match, and the recomputed
   `callsHash` and `actionId` must match the stored action. Immediately before
   each low-level call the executor exposes that entry's `scopeHash`,
   `oldValueHash`, and `newValueHash` through `currentAction()`; it clears the
   per-call context after the call. The single-call wrapper places its request's
   three transition hashes in the sole call descriptor, then derives the three
   action-level aggregates with the one-element-array formulas in
   [GOV-ACTION-ID], so it remains byte-identical to the equivalent one-call
   batch.
2. Batch execution is atomic: every call succeeds or the whole action
   reverts. Partial application is never observable. Payable semantics are
   pinned (ADR 0013 decision U5): each `GovernanceCall.value` is the exact
   wei forwarded to that call, execution requires
   `msg.value == sum(calls[].value)`, and any refunded surplus reverts the
   batch rather than stranding in the governance contract.
   The executor requests no output bytes from a successful governed call and
   ignores its returndata. On failure it bubbles at most 4,096 bytes; a larger
   revert payload fails with
   `GovernanceCallReturndataTooLarge(bytes32,uint256,uint256,uint256)` rather
   than allocating attacker-selected memory. Ordinary bounded revert data is
   preserved exactly.
3. The single-call `GovernanceAction` storage shape remains valid: it
   stores `callsHash` in `callHash` for batches, and the stored
   `target`/`selector` are those of the first call for indexing.
4. Subsystem specs that stage governed operations (pointer moves, catalog
   updates, GGP changes, registry lifecycle) fold their fields into
   `scopeHash`/`newValueHash` and this one preimage; defining a second
   staged-operation preimage is nonconformant (ADR 0010 decision D3.4).
5. Scheduled calldata is published onchain for the full open-to-execute
   window (ADR 0013 decision U5) through the exact publication ABI and
   `callDataKey` formula above. Batch publication precedes scheduling; the
   single-call wrapper publishes internally. Scheduling stores the resolved
   SSTORE2 pointer in the action record, and the pointer and decoded bytes are
   exposed by the two scheduled-call-data reads, so executors and verifiers
   never depend on an offchain preimage to exercise or audit an action.

### System-Manifest Batch Tail [GOV-MANIFEST-TAIL]

"Batch-composition policy" is not an offchain convention. The executor has one
minimal, append-only rule set that forces every registered pointer or catalog
mutation to end in the Permanent `StreamSystemManifest` publication call.

The executor constructor pins only
`SYSTEM_MANIFEST_PUBLISH_SELECTOR = 0x09b1b5c6` and bootstrap-independent
governance configuration. It accepts no Core, satellite, registry, trigger,
code-hash, payload-address, manifest-hash, or inventory-root input derived from
an executor-bound downstream deployment. The tail target and its observed
runtime code hash begin zero and are recorded by the single irreversible
bootstrap bind specified below, after the executor-bound contracts exist.
There is no clear, replace, or second-bind path. Exact trigger ABI and storage
are:

```solidity
struct ManifestTailTriggerRule {
    bytes32 triggerCodeHash; // zero means unregistered
    uint8 allowedActionClassMask; // bits 0..3 only; zero means invalid
}

// Exact target plus selector prevents selector aliasing.
mapping(address => mapping(bytes4 => ManifestTailTriggerRule))
    private _manifestTailTriggerRules;

struct ManifestTailTriggerEntry {
    address triggerTarget;
    bytes4 triggerSelector;
}
ManifestTailTriggerEntry[] private _manifestTailTriggerEntries;
bytes32 private _manifestTailTriggerChainHash;

function systemManifestBatchTailRule(
    address triggerTarget,
    bytes4 triggerSelector
)
    external
    view
    returns (
        bool registered,
        bytes32 triggerCodeHash,
        uint8 allowedActionClassMask,
        address tailTarget,
        bytes4 tailSelector,
        bytes32 tailCodeHash
    );

function registerSystemManifestTailTrigger(
    address triggerTarget,
    bytes4 triggerSelector,
    uint8 allowedActionClassMask
) external;

function systemManifestTailTriggerCount() external view returns (uint256);

function systemManifestTailTriggerAt(uint256 index)
    external
    view
    returns (
        address triggerTarget,
        bytes4 triggerSelector,
        bytes32 triggerCodeHash,
        uint8 allowedActionClassMask
    );

function systemManifestTailTriggerChainHash()
    external
    view
    returns (bytes32 chainHash, uint64 recordCount);

event SystemManifestTailTriggerRegistered(
    uint16 schemaVersion,
    address indexed triggerTarget,
    bytes4 indexed triggerSelector,
    bytes32 triggerCodeHash,
    uint8 allowedActionClassMask,
    address tailTarget,
    bytes4 tailSelector,
    bytes32 indexed actionId
);
```

Selectors are `0xffd6babe` for
`systemManifestBatchTailRule(address,bytes4)` and `0xc64f0807` for
`registerSystemManifestTailTrigger(address,bytes4,uint8)`, plus `0xeee99df8`,
`0xd83d70b6`, and `0xa05cac72` for the count, indexed-at, and chain-hash reads.
The schema-v1 event topic
is `0x522584aa9f3d195f3d5f3001a5a3a2365f9f61c3982d9ae9aa1c6d0518b31f7f`
for
`SystemManifestTailTriggerRegistered(uint16,address,bytes4,bytes32,uint8,address,bytes4,bytes32)`;
`triggerTarget`, `triggerSelector`, and `actionId` are indexed.

Registration is itself an exact target-side transition:

```solidity
bytes32 constant STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_SCOPE_V1 =
    0x2c9b0dbea692b77bd1679258ca569c13c24eb261671f5a6b78b9fa59cd29c7f1;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_SCOPE_V1")

bytes32 constant STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_STATE_V1 =
    0xd41313fe7ee9b51221beebf9c314d67aebec3677907eb1365fff4caa4248f493;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_STATE_V1")

bytes32 constant STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_RECORD_V1 =
    0xe52b2b6e65acb1eae2c217c4b26e893c7d0e7f32afc148867b79c133b3a134fa;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_RECORD_V1")

bytes32 constant STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_CHAIN_V1 =
    0xdf8c3b0d7ebdd491123b988924db55f8fd11251d7e88e5d76722331928dd4951;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_CHAIN_V1")

bytes32 scopeHash = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_SCOPE_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    triggerTarget,
    triggerSelector
));

bytes32 triggerStateHash = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_STATE_V1,
    scopeHash,
    registered,
    triggerCodeHash,
    uint8(allowedActionClassMask),
    uint64(triggerCount),
    triggerChainHash,
    systemManifestSatellite,
    bytes4(0x09b1b5c6),
    systemManifestSatelliteCodeHash
));

bytes32 triggerRecordHash = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_RECORD_V1,
    uint64(triggerIndex),
    triggerTarget,
    triggerSelector,
    triggerCodeHash,
    uint8(allowedActionClassMask)
));
bytes32 nextTriggerChainHash = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_TAIL_TRIGGER_CHAIN_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    triggerChainHash,
    triggerRecordHash,
    uint64(triggerIndex)
));
```

The ordinary registration function accepts only an executor self-call while a
nonzero `TERMINAL_FREEZE` action (numeric ID `2`) is executing and additionally
requires the bootstrap seal already set. Genesis uses atomic materialization in
the direct one-way bind below, never ordinary registration. Post-seal registration requires exact
per-call scope/old/new hashes above, an unregistered nonzero target and
selector, `allowedActionClassMask != 0`, no set bit outside numeric classes
`0..3` (`allowedActionClassMask & 0xf0 == 0`),
`triggerTarget.code.length > 0`, the stored observed code hash to equal
`triggerTarget.codehash`, a live satellite code hash equal to the immutable
one-way-bound tail code hash, and a trigger pair different from the tail pair. The old state
uses `registered = false`, zero trigger code hash, and mask `0`; the new state
uses `registered = true`, the observed hash, and the proposed mask. A mask bit
is `uint8(1 << actionClass)`: `0x01`, `0x02`, `0x04`, and `0x08` permit classes
`0`, `1`, `2`, and `3`, respectively. Field-name changes do not alter the
getter/registration selectors or the event topic because their ABI types are
unchanged.
Registration emits the event only
after mapping storage, the append-only entry, count, and chain hash are written.
`triggerIndex` is the pre-state count; the new state commits count plus one and
`nextTriggerChainHash`, with uint64 overflow rejected. The three enumeration
reads must agree (`recordCount == systemManifestTailTriggerCount()`), and `At`
resolves its fields from the append-only key plus mapping. The mapping has no delete, clear, replace, wildcard,
or target-only registration path.

Except for the bounded, one-way genesis branch specified below, scheduling and
execution both run the same deterministic scan after validating the decoded
call-data selectors:

1. A batch containing the exact executor self-call
   `registerSystemManifestTailTrigger` must contain that one call only. This
   prevents a new rule from becoming visible partway through the same batch.
2. For every call whose exact `(target, selector)` is registered, the executor
   rechecks the target's current runtime code hash against the stored trigger
   code hash. The action class must be in `0..3`, and every matched rule must
   contain that class's bit. Different masks may coexist in one batch only when
   their intersection contains the current class bit; one permissive trigger
   never overrides a second trigger that omits it. One or more registered
   triggers require exactly one call to the immutable
   `(systemManifestSatellite, 0x09b1b5c6)` tail pair.
3. A tail call, whether trigger-required or standalone, may occur exactly once,
   must have `value == 0`, and must be the final array element. The executor
   rechecks the satellite runtime code hash against the one-way-bound observed hash. A
   standalone tail with no registered trigger is permitted only under
   `POINTER_REPLACEMENT` (`3`), the catalog/payload publication class.
4. A missing, duplicated, non-final, value-bearing, or code-hash-mismatched tail
   rejects scheduling and execution. Rules registered after an older action was
   scheduled are enforced at execution too; the now-incomplete action becomes
   safely unexecutable and must be cancelled or allowed to expire, then
   rescheduled with the required tail.

Before any protected writer is enabled, the genesis bind—or, after seal, a
separate completed registration action—must cover Core's
`updateSatellitePointer(bytes32,address)` (`0xac1e5708`) as
mask `0x08`, `freezeSatellitePointer(bytes32)` (`0xcdcdb71e`) as mask `0x04`,
and every exact deployed catalog-publisher `(target, selector)`
that can change one of the seven cached discovery hashes as mask `0x08`.
Raise-only GGP/GTP mutations are not manifest-tail triggers (ADR 0017).
Current module-registry inventory is equally protected: each exact deployed
`registerModule((address,bytes32,bytes32,bytes4,uint32,bytes32,bytes32,bytes32,string))`
pair (`0x77bfa48d`) is registered with mask `0x02`; each exact polymorphic
`setModuleStatus(address,uint8,bytes32,string)` pair (`0x96a6e18b`) uses mask
`0x03`; and each exact
`setModuleRegistryManifest(bytes32,string)` pair (`0x7ba46615`) uses mask
`0x02`. The executor's calldata-aware classifier and the registry target both
independently require class `0` for status tightening and class `1` for
registration, status loosening, or registry-manifest publication; the mask is
not permission to misclassify a transition. Their target-owned scope/state
formulas and hash/URI bounds are pinned at [LTA-REGISTRY-GOVERNANCE]. If a
future registry separates loosening and revocation selectors, their exact
rules use the corresponding one-bit masks instead. A future
registry/catalog/pointer trigger address is deployed and
code-hash checked, registered in its own terminal-freeze action, and only then
made usable. This exact-address model covers future modules without a selector
wildcard or an unsafe mutable policy administrator.

Tail/class goldens cover at least: class-2 pointer freeze followed by one final
publication; class-3 pointer update followed by one final publication; every
genesis catalog trigger followed by one final publication; module registration and status
loosening under class `1` followed by one final publication; incident status
revocation under class `0` followed by one final publication; registry-
manifest publication under class `1` followed by one final publication; and
standalone class-3 payload publication. Negative goldens reject a zero or high-bit mask,
class-2/update, class-3/freeze, registration/revocation under the wrong class,
mixed triggers when any mask omits the current class bit, missing/duplicate/
non-final tails, and standalone class-0/1/2 publication; a mixed-mask batch
whose every rule contains the current class bit succeeds. Enumeration goldens
walk `0..count-1`, recompute the record chain, compare every mapping rule, and
reject out-of-range access or any count/chain/state-hash drift.

Genesis bootstrap is an exact one-way exception, not an ungoverned gap. The
executor constructor pins only a single `genesisBootstrapAuthority` plus pure
schema/domain/governance configuration; no constructor input may be derived
from Core, the satellite, a registry/host, an expected trigger, downstream
runtime code, or a payload/inventory commitment. The executor deploys first.
`genesisBootstrapAuthority == address(0)` rejects deployment; the zero-
authority negative is a constructor golden.
Core, registries, hosts, and `StreamSystemManifest` then deploy with that known
executor address. One direct, authority-only, irreversible bind atomically
records the downstream facts and stable first-publication commitments. A pre-
seal action is always *bootstrap-scoped*; there is no ordinary pre-seal action
lane. Scheduling is allowed only when `bound && !sealed`,
`pendingScheduledActionCount() == 0`, the stored proposer is exactly
`genesisBootstrapAuthority`, and the batch is one of two forms: one or more
calls all drawn from the already-bound trigger table with a compatible single
class and no tail; or the exact seal/publication batch below. The same
form and proposer checks run again at execution. Native transfers, role/admin
changes, any class-`6` action, and every unrelated target/selector are
forbidden until after seal; they cannot be queued to survive the bootstrap
authority's sunset. Checking only the caller that submits or executes the
transaction is insufficient. The bind materializes its entire supplied trigger
table from index zero through the final record atomically, so no later proposer
can add an extra, skipped, substituted, or out-of-order pre-seal record. Any
executor-mediated registry, catalog, or Core-pointer mutation that contributes
to the first payload
but is absent from the bound expected table rejects while unsealed. Every
schedule increments the executor-wide pending scheduled count from zero to
one; execution, cancellation, veto, or explicit expiry materialization returns
it to zero. A virtually expired but unmaterialized action still counts. All
ordinary target-side classes, scope/state hashes, delays, vetoes, code-hash
checks, and transition rules still apply. The executor exposes:

```solidity
struct SystemManifestBootstrapTriggerExpectation {
    address triggerTarget;
    bytes4 triggerSelector;
    bytes32 triggerCodeHash;
    uint8 allowedActionClassMask;
}

struct SystemManifestBootstrapBinding {
    address roleRegistry;
    address governanceRoot;
    bytes32 governanceRootCodeHash;
    address[] initialTerminalFreezeVetoGuardians;
    address core;
    address systemManifestSatellite;
    bytes32 expectedManifestHash;
    bytes32 expectedInventoryStateRoot;
    uint64 expectedInventoryLeafCount;
    SystemManifestBootstrapTriggerExpectation[] expectedTriggers;
    bytes32[] pointerTypes;
    address[] registries;
}

function bindSystemManifestBootstrap(
    SystemManifestBootstrapBinding calldata binding
) external;

function pendingScheduledActionCount() external view returns (uint256);

function systemManifestBootstrapState()
    external
    view
    returns (
        bool bound,
        bool isSealed,
        address roleRegistry,
        bytes32 roleRegistryCodeHash,
        address governanceRoot,
        bytes32 governanceRootCodeHash,
        uint64 governanceRootRevision,
        bytes32 initialGuardianSetHash,
        uint256 initialGuardianCount,
        bytes32 terminalFreezeVetoMutationChain,
        uint64 terminalFreezeVetoMutationRevision,
        address core,
        bytes32 coreCodeHash,
        address systemManifestSatellite,
        bytes32 systemManifestSatelliteCodeHash,
        bytes32 triggerSetHash,
        uint256 triggerCount,
        bytes32 expectedTriggerSetHash,
        uint256 expectedTriggerCount,
        bytes32 expectedManifestHash,
        bytes32 expectedInventoryStateRoot,
        uint256 expectedInventoryLeafCount,
        bytes32 inventoryStateRoot,
        uint256 inventoryLeafCount,
        address genesisBootstrapAuthority,
        address sealedPayloadPointer
    );

function sealSystemManifestBootstrap() external;

event SystemManifestBootstrapSealed(
    uint16 schemaVersion,
    bytes32 indexed triggerSetHash,
    uint256 triggerCount,
    address indexed payloadPointer,
    bytes32 manifestHash,
    bytes32 indexed actionId
);

event SystemManifestBootstrapBound(
    uint16 schemaVersion,
    address indexed core,
    address indexed systemManifestSatellite,
    bytes32 coreCodeHash,
    bytes32 systemManifestSatelliteCodeHash,
    bytes32 indexed expectedManifestHash,
    bytes32 expectedInventoryStateRoot,
    bytes32 expectedTriggerSetHash,
    uint256 triggerCount,
    address genesisBootstrapAuthority,
    address roleRegistry,
    bytes32 roleRegistryCodeHash,
    address governanceRoot,
    bytes32 governanceRootCodeHash,
    bytes32 initialGuardianSetHash,
    uint256 initialGuardianCount,
    bytes32 terminalFreezeVetoMutationChain,
    uint64 terminalFreezeVetoMutationRevision
);
```

The bind, pending-count, state, and seal selectors are `0x32212927`,
`0x20662991`, `0x8a2d979b`, and `0xbd1f39cd`, respectively.
The bind event topic is
`0x0af9f59ce766b6c1564dcbc54493155eaac34589421982b2521a49b0fd056a44`
for
`SystemManifestBootstrapBound(uint16,address,address,bytes32,bytes32,bytes32,bytes32,bytes32,uint256,address,address,bytes32,address,bytes32,bytes32,uint256,bytes32,uint64)`;
schema version is `1`, and Core, satellite, and expected manifest hash are
indexed. The seal event topic is
`0xf8424a276e804e284aa6e3c67ceb87c4c23caff3164e0666e558d34893b13cf9`
for
`SystemManifestBootstrapSealed(uint16,bytes32,uint256,address,bytes32,bytes32)`;
schema version is `1`, and trigger-set hash, root pointer, and action ID are
indexed. Bootstrap transition hashes are:

Before `bound == true`, every scheduling, execution, cancellation, registration,
and seal path reverts; read-only inspection and the
exact direct bind call are the only available surfaces. The bind requires
`msg.sender == genesisBootstrapAuthority`, `bound == sealed == false`, no
action nonce or record ever created, nonzero distinct code-bearing Core and
satellite addresses, and nonzero content/inventory commitments and counts. It
proves Core's immutable executor without adding a Core getter by making a
write-impossible `staticcall` to
`updateSatellitePointer(bytes32(0),address(0))`: Core must first accept this
executor as caller and then revert with exact
`NoExecutingGovernanceAction()` (`0xb8456c92`) before argument validation;
`UnauthorizedGovernanceExecutor(address)` (`0xdd2aa8bd`), success, empty data,
or any other revert rejects the bind. It requires the satellite's explicit
binding getters `core()` (`0xf2f4eb26`) and `governanceExecutor()`
(`0x8fc98386`) to equal the bound Core and this executor, and requires
`supportsInterface(0x37660ede)` to match [LTA-MANIFEST]. Those two getters are
part of the satellite's seven protocol-specific selectors but are excluded
from the five-function `IStreamSystemManifest` interface ID;
`supportsInterface(bytes4)` is the eighth external function. The bind records
the observed Core and satellite `extcodehash` values and never accepts caller-
supplied expected code hashes for either contract.

The trigger array is bounded by
`MAX_GENESIS_MANIFEST_TAIL_TRIGGERS = 128`. The independent launch-inventory
bounds are `MAX_STRICT_POINTERS = 32`, `MAX_STRICT_REGISTRIES = 8`,
`MAX_STRICT_REGISTRY_MODULES = 128`, and
`MAX_STRICT_INVENTORY_LEAVES = 80`; the total includes pointers, registry
headers, and registry modules. The pointer/registry arrays must be nonempty,
strictly ascending in their canonical orders, duplicate-free, and the pointer
list must contain the exact `SYSTEM_MANIFEST` pointer type. The expected leaf
count cannot exceed
`pointerCount + registryCount + 128 * registryCount`, so the irreversible bind
cannot commit to a state that its listed registries can never reach. Every
supplied trigger has a nonzero target/selector, an
observed live code hash equal to its supplied trigger code hash, and a valid
nonzero class mask within `0x0f`. In the same transaction the bind appends every
record to the normal trigger array/mapping, computes every record/chain step,
and stores actual and expected trigger hash/count as the same final values. It
does not emit `SystemManifestTailTriggerRegistered` per row because no governed
`actionId` exists; the single bind event commits the final hash/count and the
state enumeration exposes every row. All registry addresses are code-bearing
and expose the exact registry interface. All checks and storage writes are one
transaction; a failure leaves the executor unbound with zero trigger count.
Success emits the bind event, permanently disables the bind entrypoint, and
enables only the constrained pre-seal governance lane. From
then until seal the bootstrap identity has no direct writer privilege: it is
only the exact stored proposer required for bootstrap-scoped governed actions.
The executor rechecks the recorded Core/satellite code hashes on every
bootstrap-scoped schedule and execution and on seal.

The executor can enforce order, bounds, live code hashes, masks, and equality
to the irreversibly bound set; it cannot know the external 60-module release
profile from constructor state. Checksum-covered release tooling and deployment
conformance—not the bind—prove that the supplied trigger and pointer/registry
lists are complete against the normative profile/spec. The implementation gate
measures the full-profile bind, including all trigger SSTOREs and hashing, under
the deployment block-gas envelope and retains margin. The current
pre-integration fixture separately measures a cold-state shape corresponding to
the 72-leaf launch inventory (11 pointers, one registry header, and 60 modules)
at 17,650,763 gas, plus adversarial 80-leaf boundary shapes with maximum-size
canonical URIs. The module-heavy boundary is the worst measured fixture shape
at 20,868,946 gas, below the fixed 24,000,000-gas execute-only ceiling. These
measurements use bounded Registry and SystemManifest mocks and therefore are
not production-runtime gas evidence. The production gate must repeat the cold
rehearsal against Registry V2 and the real `StreamSystemManifest`, including an
actual population-to-80 and successful seal. A warm same-test call is not
seal-gas evidence. The execute-only ceiling preserves the remaining deployment
block envelope for transaction intrinsic gas, calldata, and ceremony overhead.
The 80-leaf total is a launch envelope chosen to retain block-gas margin, not a
claim about theoretical lifetime registry capacity. A prose estimate or target
JSON fixture is not measured bind/seal-gas evidence.

This ordering has no CREATE2 fixed point. Executor initcode contains no value
derived from an executor-bound deployment; downstream addresses and runtime
code are created only after the executor address exists; the one-way bind then
records them; canonical manifest bytes are built only after every inventoried
address is known; and payload chunks/root deploy last. The root address is
never a bind or constructor input.

```solidity
bytes32 constant STREAM_SYSTEM_MANIFEST_BOOTSTRAP_SCOPE_V1 =
    0xace275f08856e822491961304b01cdc9423d7d16c05518327353df5cd02e33f8;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_SCOPE_V1")
bytes32 constant STREAM_SYSTEM_MANIFEST_BOOTSTRAP_STATE_V1 =
    0x96decef116f307400b4d1826658d33976ec923ce136ead67b736b8becbe781ef;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_STATE_V1")
bytes32 constant STREAM_SYSTEM_MANIFEST_BOOTSTRAP_TRIGGER_V1 =
    0x9927dc0a368efe3d99880bb180d83938664a29ad399291c4544e4cab70c84548;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_TRIGGER_V1")
bytes32 constant STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_LEAF_V1 =
    0x389d432187327bb28628b23403c9b3c549d0cf950e480ad6d69b7d9fa7b48b9d;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_LEAF_V1")
bytes32 constant STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_CHAIN_V1 =
    0x9efe6891a30e5198982f60b2d916e3275b866addbee37b7d4b875e52d5251e89;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_CHAIN_V1")
bytes32 constant STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_ROOT_V1 =
    0xb524bfb9f69adc6c2d0e07003dd39a76b1d6a728dd95dbd495f709428d21b4ec;
    // keccak256("6529STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_ROOT_V1")

bytes32 bootstrapScopeHash = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_BOOTSTRAP_SCOPE_V1,
    uint256(block.chainid),
    address(governanceExecutor)
));
bytes32 bootstrapStateHash = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_BOOTSTRAP_STATE_V1,
    bootstrapScopeHash,
    bound,
    sealed,
    roleRegistry,
    roleRegistryCodeHash,
    governanceRoot,
    governanceRootCodeHash,
    uint64(governanceRootRevision),
    initialGuardianSetHash,
    initialGuardianCount,
    terminalFreezeVetoMutationChain,
    uint64(terminalFreezeVetoMutationRevision),
    core,
    coreCodeHash,
    systemManifestSatellite,
    systemManifestSatelliteCodeHash,
    triggerSetHash,
    triggerCount,
    expectedTriggerSetHash,
    expectedTriggerCount,
    expectedManifestHash,
    expectedInventoryStateRoot,
    expectedInventoryLeafCount,
    inventoryStateRoot,
    inventoryLeafCount,
    genesisBootstrapAuthority,
    sealedPayloadPointer
));
```

The one-way bind stores the complete nonempty ascending list of actual Core
pointer types and the complete nonempty ascending list of registry instances
represented by the first payload, plus `expectedInventoryStateRoot` and
`expectedInventoryLeafCount`. Duplicate or unsorted list entries reject the
bind. The executor recomputes and strictly validates the live inventory at the
irreversible seal execution boundary; the same canonical read is available for
offchain preflight before scheduling. The order is every Core pointer in raw
`pointerType` order; then, for each registry in address order, one registry
header followed by every `moduleAt(0..moduleCount-1)` record. Leaf kinds are
`0 = CORE_POINTER`, `1 = REGISTRY_HEADER`, and `2 = REGISTRY_MODULE`; a pointer
leaf uses `leafHost = core` and `leafKey = pointerType`, a registry header uses
`leafHost = registry` and `leafKey = bytes32(0)`, and a registry-module leaf
uses `leafHost = registry` and `leafKey = bytes32(moduleIndex)`. Facts and the
rolling root are exact:

```solidity
bytes32 pointerFactsHash = keccak256(abi.encode(
    pointerTarget,
    pointerCodeHash,
    pointerFrozen,
    pointerModuleType,
    pointerInterfaceId,
    pointerRegistry,
    uint8(pointerRegistryStatus),
    pointerModuleManifestHash,
    pointerDeploymentManifestHash,
    uint64(pointerRevision)
));

bytes32 registryHeaderFactsHash = keccak256(abi.encode(
    registry.codehash,
    moduleCount,
    registrationChainHash,
    uint64(registrationRecordCount),
    registryManifestHash,
    keccak256(bytes(registryManifestURI)),
    uint64(registryManifestRevision)
));

bytes32 registryModuleFactsHash = keccak256(abi.encode(
    moduleAtIndex,
    uint8(moduleStatus),
    moduleType,
    moduleVersion,
    moduleInterfaceId,
    moduleGasLimit,
    moduleRuntimeCodeHash,
    moduleDeploymentManifestHash,
    moduleManifestHash,
    keccak256(bytes(moduleManifestURI)),
    uint64(moduleRevision)
));

bytes32 inventoryLeafHash = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_LEAF_V1,
    uint8(leafKind),
    leafHost,
    leafKey,
    leafFactsHash
));
bytes32 nextInventoryChainHash = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_CHAIN_V1,
    inventoryChainHash,
    uint64(leafIndex),
    inventoryLeafHash
));
bytes32 inventoryStateRoot = keccak256(abi.encode(
    STREAM_SYSTEM_MANIFEST_BOOTSTRAP_INVENTORY_ROOT_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    address(core),
    uint64(inventoryLeafCount),
    inventoryChainHash
));
```

`pointerFactsHash` is formed from the exact ten trailing fields returned by
`getSatellitePointer(pointerType)`. The registry header commits the live
registry runtime code hash and requires `registrationRecordCount == moduleCount`;
each module leaf resolves the address
from `moduleAt` and the remaining fields from `moduleRecord`. The execution-
generated `registeredAt` and `statusUpdatedAt` fields are deliberately excluded
for the same reason they are excluded from scheduled registry transition hashes
and the system-manifest payload. Every read must decode canonically and every
count/index/revision conversion must fit `uint64`. The trailing returns of
`systemManifestBootstrapState()` expose both expected and current roots/counts,
the bound Core/satellite/code hashes, the exact genesis authority, and the
actual root pointer accepted at seal; adding return values does not change its
`0x8a2d979b` selector.

During bind, genesis trigger records are materialized in strict ascending
`(uint160(triggerTarget), uint32(triggerSelector))` order and update
`triggerSetHash = keccak256(abi.encode(STREAM_SYSTEM_MANIFEST_BOOTSTRAP_TRIGGER_V1,
priorHash, triggerTarget, triggerSelector, triggerCodeHash,
allowedActionClassMask))`. Post-seal registrations remain possible only by the
normal isolated terminal-freeze path and do not alter the sealed genesis root.

The only pre-seal tail-scan exception is the following exact bootstrap branch.
A bootstrap-scoped action containing one or more expected protected-writer
pairs may omit the final manifest publication only when every such pair has
already been registered with its exact expected code hash and class mask, the
action proposer is `genesisBootstrapAuthority`, and all normal mask/class/code-
hash checks pass at both scheduling and execution. The exception suppresses
only the otherwise-required tail call; it does not relax call isolation,
classification, transition, delay, veto, or target-side authorization. A
manifest tail is forbidden while unsealed except in the exact seal batch
below, and post-seal trigger registration remains a one-call-only class-2
action. Thus
the authority can populate the registry and Core-pointer state from which the
first payload is generated without publishing a knowingly partial payload.
The branch predicate begins with `!sealed`, is rechecked at execution, and no
function can clear `sealed`; after the seal flips it can never be reached
again.

The seal is an exact class-3 two-call batch: executor self-call
`sealSystemManifestBootstrap()` first and the first
`publishStreamSystemManifest` call last, both zero value. The executor requires
the current action's proposer to equal `genesisBootstrapAuthority`; no prior
manifest publication; `pendingScheduledActionCount() == 1` with that sole entry
equal to the currently executing seal action; exact expected
trigger hash/count and a full enumeration/mapping walk equal to the bound set;
the final
registry and every Core pointer (including the already terminal-frozen
`SYSTEM_MANIFEST` family) produce the exact bind-recorded inventory root and
leaf count under the formula above. It decodes the final publication call,
requires a nonzero actual root pointer and its update's `manifestHash` to equal
the bind-recorded content commitment, parses the live root descriptor and
chunks under [LTA-MANIFEST], and independently recomputes that same
`manifestHash`. The tail's normal per-call scope/old/new hashes commit the
actual pointer and derived satellite state; no constructor or bind commitment
contains the root address or a state hash that embeds it. The seal stores that
actual pointer as `sealedPayloadPointer`, flips `sealed` before the tail call, and emits
only after the satellite publication succeeds; atomic reversion restores the
unsealed bit and zero sealed pointer if publication fails. From that
transaction onward the bootstrap
authority is ignored forever and every registered writer is subject to the
normal tail scan. There is no transaction boundary between sealing and the
first manifest publication.

Bootstrap goldens cover the complete ordered ceremony and reject a second
seal; a pre-seal action proposed by any identity other than the exact
genesis authority at scheduling or execution; missing, extra, skipped,
substituted, or out-of-order triggers; a wrong trigger code hash or mask; an
unregistered or non-expected protected writer; any pre-seal tail outside the
seal batch; any pre-seal class-`6`, role/admin, native-value, or other
non-ceremony action; an attempt to queue a second action; any cancelled,
vetoed, or virtually expired action whose pending-count accounting is not
materialized back to zero; a seal whose sole pending/current-action invariant
fails; prior publication; incomplete or pending registry/pointer work; a
mutable or wrong `SYSTEM_MANIFEST` pointer; a mismatched actual root/content
hash/satellite per-call state;
a malformed descriptor, chunk/hash mismatch, or any attempt to bind the root
address before the seal action; a mismatched live-inventory root/count or
registry record-chain count; a seal
batch with any third call; failed-tail rollback; and every protected
mutation after sealing that omits its required final tail. A positive golden
also proves that the bounded no-tail population branch succeeds before seal
and that the identical call shape fails without a tail immediately after
seal.

### Emergency-Restoration Eligibility [GOV-EMERGENCY-RESTORATION]

> **Superseded in full by ADR 0017.** The launch target has no emergency-
> restoration registry, selectors, events, domains, class-`6` writer, or
> eligibility records. The material below is retained only to preserve the
> decision history; it is non-normative for implementation, conformance, and
> release artifacts. Class ID `6` is reserved `retired_pre_genesis`,
> forbidden, and never reusable.

Numeric class `6` is fail-closed to an exact append-only eligibility registry;
the zero delay is never available merely because a proposer labels an action
`EMERGENCY_RESTORATION`.

```solidity
// Zero means ineligible; exact target plus selector prevents aliasing.
mapping(address => mapping(bytes4 => bytes32))
    private _emergencyRestorationCodeHash;

struct EmergencyRestorationEligibilityEntry {
    address target;
    bytes4 selector;
}
EmergencyRestorationEligibilityEntry[]
    private _emergencyRestorationEligibilityEntries;
bytes32 private _emergencyRestorationEligibilityChainHash;

function emergencyRestorationEligibility(address target, bytes4 selector)
    external
    view
    returns (bool eligible, bytes32 targetCodeHash);

function registerEmergencyRestorationEligibility(
    address target,
    bytes4 selector
) external;

function emergencyRestorationEligibilityCount()
    external
    view
    returns (uint256);

function emergencyRestorationEligibilityAt(uint256 index)
    external
    view
    returns (address target, bytes4 selector, bytes32 targetCodeHash);

function emergencyRestorationEligibilityChainHash()
    external
    view
    returns (bytes32 chainHash, uint64 recordCount);

event EmergencyRestorationEligibilityRegistered(
    uint16 schemaVersion,
    address indexed target,
    bytes4 indexed selector,
    bytes32 targetCodeHash,
    bytes32 indexed actionId
);
```

Selectors are `0xf23a1e43` for
`emergencyRestorationEligibility(address,bytes4)` and `0x9e842aea` for
`registerEmergencyRestorationEligibility(address,bytes4)`, plus `0xffd0e631`,
`0xe249cded`, and `0x927836c4` for the count, indexed-at, and chain-hash reads.
The schema-v1 event
topic is
`0x58f0981cb5de22437b5c66dda67857f5ec829b10c47f4e75ac208966fd9c7088`
for
`EmergencyRestorationEligibilityRegistered(uint16,address,bytes4,bytes32,bytes32)`;
`target`, `selector`, and `actionId` are indexed.

Registration hashes are exact:

```solidity
bytes32 constant STREAM_EMERGENCY_RESTORATION_SCOPE_V1 =
    0xb9085dad05460da2726c7e111c53618efbcaf3fefea1e4d419ce162fe04e8d0b;
    // keccak256("6529STREAM_EMERGENCY_RESTORATION_SCOPE_V1")

bytes32 constant STREAM_EMERGENCY_RESTORATION_STATE_V1 =
    0x9e9da69a2ae8579f9356a29767b060277c495f965d4d7ae73169e241232160ae;
    // keccak256("6529STREAM_EMERGENCY_RESTORATION_STATE_V1")

bytes32 constant STREAM_EMERGENCY_RESTORATION_ELIGIBILITY_RECORD_V1 =
    0xbc91b88f68461f99b3836432e21ee3043827c2937229121ccbb955fee3125004;
    // keccak256("6529STREAM_EMERGENCY_RESTORATION_ELIGIBILITY_RECORD_V1")

bytes32 constant STREAM_EMERGENCY_RESTORATION_ELIGIBILITY_CHAIN_V1 =
    0xed9c1773f24c613652817d2dc58a04d22ceda9bb51fade48ea848ae5d322f340;
    // keccak256("6529STREAM_EMERGENCY_RESTORATION_ELIGIBILITY_CHAIN_V1")

bytes32 scopeHash = keccak256(abi.encode(
    STREAM_EMERGENCY_RESTORATION_SCOPE_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    target,
    selector
));

bytes32 eligibilityStateHash = keccak256(abi.encode(
    STREAM_EMERGENCY_RESTORATION_STATE_V1,
    scopeHash,
    eligible,
    targetCodeHash,
    uint64(eligibilityCount),
    eligibilityChainHash
));

bytes32 eligibilityRecordHash = keccak256(abi.encode(
    STREAM_EMERGENCY_RESTORATION_ELIGIBILITY_RECORD_V1,
    uint64(eligibilityIndex),
    target,
    selector,
    targetCodeHash
));
bytes32 nextEligibilityChainHash = keccak256(abi.encode(
    STREAM_EMERGENCY_RESTORATION_ELIGIBILITY_CHAIN_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    eligibilityChainHash,
    eligibilityRecordHash,
    uint64(eligibilityIndex)
));
```

The registration entry accepts only an isolated executor self-call under
`TERMINAL_FREEZE` (`2`) with exact per-call old/new hashes, a nonzero deployed
target and selector, an absent rule, and the observed nonzero runtime code
hash. The old state is ineligible with zero code hash and the new state is
eligible with the observed hash. `eligibilityIndex` is the pre-state count; the
new state also commits count plus one and `nextEligibilityChainHash`, rejecting
uint64 overflow. It writes the mapping, append-only key, count, and chain before
emitting. The enumeration count/at/chain reads agree and reconstruct every
eligible exact pair from state. It has no remove,
replace, wildcard, target-only, owner-direct, or class-6 registration path.
The entry additionally requires `sealed == true`; class-6 eligibility is never
part of the pre-seal ceremony and cannot be queued across the bootstrap sunset.
The launch implementation narrows the selector to the single reviewed
`emergencyRaiseGasParameter(bytes32,uint256)` entrypoint (`0x4fa1b5ad`) and
requires a canonical `governanceAuthority()` read from the target to equal this
Executor. RoleRegistry and arbitrary selector pairs are rejected before any
eligibility count or chain write. Adding another class-6 selector requires an
explicit specification and implementation revision plus a code-hash-pinned
catalog/deployment allowlist; terminal registration alone is not proof that a
target enforces the class-6 incident predicate.

At both scheduling and execution, every class-6 call must have nonempty
selector-bearing calldata, `value == 0`, deployed target code, an exact eligible
`(target, selector)` pair, and a live runtime code hash equal to the registered
hash. Class `6` never admits empty-calldata/native transfers or the approved-
native-receiver exception. Conversely, a registered emergency selector must be
scheduled only as class `6`. A batch may contain several calls only when every
call independently passes these rules; any rule registered after scheduling is
rechecked at execution.

Eligibility is only the executor backstop. Every eligible target independently
requires `currentAction().actionClass == 6`, a nonzero action ID, exact per-call
scope/old/new commitments, and its own fresh incident proof and bounded
restoration predicate. Before class `6` is enabled, every existing GGP and GTP
host — not only Core — must migrate from authority-only checks to these
target-side class/context checks. In particular, lower, ordinary raise,
probe-rebind, and unrelated admin selectors remain ineligible and reject class
`6` at the target even if reached from the executor.

Goldens cover registration isolation/terminal veto, exact selector and code-
hash matching, missing/stale eligibility, zero/nonzero value, empty/native
calls, mixed eligible/ineligible batches, emergency selector under a non-6
class, lower/rebind under class `6`, all pre-existing GGP/GTP hosts, and a
registered emergency raise whose target rejects stale/passing/wrong-value or
over-bound probe evidence. They reject registration before seal and any
pre-seal action that attempts to queue one past seal. They also enumerate `0..count-1`, recompute the
eligibility record chain, compare every mapping entry, and reject out-of-range
or count/chain/state-hash drift.

### Material Actions And Holder Classes [GOV-MATERIAL]

Amended by ADR 0011 (decision R10). "Material actions" are: any staged
governance action class; Core satellite pointer moves; registry lifecycle
changes; GGP changes; freeze, finality, and recovery operations; asset
policy transitions; role grants and revocations; successor declarations;
and treasury or endowment movements. Material actions must be executable
by Safe multisigs and governor contracts. EOA-class holders may hold
material-action roles only during a time-boxed deployment bootstrap whose
sunset (transfer of every material role to Safe or governor holders) is a
deployment gate recorded in the ceremony evidence. Executability is
verified, not assumed: a deployment-gated rehearsal executes at least one
action of every material class from a Safe multisig and one from a
governor contract, with the transcripts retained as release evidence
(ADR 0012 decision T5). The window/latency compatibility proof is a
standing obligation, not a one-time gate: any post-genesis handover of a
material role to a slower holder class re-runs the latency rehearsal
before the grant executes, and a handover without a passing proof is
nonconformant (ADR 0014 decision V4). Value-receiving role holders must
prove in the same rehearsal that they can receive native ETH
(ADR 0014 decision V4). Non-material operational grants held by EOA-class
wallets are reviewed on the funding-renewal cadence and either
re-justified in the ceremony evidence or sunset (ADR 0012 decision T5).

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

This subsection also pins the EIP-7702 posture once for every signature
surface (ADR 0013 decision U6). An EOA bearing an EIP-7702 delegation
designation is a delegated EOA: its account-type classification is
observed at verification time — code presence is a per-observation
fact, never a cached account-type fact — and while designated, ERC-1271
verification targets whatever code the account exposes at that
observation. A canonical ECDSA signature from the account's own key
remains valid alongside ERC-1271 verification for every verifying
layer, so delegation never strands a signer. No verifying layer may
branch on code presence for any purpose other than selecting the
signature-verification path this class pins, and wallet-class
enumerations in subsystem specs note 7702 delegated EOAs as members of
the class.

### Governance Window Floors And Unpause [GOV-WINDOWS]

Amended by ADR 0010 (decisions D7.2). Windows are sized for multisig and
governor-contract latency, not for fast single signers:

1. Delayed action classes must keep an open-to-execute window
   (`expiresAfter - notBefore`) of at least 7 days.
2. Emergency classes must be executable by role-redundant holders —
   defined testably (ADR 0013 decision U5) as at least two independently
   controlled holders per emergency role, neither of which is a
   single-signer EOA — and assume at least 4 hours of coordination
   latency; no emergency path may presume a single hot key. The terminal-freeze veto window floor is 72
   hours (ADR 0011 decision R10) so governor-contract holders can
   realistically exercise it. Class ID `6` is retired before genesis and is
   not an emergency path.
3. Unpause is a dedicated operational class: a distinct `ROLE_UNPAUSE`
   (grantable to a Safe or governor contract) executes unpause with no
   timelock and an evented reason. Pause guardians cannot unpause; unpause
   holders cannot pause. The two-tier delay model does not apply to
   unpause.
4. `EMERGENCY_RESTORATION` (numeric ID `6`) is
   `retired_pre_genesis`. Scheduling and execution reject it, no selector can
   be registered for it, and the numeric ID is never reusable (ADR 0017).

Execution rules:

1. `scheduleGovernanceBatch` allocates the next nonce, derives and checks the
   three action-level aggregate hashes, computes the canonical V2 action ID,
   stores the batch `callsHash` in `GovernanceAction.callHash` plus the
   validated calldata pointer, and emits `GovernanceActionScheduled`.
   `scheduleGovernanceAction` is the equivalent one-call wrapper.
2. `notBefore` must be at least `block.timestamp + minimumDelay(actionClass)`
   unless the action is `IMMEDIATE_TIGHTENING` and the implementation's
   calldata-aware tightening classifier proves it cannot loosen policy.
3. `expiresAfter` must be greater than `notBefore` and within a launch-pinned
   maximum action lifetime. Delayed classes keep the seven-day floor above.
4. The stored `callHash` is the V2 `callsHash`, never
   `keccak256(singleCallData)`. Execution recomputes every descriptor and the
   three action-level aggregates, requires the ordered supplied calldata to be
   byte-identical to the decoded scheduled SSTORE2 publication, and requires
   `msg.value == sum(calls[].value)`. Each nonempty calldata element has length
   at least four, its leading selector matches, and its target has code. The
   sole empty-calldata exception has selector zero, positive value, and an
   approved native receiver.
5. Anyone may execute a scheduled action after `notBefore` unless the action
   class requires a named executor in the manifest. Permission to schedule and
   cancel remains role-gated.
6. Execution rechecks every subsystem-specific invariant named in the action
   manifest, including old value hash, new value hash, pointer code hash,
   registry eligibility, interface ID, freeze state, owed-funds boundary, and
   terminal-freeze veto status where applicable.
7. Execution uses the stored `callsHash`, scheduled calldata pointer, and full
   caller-supplied descriptor array only after all V2 hashes, selectors, bytes,
   tail/eligibility rules, and action ID match. The first-call target/selector
   fields retained for indexing are never execution authority, and arbitrary
   caller-selected bytes cannot execute.
   The bounded-returndata assembly call used for execution does not remove the
   underlying authority risk of forwarding proposal-selected native value;
   it only prevents a returndata bomb. Slither no longer recognizes that
   assembly call as `arbitrary-send-eth`, so issue #658 and the closed-world
   action-policy/deployment gate remain the manual fail-closed security record
   for destination, value, balance-source, and rollback review.
8. A successful execution stores `EXECUTED`, records `executor`, emits
   `GovernanceActionExecuted`, and cannot be replayed.
9. Cancellation is allowed only while stored status is `SCHEDULED`, before
   execution, and while `block.timestamp <= expiresAfter`; it stores
   `CANCELLED`, records `canceller`, and emits `GovernanceActionCancelled`.
   Once `block.timestamp > expiresAfter`, cancellation reverts with
   `GovernanceActionExpiredWindow` and cannot replace the virtual `EXPIRED`
   status.
10. `materializeExpiredAction` may be called by anyone after `expiresAfter` to
    store `EXPIRED` and make the virtual expiry explicit.

Transition table:

```text
NONE       -> SCHEDULED   schedule valid action
SCHEDULED  -> EXECUTED    execute after notBefore and before expiresAfter
SCHEDULED  -> CANCELLED   authorized cancellation no later than expiresAfter
SCHEDULED  -> VETOED      terminal-freeze guardian veto before deadline
SCHEDULED  -> EXPIRED     virtual or materialized after expiresAfter
CANCELLED  -> terminal
EXECUTED   -> terminal
EXPIRED    -> terminal
VETOED     -> terminal
```

The release manifest must include a machine-readable governance action policy
catalog. Each protected selector is mapped to role, action class, minimum delay,
tightening/loosening classifier, old/new value predicate, and whether
permissionless execution after delay is allowed. Governance code
and CI use this catalog as the conformance target; prose examples are not
authority.

Selector-wide irreversible-freeze registration is valid only when every
successful invocation of that selector is terminal. A polymorphic selector is
never put in that boolean registry. In particular,
`setCollectionStatus(uint256,uint8)` (`0x68abd161`) is explicitly excluded:
the executor's calldata-aware policy requires `IMMEDIATE_TIGHTENING` (`0`) for
`PAUSED`, `DELAYED_LOOSENING` (`1`) for `ACTIVE`, and `TERMINAL_FREEZE` (`2`)
for `CLOSED`; a class-2 schedule enters the ordinary veto live set and guardian
checks. Core independently decodes `newStatus` and requires the same class and
exact old/new state hashes at execution. Golden tests prove that a `CLOSED`
call cannot schedule or execute as class `0` or `1`, while pause and resume are
not accidentally forced through the terminal class.

Terminal freeze actions require an explicit guardian/veto surface:

```solidity
function terminalFreezeVetoGuardian(bytes32 scopeHash)
    external
    view
    returns (address guardian, uint64 vetoDeadline);

function terminalFreezeVetoGuardianSet(bytes32 scopeHash)
    external
    view
    returns (
        address roleRegistry,
        bytes32 scopedRole,
        uint256 scopedHolderCount,
        bytes32 globalRole,
        uint256 globalHolderCount,
        uint64 vetoDeadline
    );

function terminalFreezeGuardianConfigCommitment(bytes32 actionId)
    external
    view
    returns (bytes32 commitment);

function terminalFreezeLiveActionCaps()
    external
    pure
    returns (uint256 totalCap, uint256 nonRootCap, uint256 proposerCap);

function terminalFreezeLiveActionUsage(bytes32 scopeHash, address proposer)
    external
    view
    returns (
        uint256 totalMemberships,
        uint256 nonRootMemberships,
        uint256 proposerMemberships
    );

function pruneElapsedTerminalFreezeActions(bytes32 scopeHash)
    external
    returns (uint256 prunedCount);

function terminalFreezeActionPage(bytes32 scopeHash, uint256 cursor, uint256 limit)
    external
    view
    returns (
        bytes32[] memory actionIds,
        uint64[] memory vetoDeadlines,
        uint256 nextCursor
    );

function vetoTerminalFreeze(bytes32 actionId, bytes32 reasonHash) external;
```

At least two global `ROLE_TERMINAL_FREEZE_VETO` contract holders satisfying the
role-redundancy floor are required to schedule or execute a terminal freeze.
The scoped role
`keccak256(abi.encode(ROLE_TERMINAL_FREEZE_VETO, scopeHash))` is additive to,
not a fallback for, that global set. A global holder or a holder for any
distinct affected scope may veto the whole atomic batch while it is scheduled
and strictly before `notBefore`. A vetoer cannot edit the action, execute a
different action, sweep funds, or unfreeze an already executed terminal freeze.

`terminalFreezeVetoGuardian` is a compatibility singleton view: it returns a
nonzero address only when the deduplicated scoped-plus-global union has exactly
one holder; zero means zero or multiple holders and never means that the veto
surface is absent. Integrations enumerate both additive sets from the returned
RoleRegistry and role keys in `terminalFreezeVetoGuardianSet`. Both views
return the earliest still-open deadline for the scope, so a later decoy action
cannot shadow an earlier veto deadline.

Every terminal action snapshots the exact relevant guardian configuration at
schedule and rechecks it at execution. Let `appendHolders(role, h)` be:

```solidity
h = keccak256(abi.encode(
    TERMINAL_GUARDIAN_HOLDER_V1,
    h,
    role,
    roleHolderCount(role)
));
for (uint256 i; i < roleHolderCount(role); ++i) {
    address holder = roleHolderAt(role, i);
    h = keccak256(abi.encode(
        TERMINAL_GUARDIAN_HOLDER_V1,
        h,
        role,
        i,
        holder,
        holder.codehash
    ));
}
```

The schedule-time commitment is:

```solidity
bytes32 h = keccak256(abi.encode(
    TERMINAL_GUARDIAN_CONFIG_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    address(roleRegistry),
    address(roleRegistry).codehash,
    globalTerminalRoleMutationChain,
    uint64(globalTerminalRoleMutationRevision)
));
h = appendHolders(ROLE_TERMINAL_FREEZE_VETO, h);

uint256 distinctScopeCount;
for (uint256 i; i < calls.length; ++i) {
    if (_scopeSeenBefore(calls, i, calls[i].scopeHash)) continue;
    bytes32 scopedRole = keccak256(abi.encode(
        ROLE_TERMINAL_FREEZE_VETO,
        calls[i].scopeHash
    ));
    (bytes32 chain, uint64 revision) = roleMutationState(scopedRole);
    h = keccak256(abi.encode(
        TERMINAL_GUARDIAN_SCOPE_V1,
        h,
        calls[i].scopeHash,
        scopedRole,
        chain,
        revision
    ));
    h = appendHolders(scopedRole, h);
    ++distinctScopeCount;
}
bytes32 commitment = keccak256(abi.encode(
    TERMINAL_GUARDIAN_CONFIG_V1,
    h,
    distinctScopeCount
));
```

Distinct scopes are processed in first-call order; holder order is the exact
RoleRegistry enumeration order. The commitment therefore detects registry
runtime-code drift, global or relevant scoped A-to-B-to-A role history, holder
order/membership changes, and holder runtime-code drift. Unrelated role changes
do not invalidate it. Execution reverts with
`TerminalFreezeGuardianConfigDrift` on any mismatch.

The one-way bootstrap's initial global set uses a separate initial envelope:

```solidity
bytes32 setHash = keccak256(abi.encode(
    INITIAL_TERMINAL_GUARDIAN_SET_V1,
    uint256(block.chainid),
    address(governanceExecutor),
    address(roleRegistry),
    guardians.length,
    terminalRoleMutationChain,
    uint64(terminalRoleMutationRevision)
));
for (uint256 i; i < guardians.length; ++i) {
    setHash = keccak256(abi.encode(
        TERMINAL_GUARDIAN_HOLDER_V1,
        setHash,
        i,
        guardians[i],
        guardians[i].codehash
    ));
}
```

The initial array contains 2 through 16 distinct code-bearing, non-EIP-7702
holders in strictly increasing address order. The role chain/revision and
enumeration produced by bootstrap grants must match that array exactly.

The four terminal-guardian domains are:

| Constant | String preimage | Value |
| --- | --- | --- |
| `TERMINAL_GUARDIAN_CONFIG_V1` | `6529STREAM_TERMINAL_GUARDIAN_CONFIG_V1` | `0x08d0b0fbace471ddf2e5f522c3621b3fdd92b1a17fce4c1effb39e5ad1d9243e` |
| `TERMINAL_GUARDIAN_SCOPE_V1` | `6529STREAM_TERMINAL_GUARDIAN_SCOPE_V1` | `0x077788610e4d141120fd85c2372b9673a8a4ac7633f4d79522bf19565809252a` |
| `INITIAL_TERMINAL_GUARDIAN_SET_V1` | `6529STREAM_INITIAL_TERMINAL_GUARDIAN_SET_V1` | `0x9ee586231c2f5d832b7ab74ebdf30550f7b6ac36ff7f5d4ceedebd713c364b99` |
| `TERMINAL_GUARDIAN_HOLDER_V1` | `6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1` | `0x6043687fb0254773308ed2f9a8d9a86c356d45779c952f0ffd71d8beaa5a57d8` |

Terminal-freeze discovery is bounded against proposer denial of service. One
distinct action occupies at most one membership in each distinct call scope,
even if that scope repeats in the batch. Each scope permits 64 raw memberships:
at most 48 may be scheduled by non-root proposers, each non-root proposer may
occupy at most 8, and the remaining 16 are reserved for the live governance
root or the exact pre-seal bootstrap authority. Root-capacity classification is
snapshotted when the action schedules; a later root rotation neither
reclassifies old memberships nor changes their cleanup accounting.

Raw membership includes an elapsed veto deadline until bounded compaction.
Scheduling compacts each distinct scope before applying caps; anyone may also
call `pruneElapsedTerminalFreezeActions`. Pruning removes only discovery
memberships and quota counters and does not change action status or the
pending-action count. Every distinct-scope append and every actual removal
emits schema-v1
`TerminalFreezeActionMembershipUpdated(uint16,bytes32,bytes32,address,bool,uint8,bool,uint64,uint256,uint256)`
after the membership and quota post-state is written. `present` is `true` only
for an append. `mutationCause` is `1` for append, `2` for elapsed compaction,
and `3` for action-terminal cleanup. `rawIndex` is zero-based and
`remainingCount` is the post-mutation raw membership count. On removal,
indexers deterministically apply the same swap-and-pop rule: when `rawIndex <
remainingCount`, the prior last member moves into `rawIndex`; equality means
there was no swap. The event owns raw membership and quota replay, while the
governance lifecycle event owns action status. `present` describes raw
membership, not whether the veto deadline remains live at the current block.
On scheduling, all distinct-scope append events precede
`TerminalFreezeGuardianConfigCommitted`, which precedes
`GovernanceActionScheduled`. On execute, veto, cancel, or materialized expiry,
all action-terminal membership removals precede the corresponding lifecycle
event. Elapsed compaction intentionally leaves the private action-to-scope
cleanup relation until a later terminal transition. Later execute, veto,
cancel, or expiry cleanup tolerates an already-deindexed scope. All
multi-scope writes, membership events,
nonce/pending writes, and counter changes roll back if any later scope fails a
cap.

`terminalFreezeActionPage` exposes the raw swap-and-pop order with a maximum
limit of 64. `cursor` may equal the current membership count, a zero limit is
valid, and entries may be elapsed; callers compare each deadline to the current
timestamp. The existing dense live-count/index views continue to skip elapsed
memberships without mutating storage.

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
| `ROLE_PAUSE_GUARDIAN` | Immediately pauses approved domains (tightening only); disjoint from unpause (ADR 0012 decision T5) | root | this ADR (Role Model, [GOV-ROLES]); guardian-module holders per [`docs/stream-long-term-architecture.md`](../stream-long-term-architecture.md) [LTA-GUARDIAN] |
| `ROLE_UNPAUSE` | Executes unpause with no timelock and an evented reason; disjoint from pause guardians | root | this ADR, [GOV-WINDOWS].3 |
| `ROLE_COLLECTION_FINALITY_ADMIN` | Executes `finalizeCollectionArtwork` / scoped finality subject to component verification | root | [`docs/stream-long-term-architecture.md`](../stream-long-term-architecture.md) (Artwork Finality Freeze [LTA-FINALITY]) |
| `ROLE_TERMINAL_FREEZE_VETO` | Per-scope terminal-freeze veto guardian resolved through `terminalFreezeVetoGuardian`; independent of scheduling roles | root | this ADR ([GOV-WINDOWS] veto surface); [`docs/stream-long-term-architecture.md`](../stream-long-term-architecture.md) [LTA-FREEZE] rule 4 |
| `ROLE_ENTROPY_INCIDENT_DECLARER` | Declares entropy requests unrecoverable under the fresh-recovery policy | operational | [`docs/stream-entropy-coordinator.md`](../stream-entropy-coordinator.md) [EC-INCIDENT-ROLE] |
| `ROLE_ENTROPY_REVEAL_OWNER` | Holds the declared reveal-request obligation for `ASYNC` collections within the reveal SLO (ADR 0011 decision R8) | operational | [`docs/stream-entropy-coordinator.md`](../stream-entropy-coordinator.md) [EC-REVEAL] |
| `ROLE_ARTIST_REGISTRY_ADMIN` | Proposes artist bindings, declares platform works, withdraws unaccepted proposals | operational | [`docs/stream-artist-authority.md`](../stream-artist-authority.md) [AA-ROLES] |
| `ROLE_ATTRIBUTION_ARBITER` | Governed arbiter for attribution disputes and post-revocation rebinding approval | root | [`docs/stream-artist-authority.md`](../stream-artist-authority.md) [AA-DISPUTE] |
| `ROLE_ARTIST_DORMANCY_ADMIN` | Initiates and completes the governed artist-dormancy procedure | root | [`docs/stream-artist-authority.md`](../stream-artist-authority.md) [AA-DORMANCY] |
| `ROLE_ATTRIBUTION_APPEAL` | Second-tier review of arbiter actions (ADR 0011 decision R7) | root | [`docs/stream-artist-authority.md`](../stream-artist-authority.md) [AA-DISPUTE] |
| `ROLE_FIXITY_OPERATOR` | Executes the mandated fixity program cadence and records cycle attestations | operational | [`docs/collection-metadata-contract.md`](../collection-metadata-contract.md) [CMC-FIXITY-PROGRAM] |
| `ROLE_EXPORT_PUBLISHER` | Publishes state exports and event-history snapshots on the mandated cadence | operational | [`docs/stream-long-term-architecture.md`](../stream-long-term-architecture.md) [LTA-EXPORT] |
| `ROLE_CLAIM_ROUTER_OPERATOR` | Operates the recipient claim-aggregation rehearsals and UX gate evidence | operational | [`docs/revenue-splits-and-royalties.md`](../revenue-splits-and-royalties.md) [RSR-CLAIM-ROUTER] |
| `ROLE_EMERGENCY_RECIPIENT` | Receives emergency-withdrawal surplus; resolved through the admin registry, never a stored raw address (ADR 0013 decision U5) | root | this ADR (emergency-withdrawal rules) |
| `ROLE_ENTROPY_ADMIN` | Configures collection entropy policy and provider assignments within staged-governance rules (ADR 0014 decision V4) | operational | [`docs/stream-entropy-coordinator.md`](../stream-entropy-coordinator.md) [EC-ROLES] |
| `ROLE_TREASURY` | Receives protocol-fee and residual value flows (reveal-fee residuals and peers); resolved through the admin registry (ADR 0014 decision V4) | root | this ADR; value-flow homes cite it |

Every authority any Stream specification references by role must appear in
this table (ADR 0013 decision U5); an authority exercised through a raw
stored address is nonconformant, and `emergencyRecipient()` reads resolve
`ROLE_EMERGENCY_RECIPIENT` through the registry.

The legacy CamelCase names in the Role Model table (for example
`UnpauseAdmin`, `PauseGuardian`) are the P0 authority descriptions; where a
production surface binds an authority into storage, an event, or a policy
hash, it binds the `ROLE_*` constant, and the registry maps the constant to
its current holder. Pause-guardian authority binds `ROLE_PAUSE_GUARDIAN`
(ADR 0012 decision T5); every surface that stores, events, or grants pause
authority uses the constant, and the registry maps it to the current
holder set.

### Governance Event Schemas [GOV-EVENTS]

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

The Governance V2 foundation and RoleRegistry event rows below are
production-exact. `topic0` is the Keccak-256 hash of `signature`; every row is
schema version `1`, and no row has more than three indexed fields.

| Signature | `topic0` | Indexed fields | Unindexed fields |
| --- | --- | --- | --- |
| `GovernanceCallDataPublished(uint16,bytes32,address,address)` | `0x5922e6285b4b955740f916aa25accf8dcd9f75131e4bde259347d27adfaf1cce` | `callDataKey` | `schemaVersion`, `pointer`, `publisher` |
| `GovernanceRootRotated(uint16,address,address,bytes32,uint64,bytes32)` | `0x08d370ac1a1f9fb20901f4973ecd503905441935a5b50d55949383fb2e577022` | `oldRoot`, `newRoot`, `actionId` | `schemaVersion`, `newRootCodeHash`, `revision` |
| `TerminalFreezeGuardianConfigCommitted(uint16,bytes32,bytes32)` | `0x53acfef70a58072f772f652e17d1aae14ab4389a12ad30c9423ed0a887f8ba65` | `actionId`, `commitment` | `schemaVersion` |
| `GovernanceProposerUpdated(uint16,address,bool,uint64,bytes32)` | `0x220035fc1066049066bc625ffc68a6dd5d26c64d3bcf552113a2b83726f5ccc3` | `account`, `actionId` | `schemaVersion`, `enabled`, `revision` |
| `GovernanceCancellerUpdated(uint16,address,bool,uint64,bytes32)` | `0x25f1eb9ffcadbf70fdce20cb2089d1d75b4acc808a30caf8730a8cac77191a47` | `account`, `actionId` | `schemaVersion`, `enabled`, `revision` |
| `TighteningCallUpdated(uint16,address,bytes4,bool,bytes32,uint64,bytes32)` | `0x036c8ff514a46d08a6d064b8303207c224554087f3a378bf88ca1d8f8d4ece58` | `target`, `selector`, `actionId` | `schemaVersion`, `tightening`, `targetCodeHash`, `revision` |
| `ApprovedNativeReceiverUpdated(uint16,address,bool,uint64,bytes32)` | `0xd02c58454df06c3acae4d99fd37a3031799db442605179362d1ee19588f9f3b4` | `receiver`, `actionId` | `schemaVersion`, `approved`, `revision` |
| `FreezeSelectorUpdated(uint16,address,bytes4,bool,bytes32,uint64,bytes32)` | `0x99b0305b9daf0dfcf7c496155ec00fbc7f4c03a7d91f6436f7edc0a3cef91ac3` | `target`, `selector`, `actionId` | `schemaVersion`, `freeze`, `targetCodeHash`, `revision` |
| `TerminalFreezeActionMembershipUpdated(uint16,bytes32,bytes32,address,bool,uint8,bool,uint64,uint256,uint256)` | `0xfca432e480c87cddba2b629d363f2ad28733127441639c4f7a1d84edca17d676` | `scopeHash`, `actionId`, `proposer` | `schemaVersion`, `present`, `mutationCause`, `usesRootCapacity`, `vetoDeadline`, `rawIndex`, `remainingCount` |
| `StreamRoleGranted(uint16,bytes32,address,uint8,address,bytes32)` | `0x9b9b410e01df674848a6af9c4677f982bcd5957194cd51eb34ed04532bc7a2aa` | `role`, `holder`, `actionId` | `schemaVersion`, `grantClass`, `actor` |
| `StreamRoleRevoked(uint16,bytes32,address,uint8,address,bytes32)` | `0x674124c7fd9b40a7e8da58914611e15b27e8f0645cae8abf147adb7eb68d841f` | `role`, `holder`, `actionId` | `schemaVersion`, `grantClass`, `actor` |
| `RoleManagerUpdated(uint16,address,bool,address,bytes32,uint64,bytes32)` | `0xb08dd46dd5caf79cdfd7060f42cebba12dc707c2d25f0646753c6c240ea5b627` | `account`, `admin`, `actionId` | `schemaVersion`, `enabled`, `configChainHash`, `configRevision` |
| `RoleMutationCommitted(uint16,bytes32,address,bool,bytes32,uint64,bytes32,uint64,bytes32)` | `0xe7db8fc830e4a9ad4e109992e6cf9d48e383ea6b7b37cf64be502d2ad4143666` | `role`, `holder`, `actionId` | `schemaVersion`, `granted`, `roleChainHash`, `roleRevision`, `globalChainHash`, `globalRevision` |

Executor-mediated RoleRegistry grant, revoke, scoped mutation, and manager
configuration events carry the exact nonzero executing action ID. A direct
registered-RoleManager mutation of an operational role is not a staged action
and uses `bytes32(0)` in both its `StreamRole*` and
`RoleMutationCommitted` events. The one bootstrap global terminal-guardian
grant exception also uses that zero sentinel. The sentinel is selected from the
actual actor/path; a direct manager must never inherit an unrelated in-flight
Executor context. `RoleManagerUpdated` has no direct or bootstrap path and
therefore always carries a nonzero action ID.

For the [LCM-EVENTS] one-fact/one-owner catalog, `StreamRoleGranted` owns a
role-membership grant and `StreamRoleRevoked` owns a role-membership revoke,
including the grant class and actor. `RoleMutationCommitted` instead owns the
role-local and global chain/revision commitments. Its `role`, `holder`,
`granted`, and `actionId` fields are required same-execution mirrors in the
corresponding role-membership fact family; they are not a second membership
owner. The generated catalog must encode those owner and required-mirror tags
before this event family enters a production release profile.

`TerminalFreezeActionMembershipUpdated` owns the raw terminal-discovery
membership and quota facts. Its `actionId` identifies the affected action; it
is not an authorizing governance context for permissionless elapsed
compaction. `GovernanceCallDataPublished` announces content-addressed
pre-action bytes and does not assert that any action used them. Every actual
governed configuration row above carries its authorizing action ID as required
by [LCM-EVENTS]. These rows must enter the generated release event catalog
before Governance V2 is in a production deployment profile.

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
  pre-audit. [Superseded (ADR 0014 decision V4): production deployments
  execute material actions only through the staged [GOV-ACTION-ID] model;
  direct Safe execution without the onchain timelock is a pre-audit
  development convenience only and is nonconformant at any deployment
  gate.]
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
