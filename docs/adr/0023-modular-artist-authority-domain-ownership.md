# ADR 0023: Global Artist Semantic-Domain Ownership And Atomic Recipes

- Status: Proposed
- Date: 2026-08-09
- Decision owners: protocol maintainers
- Scope: non-roadmap successor architecture acceptance packet
- Supersedes if accepted:
  [ADR 0022](0022-immutable-artist-registry-validation-adapter.md)'s
  single-state-owner artist-registry topology, the abandoned monolithic
  `StreamArtistRegistry` implementation shape, and the
  `StreamArtistPayloadStore` semantic-state shape
- Does not supersede: any field in the 57-row, 18-column issue #670 freeze,
  its overlay/effective implementation stops, or its source requirements

## Status And Authority

This ADR is **Proposed**. It records a selected architecture for independent
review. It is not accepted merely because the ADR, matrix, schema, checker, and
tests exist. No Solidity implementation, deployment candidate, release
binding, audit credit, or readiness follows from this packet.

Issue #670 is closed and remains closed. This is a bounded, non-roadmap
architecture successor; it does not reopen or edit completed #670 scope.

The machine-readable normative companion is the
[global artist semantic-owner matrix v2](../architecture/artist-semantic-owner-matrix-v2.json).
Its strict
[schema](../architecture/artist-semantic-owner-matrix-v2.schema.json),
[checker](../../scripts/check_artist_semantic_owner_matrix.py), and
[hostile tests](../../scripts/test_artist_semantic_owner_matrix.py) bind:

- all 57 source rows;
- all 18 columns in every row;
- all 37 named record domains;
- all 54 named events;
- all 64 normalized replay surfaces;
- seven global semantic owners;
- five immutable typed external providers and three platform-role authority
  surfaces;
- 57 immutable typed coordinator recipes;
- every base and effective implementation stop;
- every dependency and future source requirement; and
- the exact issue #669 stateless ERC-1271 validation boundary.

The checker pins the source matrix SHA-256 and independently pins the schema
file SHA-256. It also checks the schema identifier, Proposed status, pre-audit
maturity, and exact critical top-level field set before relying on JSON Schema
validation.

## Problem

The earlier packet enforced one owner per operation. That is insufficient.
One operation can touch several underlying semantic domains, and two operations
can touch the same record, replay, state, or event domain. Assigning a whole
operation to one module can therefore split a shared domain between modules or
let one module write another module's state.

Concrete conflicts include:

- operations 2 and 7 both create `ACCEPTANCE_RECORD_DOMAIN`, so binding and
  collaborator modules cannot each own their own copy;
- operations 1 and 6 both register identity records;
- operations 1-4, 7, 13, 44, 46, and 50 can affect collection attribution
  state or its normative event;
- signature nonces, digest revocations, delegation uses, and standing
  retirement recur across otherwise unrelated operations;
- operation 15 needs the operative payout designation before it may record
  economics consent; and
- direct module-to-module reads create cyclic dependency and reentrancy risk
  when binding, collaborator, identity, attribution, payout, and consent facts
  depend on one another.

The architecture must assign one owner to the underlying semantic surface
globally, then compose operations without creating another semantic owner.

## Current Behavior

There is no artist-authority Solidity implementation in the canonical source
tree. Future sources belong under `smart-contracts/domains/artist/`; future
interfaces belong under `smart-contracts/interfaces/stream/`.

The frozen source is
`release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json`
at SHA-256
`34e768291af8fd0327cbd6d99177d4a829fa8d8076fdc18da58bf74912efa8df`.
It contains 57 ordered rows and 18 exact columns:

1. id;
2. write;
3. family;
4. validation selector;
5. write selector;
6. write-selector preimage;
7. authority;
8. signature rule;
9. typehash;
10. field mask;
11. fields;
12. current-state facts;
13. replay facts;
14. primary record;
15. secondary record;
16. dependencies;
17. events; and
18. base implementation stops.

The source overlay removes the finality stop from operations 12 and 13 but
preserves it for operation 22. This proposal mirrors both base and effective
stops; it does not reinterpret them.

The active issue #669 taxonomy reserves exactly one future high-level
`staticcall` call option at
`smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol::_validateSignerProof`.
The exact reserved row is:

- kind `call-option`;
- operation `staticcall`;
- expression `context.erc1271GasCap`;
- exact call syntax
  `address(<signer>).staticcall{gas: context.erc1271GasCap}`;
- expected count `1`;
- path class `user-path`;
- lane `artist-authority`;
- issue `#669`; and
- disposition `open-remediation-required`.

The validator source and inventory row are intentionally absent pending
architecture and interface acceptance. This packet does not edit #669-owned
files.

## Decision

### Ownership Is Global By Semantic Surface

Exactly one owner exists for every underlying artist state, record, replay, and
normative event surface. An operation is not itself an ownership boundary.

| Snapshot order | Semantic domain | Sole owner |
| ---: | --- | --- |
| 1 | Binding lifecycle | `StreamArtistBindingLifecycle` |
| 2 | Collaborator lifecycle | `StreamArtistCollaboratorLifecycle` |
| 3 | Identity and signature authority | `StreamArtistIdentityAuthority` |
| 4 | Acceptance lifecycle | `StreamArtistAcceptanceLifecycle` |
| 5 | Attribution lifecycle | `StreamArtistAttributionLifecycle` |
| 6 | Payout lifecycle | `StreamArtistPayoutLifecycle` |
| 7 | Consent and finality lifecycle | `StreamArtistConsentFinalityLifecycle` |

Each owner alone:

- stores its semantic state and records;
- advances its domain revision;
- owns its replay surfaces;
- emits events assigned to its domain;
- maintains its domain record-chain tip;
- exports its state root; and
- performs an explicit domain-local rollback or supersession.

No owner writes or rolls back another owner's surface. Owner contracts cannot
read peer owner contracts.

### Dedicated Acceptance Owner

`StreamArtistAcceptanceLifecycle` solely owns
`ACCEPTANCE_RECORD_DOMAIN`. Operations 2 (`acceptArtistBinding`) and 7
(`acceptCollaborator`) both create records in this one domain and therefore
both call the same acceptance owner.

The acceptance owner also emits the acceptance-domain events
`ArtistBindingAccepted` and `CollaboratorAccepted`. Binding and
collaborator owners cannot create shadow acceptance records or emit competing
copies of those events. Their own state changes remain in their own domains.

### Stateless Atomic Operation Coordinator

Every operation enters an explicit typed function on the immutable
`StreamArtistOperationCoordinator`. There are 57 enumerated recipe
entrypoints and 57 pinned recipe identities. There is no selector registry,
arbitrary selector/calldata route, generic `bytes` dispatcher, fallback
router, `delegatecall`, `callcode`, proxy, upgrade path, or mutable recipe.

The coordinator owns no semantic state, record, replay state, revision, state
root, record-chain tip, or normative event. It may use only a transient typed
operation reentrancy lock.

For each recipe the coordinator:

1. authenticates the exact Registry and original caller;
2. snapshots typed owner revisions/commitments in the matrix order;
3. verifies and snapshots the exact immutable external-provider address,
   runtime codehash, interface, marker, schema, and binding commitments, then
   snapshots the Core, Governance, Finality, import, role, or validator facts
   required by the frozen authority/dependency columns;
4. invokes the enumerated owner actions in the recipe's checked order;
5. passes the exact original caller and every relevant pinned revision/
   commitment to each owner; and
6. requires the exact ArchiveV2 evidence append in the same transaction.

Each owner accepts a mutation only from the immutably bound coordinator and
validates the exact original caller, operation recipe, and its pinned snapshot.
The coordinator cannot fabricate owner authority merely by being the caller.

EVM revert supplies all-or-nothing rollback. If any owner, event, replay
consumption, pin, revision check, validator call, or ArchiveV2 append fails,
all earlier calls, storage writes, and events in that recipe revert.

### No Cyclic Module Reads

Owner modules never call or read each other. Cross-domain facts are coordinator
inputs bound to exact typed revision/commitment snapshots. The coordinator
collects all snapshots before the first semantic mutation. This removes cyclic
module dependencies and ensures a later owner cannot observe a partially
committed peer state.

The fixed snapshot order puts payout before consent/finality. Operation 15
(`recordEconomicsConsent`) must include
`domain:payout_lifecycle` before `domain:consent_finality`. The consent owner
accepts only the exact typed payout revision and commitment proving the
operative payout designation referenced by the frozen row.

### Required Composite Recipes

The matrix resolves every multi-owner operation, including the following
high-risk cases.

#### Operation 1: Artist Binding Proposal And Identity Registration

The coordinator snapshots binding, identity, attribution, and Core facts, then
calls:

1. Identity owner to allocate registration replay state, create
   `ARTIST_ID_DOMAIN`, and emit `ArtistIdentityRegistered`;
2. Binding owner to create `ARTIST_BINDING_DOMAIN` and emit
   `ArtistBindingProposed`; and
3. Attribution owner to change collection attribution state and emit
   `ArtistAttributionStateChanged`.

No binding module writes identity or attribution state.

#### Operation 6: Collaborator Identity Acceptance And Registration

The coordinator snapshots collaborator and identity commitments and the
stateless signer-validation boundary, then calls:

1. Identity owner to consume signature replay, create `ARTIST_ID_DOMAIN`,
   and emit `ArtistIdentityRegistered`; and
2. Collaborator owner to terminally update the exact collaborator identity
   proposal.

The collaborator owner never stores the identity record.

#### Operation 2: Binding Acceptance

The coordinator snapshots binding, collaborator, identity, acceptance,
attribution, Core, and validator commitments, then calls:

1. Identity owner for signature nonce/digest replay consumption;
2. Acceptance owner for `ACCEPTANCE_RECORD_DOMAIN` and
   `ArtistBindingAccepted`;
3. Binding owner for the binding lifecycle transition; and
4. Attribution owner for `ArtistAttributionStateChanged`.

The collaborator snapshot proves the required acceptance set before any write.

#### Operation 7: Collaborator Acceptance And Binding Completion

The coordinator snapshots binding, collaborator, identity, acceptance,
attribution, Core, and validator commitments, then calls:

1. Identity owner for signer replay;
2. Acceptance owner for the same `ACCEPTANCE_RECORD_DOMAIN` used by
   operation 2 and for `CollaboratorAccepted`;
3. Collaborator owner for the collaborator row transition;
4. Binding owner for collaborator-complete binding state; and
5. Attribution owner for `ArtistAttributionStateChanged`.

The last collaborator can complete a binding only through this atomic recipe.

#### Operation 13: Sanction Finality And Attribution Transition

The coordinator snapshots consent/finality, attribution, Core, and Finality
commitments, then calls:

1. Consent/finality owner to validate the existing
   `SANCTION_RECORD_DOMAIN` and consume the sanction-finalization transition
   key; and
2. Attribution owner to perform and emit the exact
   `ArtistAttributionStateChanged` transition.

The sanction record never moves into the attribution owner.

#### Operation 15: Economics Consent With Payout Dependency

The coordinator snapshots binding, collaborator, identity, payout,
consent/finality, Core, and validator commitments. The payout snapshot occurs
before consent/finality. Identity consumes signer replay; consent/finality
creates `ECONOMICS_CONSENT_RECORD_DOMAIN` and emits
`ArtistEconomicsConsentRecorded`. Payout remains read-only in this recipe.

#### Every Other Multi-Domain Row

All remaining rows are expressed by the same exact structure. Each row mirrors
all 18 frozen fields, binds every current-state fact to its typed snapshot set,
binds every replay fact to one or more globally owned replay surfaces, resolves
primary/secondary record modes and owners, resolves every named event to one
emitter, lists dependency snapshots, and enumerates every owner action.

The checker rejects a missing source fact, missing record/event/replay
binding, owner split, unowned surface, wrong action order, peer-domain write,
unvalidated caller/coordinator/revision, incomplete source requirement, or
recipe hash drift.

The current-state inventory has eleven typed surfaces: seven artist semantic
owners plus read-only Core, Governance V2, Finality, and import-continuity
surfaces. Every semicolon-delimited current-state clause names one or more of
those exact surfaces, and every surface must be present in the operation's
snapshot recipe. External providers remain read-only and do not become artist
semantic owners.

### Immutable External Provider And Platform-Role Binding

The coordinator and Registry bind five typed external providers. Each provider
record requires an exact nonzero candidate address, deployed runtime
`EXTCODEHASH`, interface ID, required marker, schema hash, and derived binding
hash under `6529STREAM_ARTIST_EXTERNAL_PROVIDER_BINDING_V2`. The binding hash
orders `chain_id`, provider ID, address, runtime codehash, interface ID, marker
hash, and schema hash. No mutable lookup or successful-call inference may
replace those pins.

| Provider | Recipe snapshot(s) | Existing authority | Remaining hard stop |
| --- | --- | --- | --- |
| `StreamRoleRegistry` | the three `authority:role_registry:ROLE_*` surfaces | candidate manifest `streamAdminsOrGovernance` executor, then its sealed `IStreamGovernanceExecutor.systemManifestBootstrapState()` `roleRegistry` and `roleRegistryCodeHash`; `IStreamRoleRegistry` `0xd77ee305`; `ADR0004_TIMELOCK_ROLE_LAYER`; `STREAM_ROLE_MUTATION_STATE_V1` | candidate executor identity, sealed role-registry identity, and binding hash absent |
| `StreamCore` | `external:core` | candidate manifest `core` / `STREAM_CORE`; `IStreamCore` `0x93740d3a`; permanent-Core interface artifact | candidate identity and accepted artist-fact read subset absent |
| Governance V2 | `external:governance` | candidate manifest `streamAdminsOrGovernance` / `GOVERNANCE_LAYER`; `IStreamGovernedParameterAuthority` `0xd9f8d48c`; governed-parameter ABI schema | candidate identity and exact artist action scope/old/new bindings absent |
| `StreamArtworkFinalityRegistry` | `external:finality` | candidate manifest `artworkFinalityRegistry` / `ARTWORK_FINALITY_REGISTRY`; `IStreamArtworkFinalityRegistry` `0x47291ea1`; finality supplement | candidate identity absent; operation 22 keeps its finality stop |
| predecessor/import continuity | `external:import_continuity` | future accepted artist-suite composite manifest address/codehash fields | no accepted continuity interface, marker, or schema exists |

The checked-in `system-manifest-payload-vector.json` is only a synthetic target
ABI-lock fixture. Its addresses and runtime hashes are not candidate evidence
and cannot populate these null pins. Every provider therefore remains
`implementable: false`; exact manifest field names and accepted authorities are
bound now, while candidate values remain null and implementation-blocking.

The role provider exposes exactly three authority snapshots:
`ROLE_ARTIST_REGISTRY_ADMIN`, `ROLE_ATTRIBUTION_ARBITER`, and
`ROLE_ARTIST_DORMANCY_ADMIN`. Each snapshot binds the exact keccak role ID,
`hasRole(bytes32,address)`, `roleMutationState(bytes32)`, and the authenticated
original caller. The seven frozen operations that name one of those roles must
include its exact authority snapshot. Staged-governance recipes also retain the
separate Governance V2 snapshot; implementation remains blocked until an
accepted interface demonstrates how the governance action's role-authorizing
actor is carried as that authenticated original caller.

### Global Record Ownership

The matrix assigns all 37 named record domains exactly once:

- Binding owns `ARTIST_BINDING_DOMAIN` and
  `BINDING_REFUSAL_RECORD_DOMAIN`.
- Acceptance owns `ACCEPTANCE_RECORD_DOMAIN`.
- Payout owns `PAYOUT_DESIGNATION_RECORD_DOMAIN`.
- Attribution owns attestation, attribution claim/repudiation/dispute, and
  platform-works declaration/claim/correction records.
- Consent/finality owns sanction, policy/economics/sale/content consent,
  royalty/content freeze, recovery approval, and content ratification records.
- Identity owns artist identity/import, authorization revocation, delegation,
  directive, estate, guardian, contest/recovery/revision, rotation, standing,
  steward, succession, and unavailability records.

An `EXISTING:<domain>` binding is a typed read of that domain owner, never a
record re-creation by the consuming operation.

### Global Event Ownership

All 54 source events have one emitter. In particular:

- `ArtistIdentityRegistered` is emitted only by Identity;
- `ArtistBindingProposed` only by Binding;
- `ArtistBindingAccepted` and `CollaboratorAccepted` only by Acceptance;
- `CollaboratorIdentityProposed` only by Collaborator;
- `ArtistAttributionStateChanged`, attribution, attestation, and
  platform-works events only by Attribution;
- payout events only by Payout;
- consent, sanction, freeze, ratification, and recovery-approval events only by
  Consent/finality; and
- identity, delegation, guardian, rotation, succession, estate, dormancy,
  import, standing, and authorization events only by Identity.

The coordinator and ArchiveV2 emit no normative semantic event.

### Global Replay Ownership

Replay facts are normalized into globally owned surfaces. Identity solely owns
artist/collaborator/account/authority nonce allocation, signed-digest
revocation, delegation-use accounting, standing retirement, and target
authorization revocation. Acceptance solely owns shared acceptance-record
uniqueness. Binding, collaborator, attribution, payout, consent/finality, and
identity own their remaining domain-specific keys and chains.

The checker requires every semicolon-delimited frozen replay fact to resolve to
at least one listed replay surface and rejects any different owner for the same
surface.

### Slim Registry

`StreamArtistRegistry` remains the registered Core pointer and an immutable
typed directory/facade. It routes only to the exact
`StreamArtistOperationCoordinator` entrypoint for the requested operation and
pins the coordinator, ArchiveV2, seven owners, interfaces, runtime codehashes,
schema hashes, binding hashes, and recipe set.

Registry owns no artist semantic state, record, replay state, current/latest
answer, recipe, or normative event. It has no generic routing or upgrade path.

### ArchiveV2 Is Evidence Only

The former payload-store deployment position becomes
`StreamArtistArchiveV2`. ArchiveV2 is append-only evidence storage and owns
no semantic record. It cannot authorize, consume replay, answer current/latest
state, replace an owner root/revision/tip, or emit a normative semantic event.

Archive append failures revert the complete coordinator recipe. Archive
evidence cannot substitute for an owner snapshot or the composite manifest.

### Sole Signature And Record-Family Authority

`StreamArtistIdentityAuthority` is the only artist implementation of
`IStreamRecordFamilyAuthorityProvider`.

It is also the sole semantic owner of artist signature policy,
`ARTIST_ERC1271_VERIFY_GAS` revision binding, signature-execution admission,
validation-result acceptance, and signature replay facts.

`StreamArtistRegistryValidatorBase._validateSignerProof` is a stateless
validation callsite only. Its reserved inventory operation is exactly
`staticcall`, with exact syntax
`address(<signer>).staticcall{gas: context.erc1271GasCap}`. It uses the
Registry-authenticated cap and owns no policy, GGP state, record, replay state,
current state, revision, or event. Callsite location does not transfer semantic
ownership from Identity.

The frozen source context still names `StreamArtistRegistry` as the technical
GGP host. This successor preserves that field as source evidence but does not
silently treat it as semantic ownership: Registry may authenticate the exact
request context, while Identity is the sole selected policy/state owner. The
future accepted interface freeze must reconcile the host/read mechanics before
implementation. The matrix marks that reconciliation incomplete and therefore
does not authorize source.

### Construction, Export, Import, And Continuity

The immutable constructor DAG is:

1. precompute Registry, Coordinator, ArchiveV2, seven owner addresses, and five
   external provider bindings plus runtime codehash/interface/marker/schema/
   binding pins;
2. deploy Registry with expected immutable owner/provider entries and no calls
   to absent dependencies;
3. deploy ArchiveV2 bound to Registry and predicted Coordinator;
4. deploy seven owners bound to Registry, Coordinator, ArchiveV2, and no
   peer-read capability;
5. deploy Coordinator bound to Registry, ArchiveV2, seven owners, five external
   providers, and 57 recipe hashes; and
6. verify the ordered composite manifest before any use.

There is no initializer, setter, proxy, or rebinding path.

Each owner exports only its domain ID, revision, state root, and record-chain
tip. The composite manifest also binds Registry, Coordinator, ArchiveV2,
  runtime codehashes, interface IDs, markers, schema hashes, binding hashes,
  ordered external-provider identities, and ordered recipe hashes. Each owner
  imports only its own exact constructor commitment or frozen domain import
  operation. Coordinator and Archive own no semantic import.

## Alternatives Considered

### A. One Owner Per Operation

Rejected. Shared records, replay surfaces, events, and state transitions can be
split merely because two operations touch the same domain.

### B. Monolithic Registry Owner

Rejected. It collapses all storage, replay, event, and rollback boundaries into
one contract and recreates the rejected bottleneck.

### C. Direct Module-to-Module Calls

Rejected. Cross-domain read cycles and nested mutation become difficult to
reason about, and original-caller/revision commitments can drift between calls.

### D. Generic Router Or Delegatecall Coordinator

Rejected. Generic selector/calldata routes or delegatecall create an unbounded
execution/upgrade surface and destroy isolated storage ownership.

### E. Off-Chain Or Archive-Based Composition

Rejected. Off-chain sequencing is not atomic; ArchiveV2 evidence is not
operative state and cannot authorize or resolve replay.

### F. Selected Global Owners Plus Stateless Typed Coordinator

Selected. It makes underlying ownership global and singular while preserving
atomic multi-domain operations through finite immutable recipes.

## Security Impact

Expected benefits:

- one global owner for every state, record, replay, and event surface;
- no peer-owner writes or reads;
- exact original-caller, coordinator, recipe, and revision validation;
- all-or-nothing EVM rollback across composite operations;
- no generic routing, delegatecall, proxy, or mutable recipe;
- exact source-row, dependency, stop, and source-requirement binding;
- exact immutable provider and original-caller platform-role snapshot binding;
- explicit payout-before-consent ordering for operation 15;
- sole acceptance-record ownership for operations 2 and 7; and
- cryptographically pinned schema and source freeze.

Residual and deferred risks:

- exact Solidity interfaces, storage layouts, errors, events, recipe calldata,
  state-root encodings, and manifest encoding remain unfrozen;
- the chosen fact-to-snapshot and replay-surface mappings require independent
  semantic review;
- gas and EIP-150 behavior for 57 recipes is unmeasured;
- source and #669 inventory row remain absent;
- candidate provider identities are absent and the Core, Governance V2, and
  import-continuity interfaces still require explicit reconciliation;
- no Foundry, invariant, fuzz, static-analysis, or audit evidence exists for
  this proposed topology; and
- Codex Security remains deferred.

## Release Impact

This packet adds no Solidity, ABI, contract catalog, deployment profile,
candidate address, deployment plan, release artifact, generated tail, live
evidence, or status advancement. The machine-readable architecture remains
under `docs/architecture/`, outside the generated release-artifact tree.

A future implementation must classify and regenerate its own ABI, bytecode,
catalog, profile, policy, manifest, checksum, and release-tail effects.

## Test Plan

Required packet checks:

```text
python scripts/check_artist_semantic_owner_matrix.py
python scripts/test_artist_semantic_owner_matrix.py
python -m py_compile scripts/check_artist_semantic_owner_matrix.py scripts/test_artist_semantic_owner_matrix.py
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
python scripts/check_changelog.py
codex-diff-check
```

The hostile corpus includes:

- duplicate/unsafe JSON;
- schema digest tamper;
- coupled schema-and-matrix tamper;
- schema/status/maturity/critical-field drift;
- all 18 source-row fields;
- unresolved current/replay/record/event fields;
- split or duplicate owners;
- cross-domain writes;
- missing coordinator/caller/revision validation;
- generic routing and delegatecall;
- peer-module reads;
- operations 1, 2, 6, 7, 13, and 15 recipe regressions;
- base/effective implementation-stop drift;
- false source/implementation claims;
- #669 boundary drift or authority capture;
- provider address/codehash/interface/marker/schema/binding drift;
- missing or misbound platform-role/original-caller snapshots;
- independent literal Proposed/pre-audit/no-authority posture;
- Archive replay authority; and
- readiness overclaim.

## Rollout Plan

1. Independently review this ADR and exact matrix.
2. Keep the ADR Proposed until explicit acceptance.
3. Keep #669's canonical stateless validator reservation exact and its source/
   inventory row absent until architecture and interface acceptance.
4. Freeze interfaces, storage, events/errors, recipes, snapshot commitments,
   replay keys, and manifest encoding in a separate accepted packet.
5. Implement Registry, Coordinator, ArchiveV2, Acceptance, and the other six
   owners under canonical post-#716 paths.
6. Add focused Foundry tests, invariants, fuzzing, static analysis, and ordinary
   independent review.
7. Bind a candidate and regenerate release evidence only through a separately
   authorized release packet.
8. Obtain external audit evidence before any readiness claim.

## Non-Goals

This ADR does not:

- implement Solidity;
- reopen or modify issue #670;
- edit #669-owned files;
- add catalog/profile/deployment/candidate/live evidence;
- refresh shared generated release artifacts;
- authorize custody, signing, governance, or live-chain action;
- claim audit, public-beta, testnet, or production readiness; or
- authorize generic routing, delegatecall, proxying, or upgrades.

## Accepted Risks

If accepted, maintainers accept seven owner deployments, 57 immutable
coordinator recipes, exact revision/commitment snapshotting, and composite
manifest/rollback complexity. They do not accept shared ownership, peer-domain
writes, cyclic module reads, generic dispatch, mutable recipes, Archive
authority, or validator-callsite semantic ownership.
