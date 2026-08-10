# Artist Operation Coordinator Source-Acceptance Gate

- Status: Proposed implementation gate; Coordinator source is **not authorized**
- Date: 2026-08-10
- Evaluated base: `8e856252eae2ca9afa2685b71b4cd22f900753de`
- Base tree: `dce685c061c72bfb9741e639bb109e789a7837a0`
- Maturity: pre-audit, candidate-unbound, undeployed
- Scope: dependency decision for the bounded `StreamArtistOperationCoordinator`
  source slice after the ArchiveV2 and RegistryV2 source publications

## Decision

Do not implement `StreamArtistOperationCoordinator` from the current packet.
The current Proposed evidence fixes operation identity, semantic ownership,
snapshot membership, and owner-call order for review, but it does not freeze
the typed call surfaces needed to compile or review a Coordinator without
inventing protocol behavior.

This document is the smallest honest acceptance packet supported by the
present evidence: it accepts only the Coordinator source NO-GO and the exact
requirements for the next packet. It does not accept an ABI by omission.

The next dependency-ordered change must be an exact typed protocol and storage
acceptance packet covering Coordinator ingress, owner snapshots, mutations and
storage, replay keys, provider reads, recipe commitments, normative owner
events, ArchiveV2 evidence encoding, the composite manifest, native-value
semantics, errors, and the operation lock. A typed-interface packet alone never
authorizes source. Only after every interface, storage, replay, event, manifest,
value and hostile-drift requirement in this gate is independently accepted may
`interface_and_storage_freeze_complete` change or a Coordinator source slice be
reconsidered.

This gate does not change
[ADR 0023](../adr/0023-modular-artist-authority-domain-ownership.md), the
[semantic-owner matrix](artist-semantic-owner-matrix-v2.json), or its
[schema](artist-semantic-owner-matrix-v2.schema.json). Those remain the
normative Proposed architecture surfaces.

## Evidence Baseline

The decision was made against these exact merged-main bytes:

| Surface | SHA-256 |
| --- | --- |
| ADR 0023 | `b3a7f322518aeb63638572486292be511f67202e09db58471ac867eb3fa8c113` |
| Semantic-owner matrix | `bc4b55c68c504ee7d74965d7fa0d1edbe6de816e567e076442781b81232320a2` |
| Matrix schema | `b242c5480ecdf8e4aa57dc02d76fd8cd81631298eeda0b96cbba9b036d72b473` |
| Matrix checker | `75be5171655556711282de41a3feb909b0a9fdded45c565f66597d984427152b` |
| ArchiveV2 implementation | `1228ef5451258927b8141a842c437d4738f41fb66bbfff57e805919252552778` |
| ArchiveV2 interface | `2e488c13527383b63864eb484203e2fed6349def941043ca9435cc728a29a80e` |
| RegistryV2 implementation | `038560c0a8811b7ed4a816d011813d9c529e16091bd646f153c63390578a2430` |
| RegistryV2 interface | `6b56d095a7abdde99967c18ebef1c089ef91e9cff1c5477c2c1cc5d601059a54` |

The matrix contains exactly 57 unique recipe identities and 57 unique facade
entrypoint names. It fixes one to five ordered owner actions per operation and
one to seven ordered snapshot identifiers per operation. All 57 operation rows
still have `source_present=false` and `implementation_authorized=false`.
Operation 22 additionally retains
`FINALITY_DEPENDENCY_ABI_AND_ADR0020_NOT_FROZEN`.

The recipe object has exactly these seven fields:

1. `recipe_id`;
2. `facade_entrypoint`;
3. `generic_dispatch`;
4. `original_caller_authenticated`;
5. `snapshot_ids`;
6. `actions`; and
7. `atomicity`.

It has no parameter schema, calldata encoding, return schema, selector,
interface identifier, recipe-hash preimage, evidence encoding, or versioning
field. Treating a recipe name as an ABI would therefore add unreviewed
semantics.

## Frozen Facts That Source Must Preserve

A future acceptance packet and implementation must preserve all of the
following without reinterpretation:

- the 57 source rows and all 18 fields in each row;
- the 57 recipe identities and facade entrypoint names;
- the exact snapshot identifiers and their order;
- the exact owner actions and their order;
- one authoritative owner for every state, record, replay, and normative event
  surface;
- original-caller authentication by every recipe and validation by each
  mutating owner;
- snapshot collection before the first semantic mutation;
- EVM-wide rollback when any owner, provider, validation, pin, revision,
  event, or ArchiveV2 append fails;
- ArchiveV2 as evidence-only and RegistryV2 as directory-only;
- five immutable typed external providers and seven isolated owner pins;
- the issue #669 validator reservation as a stateless, non-authoritative
  `staticcall` boundary;
- for each of the 57 recipes, every corresponding Registry-facade entrypoint
  and Coordinator entrypoint as `external nonpayable` (never `payable`, `view`,
  or `pure`), with nonzero `msg.value` rejected by ABI dispatch before any
  owner, provider, Archive, state, event, or evidence effect;
- no payable fallback or receive function, so empty calldata and unknown
  selectors revert rather than accept native value;
- every typed owner, provider, validator, and ArchiveV2 call with zero native
  value and no value-forwarding path; and
- no generic selector/calldata routing, fallback dispatch, `delegatecall`,
  `callcode`, proxy, upgrade, initializer, or mutable rebinding.

## Blocking Acceptance Surfaces

Each row below is source-blocking. A future packet must select one exact option,
bind its encoding, and add hostile tests before Coordinator Solidity is
eligible.

| Surface | Fixed in the current Proposed packet | Missing exact decision |
| --- | --- | --- |
| Entrypoint ABI | 57 names and recipe identities | Parameter types/order, structs, returns, selectors, interface ID, schema and marker |
| Registry ingress | Matrix says typed Registry facade forwards the original caller | Current RegistryV2 intentionally has no calls or operation entrypoints; direct-caller versus Registry-forwarded ingress and caller authentication are unreconciled |
| Original caller | Every recipe and owner must authenticate it | Exact derivation, forwarding field, anti-spoof rule, and relation to `msg.sender` |
| Owner snapshots | Seven domain IDs and snapshot order | Typed read functions, exact return fields, revision width, commitment/state-root/tip encodings, and failure rules |
| Owner mutations | Ordered owner/action identities and write surfaces | One or more exact typed functions per owner, calldata, return or acknowledgement, expected recipe/revision checks, and custom errors |
| Owner storage | One sole owner per semantic state, record, replay, revision, root and tip | Exact storage structs, mappings, key/value widths, packing/order, append-only fields, revision/root/tip update formulas, and storage-layout drift receipt for each owner |
| Replay keys | 64 replay surfaces and their sole owners | Exact domain-separated preimages, field types/order, allocation and consumption rules, uniqueness scope, supersession/retirement behavior, and rollback on conflict |
| Normative owner events | 54 event names and one emitter domain each | Complete event ABI, parameter types/order, indexed fields, topic commitments, emission point, and proof that failures roll every event back |
| Provider reads | Provider identities, pins and required snapshot IDs | Exact Core artist-fact subset, Governance action/actor/old/new encoding, import-continuity interface/marker/schema, operation-22 finality reconciliation, and fail-closed return decoding |
| Role authority | Three exact roles and `hasRole`/`roleMutationState` names | Exact returned revision/state type and how staged Governance supplies the authenticated actor |
| Signer validation | Identity owns policy; #669 reserves one stateless callsite | Registry technical GGP-host read mechanics, exact validation request/result ABI, cap revision, and Identity acceptance protocol |
| Recipe commitment | RegistryV2 binds a nonzero `recipeSetHash` | Per-recipe hash domain and fields, canonical encoding, ordered set-hash formula, and version transition rule |
| Archive evidence | Exact ArchiveV2 append function and atomicity requirement | Evidence ID, version allocation, payload schema, owner snapshot/action/result commitments, one-versus-many append rule, and idempotent-retry handling |
| Composite manifest | ADR 0023 fixes the required field inventory | Exact Solidity/ABI types, order, canonical encoding, hash/root formula, ordered owner/provider/recipe projections, null/absent rules, and verification failure behavior |
| Operation lock | Only a typed operation reentrancy lock is permitted | Solidity 0.8.19-compatible mechanism, lock key/granularity, nested-call behavior, reset semantics, and proof that it cannot become semantic or replay state |
| Construction | Immutable Registry/Archive/owners/providers/recipes and an acyclic predicted-address DAG | Exact Coordinator constructor fields, binding-hash preimage, codehash/interface validation timing, and behavior when owner/provider code is absent or mismatched |
| Errors | Coordinator emits no normative semantic event | Complete Coordinator/owner/shared-protocol custom-error ABI and whether any explicitly non-normative Coordinator diagnostic event is permitted |
| Native value | No artist recipe requires custody or payment | For each of all 57 recipes, every corresponding Registry-facade and Coordinator entrypoint is `external nonpayable`; fallback and receive are absent; nonzero `msg.value` rejects before effects; every owner/provider/validator/Archive call carries zero value; forced balance is ignored and never forwarded |
| Gas and call discipline | One transaction and all-or-nothing rollback | Exact gas forwarding/reserve policy, EIP-150 treatment, return-data bounds, provider/owner call order, and reentrancy hostile cases |

Candidate addresses and runtime code hashes are deployment evidence, not source
ABI facts. The future interface packet may keep those values null while still
freezing how immutable values are supplied and checked. It must not fabricate a
deployment or mark an absent dependency usable.

## Dependency-Order Options

### A. Implement Coordinator source immediately

Rejected. This would invent the missing ABI and encoding decisions, and it
would contradict `interface_and_storage_freeze_complete=false` and
`implementation_authorized=false`.

### B. Freeze only owner and provider interfaces first

Safe but incomplete. It does not settle Registry ingress, original-caller
authentication, recipe hashes, ArchiveV2 evidence, or the lock. Those omissions
would still prevent a complete Coordinator review.

### C. Freeze a unified typed protocol and storage packet before any new source

Selected. The packet should contain the smallest shared types and exact
Coordinator/owner/provider call surfaces necessary to encode every matrix row,
plus the owner storage layouts, replay preimages/rules, normative owner event
ABI, canonical hash/evidence/composite-manifest formulas, native-value policy,
complete errors and hostile drift tests required by ADR 0023. Owner
implementations may remain absent and unauthorized. This preserves dependency
order without coupling the seven owners into one implementation change.

### D. Add a partial Coordinator shell

Rejected. A constructor-only or always-reverting shell would still create an
interface/codehash artifact that integrations could mistake for the complete
57-recipe Coordinator, without exercising atomicity or owner/provider
semantics.

## Required Future Packet Shape

The unified typed protocol and storage packet is eligible for review only when
it includes:

1. exact Solidity-compatible shared types and all 57 Coordinator function
   signatures;
2. selector and ERC-165/interface-ID recomputation from those signatures;
3. exact owner snapshot and mutation interfaces for all seven domains;
4. exact storage layouts for all seven owners, including every semantic record,
   replay key, revision, state root and record-chain tip field and update rule;
5. exact domain-separated replay-key preimages, types/order, allocation,
   consumption, uniqueness, supersession/retirement and rollback rules;
6. complete normative owner event ABI with indexed-field and emission-order
   commitments for all 54 events;
7. exact read-only provider subsets, including import continuity and the
   Governance original-actor rule;
8. canonical recipe-hash and ordered recipe-set-hash preimages;
9. canonical ArchiveV2 evidence ID, version, and payload encodings;
10. exact composite-manifest types, field order, encoding, hash/root formula,
    ordered projections, null/absent rules and verification behavior;
11. the complete Coordinator/owner/shared-protocol custom-error ABI;
12. the Solidity 0.8.19-compatible operation-lock design;
13. exact constructor and binding-hash preimages with absent-code and mismatch
   behavior;
14. a row-by-row machine mapping from every one of the 57 matrix recipes to its
   entrypoint parameters, snapshots, ordered owner calls, and evidence append;
15. a native-value matrix proving, for each of all 57 recipes, every
    corresponding Registry-facade entrypoint and Coordinator entrypoint is
    `external nonpayable` with ABI `stateMutability` equal to `nonpayable`,
    fallback/receive are absent, nonzero `msg.value` reverts before any effect,
    and every typed call to an owner, provider, validator or ArchiveV2 carries
    zero value; and
16. hostile checks for selector/field/order drift, storage-layout drift,
    replay-preimage/key drift, event ABI/indexing/emission drift,
    composite-manifest encoding/order drift, caller spoofing, partial mutation,
    stale snapshots, provider return ambiguity, reentrancy, evidence conflicts,
    gas/return-data bounds, payable drift, fallback/receive introduction,
    nonzero-value acceptance, value forwarding, forced-balance influence, and
    forbidden generic dispatch; and
17. an explicit independent acceptance record that keeps owner sources,
    deployments, candidates, audit credit, and readiness out of scope.

The packet must fail closed if even one operation lacks an exact entrypoint,
mutability, native-value rule, snapshot, owner action, storage/replay mapping,
normative event, error, evidence encoding, or composite-manifest projection.
Operation 22 must remain implementation-blocked until its existing finality
stop is separately removed by accepted evidence. Typed interfaces, selectors
and interface IDs alone are never sufficient to authorize source.

## Source Gate

Until that future packet is accepted:

- `smart-contracts/domains/artist/StreamArtistOperationCoordinator.sol` must
  remain absent;
- no Coordinator interface may be presented as accepted or implementation
  ready;
- the seven semantic owner sources and stateless validator must remain absent;
- all 57 operations must remain `source_present=false` and
  `implementation_authorized=false`;
- the matrix-wide interface/storage freeze and implementation authorization
  flags must remain false;
- ArchiveV2 and RegistryV2 bytes must remain unchanged; and
- catalog, profile, deployment, candidate, readiness, generated release-tail,
  and issue #669-owned surfaces must not move in this bounded slice.

Even after a typed-interface packet exists, Coordinator source remains
ineligible and `interface_and_storage_freeze_complete` must remain false until
the exact owner storage, replay, normative event, error, composite-manifest,
native-value and hostile-drift requirements above are independently accepted.

## Validation For This Gate

This documentation-only decision should be reviewed with:

```text
python scripts/test_artist_semantic_owner_matrix.py
python scripts/check_artist_semantic_owner_matrix.py
python scripts/test_solidity_source_layout.py
python scripts/check_solidity_source_layout.py
forge test --match-path test/StreamArtistArchiveV2.t.sol -vvv
forge test --match-path test/StreamArtistRegistryV2.t.sol -vvv
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
python scripts/check_changelog.py
codex-diff-check
```

Passing these checks confirms only that the already reviewed ArchiveV2,
RegistryV2, matrix, source-absence posture, links, and repository hygiene remain
intact. It is not Coordinator implementation evidence.

## Non-Goals

This gate does not:

- define or accept Coordinator Solidity, selectors, ABI, interface ID, bytecode,
  storage, events, or errors;
- implement an owner, provider adapter, validator, Registry facade route, or
  ArchiveV2 change;
- change the 57 operation semantics or implementation stops;
- update contracts catalogs, deployment profiles, manifests, address books,
  candidates, release artifacts, checksums, or shared readiness documents;
- modify issue #669-owned inventory, checker, or tests;
- perform a deployment, broadcast, live-chain read/write, custody/signer action,
  or external governance action; or
- claim audit, public-beta, testnet, production, or deployment readiness.
