# ADR 0021 Candidate Packet: Revenue-Resolver Validation Adapter V1

## Status

**Proposed. Not approved. Not frozen. Not implementation-authorizing.**

This document is a candidate normative interface and transcript packet for
[ADR 0021](0021-immutable-revenue-resolver-validation-adapter.md). ADR 0021
accepts the adapter architecture but expressly requires a separately reviewed
and approved packet before Solidity implementation begins. Adding, reviewing,
or merging this Proposed document does not satisfy that gate.

No contract, interface, test, deployment, generated artifact, release artifact,
or readiness claim may treat the candidates below as accepted until a separate
change:

1. resolves every **BLOCKING REVIEW DECISION** in this document;
2. replaces this status with an explicit approval and identifies the exact
   freeze commit;
3. includes independently recomputed selector, ERC-165, ABI-length, digest, and
   golden-vector evidence; and
4. preserves ADR 0021's independent implementation, size, deployment, and
   release gates.

The protocol remains pre-audit and not production-ready. This packet does not
authorize deployment.

## Purpose and source boundary

This packet turns ADR 0021's architecture into one reviewable V1 candidate:

- one stateless `StreamRevenueResolverValidationAdapter`;
- one resolver that remains the only state owner and authority boundary;
- nine fixed-width operation entries;
- three fixed-width identity probes;
- one 29-word result transcript for every operation entry;
- a closed `STATICCALL` graph; and
- exact canonical-ABI, digest, failure, and size rules.

The candidate was derived from the accepted ADR, the revenue specification,
current interfaces, and the reversible issue #670 prototype. The prototype is
implementation evidence only. Its stale three-argument mint snapshot and stale
`mintManager()` probe are not silently made normative here.

The packet extracts only dependency observation and pure validation. The
following stay in the resolver:

- primary-template creation and canonicalization;
- primary-template assignment and template-storage hashing;
- split-profile materialization and its stateful factory `CALL`;
- Governance V2 authentication and `currentAction()` verification;
- owner or other resolver-side caller authentication;
- active mint-manager authentication;
- mint-ledger operation-root-used proof and replay status;
- Core prepared-mint proof;
- artist authorization semantics;
- nonce, freeze, snapshot, continuity, assignment, and counter state;
- every state transition and protocol event;
- global and revenue-class freezes; and
- the storage-only `royaltyReceiverAndBps` marketplace path.

## Candidate architecture invariants

If this packet is later approved, all of these invariants are indivisible:

1. The resolver is the sole Registry V2 module and the sole Permanent
   `ROYALTY_RESOLVER` pointer target.
2. The adapter is implementation-private dependency inventory ID `38`, never a
   Registry V2 row, module type, Core pointer, proxy, or authority.
3. The adapter has no mutable storage, owner, role, payable entry, fallback,
   `receive`, value transfer, `CALL`, `DELEGATECALL`, `CALLCODE`,
   `SELFDESTRUCT`, `CREATE`, or `CREATE2`.
4. The adapter can reach only the `STATICCALL` sites enumerated below.
5. The resolver pins the adapter address, deployed runtime `EXTCODEHASH`,
   interface ID, marker, schema, dependency binding, and dependency facts.
6. Before every operation call, the resolver checks the live adapter
   `EXTCODEHASH`.
7. The resolver acquires its non-reentrant lock and completes resolver-side
   authentication before calling the adapter.
8. Except for the transient lock, no resolver state changes and no event emits
   before the transcript is fully validated.
9. No external call occurs after the first economic state write.
10. A successful adapter result is validation data, not authorization.
11. `royaltyReceiverAndBps(address,uint256,uint256,uint256,bool)` never reaches
    the adapter or any other external contract.
12. Every call forwards available gas with EIP-150 retention. This packet
    creates no gas cap and no new Governed Gas Parameter.

## Candidate fixed constants

All hashes in this table are Keccak-256 of the exact ASCII string shown.

| Name | Exact preimage or rule | Candidate value |
| --- | --- | --- |
| `ADAPTER_MARKER_V1` | `6529STREAM_REVENUE_RESOLVER_VALIDATION_ADAPTER_V1` | `0xc712a93e70e790d800e47a24f6b52711d5b4395ef334c52f9b4abf4dd437415a` |
| `ADAPTER_SCHEMA_V1` | integer `1`, ABI type `uint16` | `0x0000000000000000000000000000000000000000000000000000000000000001` |
| `RESULT_MAGIC_V1` | `6529STREAM_REVENUE_RESOLVER_VALIDATION_RESULT_MAGIC_V1` | `0x7770c0c5bddd997a2a1f8ff01c213b8e89c2088fa67ccb78fbe9c96b0a7da33e` |
| `DEPENDENCY_DOMAIN_V1` | `6529STREAM_REVENUE_RESOLVER_VALIDATION_DEPENDENCIES_V1` | `0xd92182181887d178da7ee1abb2501ab0f688e60ef591ebafbaa3218060956923` |
| `INTENT_DOMAIN_V1` | `6529STREAM_REVENUE_RESOLVER_VALIDATION_INTENT_V1` | `0x01314df67d01eb4bb1a15954fc7090d6489ddd26cfb6c297255d1387050bc910` |
| `OBSERVATIONS_DOMAIN_V1` | `6529STREAM_REVENUE_RESOLVER_VALIDATION_OBSERVATIONS_V1` | `0x15c7c294be65e05ed6b7e91f04f32c3b15741b6bc8136a89c896ba10565f7f06` |
| `RESULT_DOMAIN_V1` | `6529STREAM_REVENUE_RESOLVER_VALIDATION_RESULT_V1` | `0x0b4e09de5081f9799c82b57041daa86221771cfce5affb5ec1acd8a097e7c4d6` |
| `PRIMARY_GOVERNANCE_SCOPE_DOMAIN_V1` | `6529STREAM_PRIMARY_ASSIGNMENT_GOVERNANCE_SCOPE_V1` | `0x687c6d8adadba2bc1b8de2358ea03e1130761d5737088a13df4a59b4d39748e2` |
| `PRIMARY_GOVERNANCE_STATE_DOMAIN_V1` | `6529STREAM_PRIMARY_ASSIGNMENT_GOVERNANCE_STATE_V1` | `0x25ba62ff5b8b8b88b3baf4831ddfa7d3aa91d21d892b5dd542f3b46961281d00` |
| `PRIMARY_FREEZE_GOVERNANCE_STATE_DOMAIN_V1` | `6529STREAM_PRIMARY_ASSIGNMENT_FREEZE_GOVERNANCE_STATE_V1` | `0xa7ae283a0a9e89f333bce42286c8d8c287f49f60fc947a8fccf979f9cf2d44ab` |
| `SNAPSHOT_PROOF_DOMAIN_V1` | `6529STREAM_REVENUE_SNAPSHOT_PROOF_V1` | `0x312c37a50a09a644909db1b0571aed097f0285b6305d3eee8e65dcb0b4983fa7` |
| `ROYALTY_POLICY_DOMAIN` | `6529STREAM_ROYALTY_POLICY_V1` | `0x672cda40f3f95b129db3b9262cfb581cbe26ea0e95cb09b958ca58ebf62ba54a` |
| `ROYALTY_REVENUE_CLASS` | `ROYALTY_ERC2981` | `0x5cb0c76a63239382404dc61f136cb498c99d198325ed6d4148d768d151e0b2f8` |
| `CORE_READ_INTERFACE_V1` | XOR of the two Core read selectors below | `0xb1fc0266` |
| `FACTORY_READ_INTERFACE_V1` | XOR of the five factory read selectors below | `0x0200c7a8` |
| `ARTIST_READ_INTERFACE_V1` | XOR of the two artist read selectors below | `0xed34ed02` |
| `WALLET_READ_INTERFACE_V1` | `profileId()` selector | `0x08386eba` |
| `CORE_MARKER_V1` | `6529STREAM_PERMANENT_CORE_V1` | `0x81e029b140303578efbc73ea15873907b328621ccb126b647102a661b5d597e9` |
| `FACTORY_MARKER_V1` | `6529STREAM_SPLIT_FACTORY_V1` | `0x74ac5c045f6661fc3e2736d16ef223cd6c45f11d8f8fa82184d557b190df220c` |
| `ARTIST_MARKER_V1` | `STREAM_ARTIST_REGISTRY` | `0x2a9dd22d7225a4cc60f5a64aa47d28addaea744116b324a22149faadac0b090a` |
| `MINT_MANAGER_POINTER_ID` | Permanent Core pointer ID | `0x136326f089f522351128a5fb79275bd12b2d84fe5bb50d5e46c9f5508d6df7e2` |
| `MINT_MANAGER_INTERFACE_ID` | compiler-derived `type(IStreamMintManager).interfaceId` | `0xb4074ed7` |
| `IERC165_INTERFACE_ID` | `supportsInterface(bytes4)` | `0x01ffc9a7` |
| invalid ERC-165 probe | required false probe | `0xffffffff` |
| adapter interface ID | XOR of the 12 packet selectors below | `0xb4165b1a` |
| snapshot event topic | `RevenueRoyaltySnapshotRecorded(uint16,uint256,uint256,bytes32,bytes32,bytes32,bytes32)` | `0x9759cccc3dc5dfb9a69774dba31ee80379f23bc686a951a46bdfbdb95227ea63` |
| result words | fixed | `29` |
| result bytes | `29 * 32` | `928` |
| maximum royalty bps | fixed | `1_000` |
| resolver runtime maximum | EIP-170 less 2,000 bytes | `22_576` |
| adapter runtime maximum | EIP-170 less 2,000 bytes | `22_576` |
| resolver full-initcode maximum | EIP-3860 less 2,000 bytes | `47_152` |
| adapter full-initcode maximum | EIP-3860 less 2,000 bytes | `47_152` |

The candidate scope values are default `0`, collection `1`, and token `2`.
The candidate assignment-type values are profile `1` and template `2`. The
candidate freeze-mode values are none `0`, exact `1`, and inherited `2`.

The Core, factory, and artist marker/schema treatment remains a blocking
decision because those dependencies do not all expose the ADR-required live
marker/schema probe surface. The table pins the candidate constants; it does
not approve using codehash-bound constants instead of probes.

## Shared request tuples

Every operation entry takes these two static tuples first. They contain no
dynamic member, pointer, offset, array, string, or `bytes`.

### `DependenciesV1`: 19 ABI words

| Word | ABI type | Field |
| ---: | --- | --- |
| 1 | `address` | `core` |
| 2 | `bytes32` | `coreCodehash` |
| 3 | `bytes4` | `coreReadInterfaceId` |
| 4 | `bytes32` | `coreMarker` |
| 5 | `uint16` | `coreSchema` |
| 6 | `address` | `splitFactory` |
| 7 | `bytes32` | `splitFactoryCodehash` |
| 8 | `bytes4` | `splitFactoryReadInterfaceId` |
| 9 | `bytes32` | `splitFactoryMarker` |
| 10 | `uint16` | `splitFactorySchema` |
| 11 | `address` | `artistRegistry` |
| 12 | `bytes32` | `artistRegistryCodehash` |
| 13 | `bytes4` | `artistRegistryReadInterfaceId` |
| 14 | `bytes32` | `artistRegistryMarker` |
| 15 | `uint16` | `artistRegistrySchema` |
| 16 | `address` | `assetPolicyRegistry` |
| 17 | `bytes32` | `assetPolicyRegistryCodehash` |
| 18 | `bytes32` | `allowedSplitWalletRuntimeCodehash` |
| 19 | `bytes32` | `dependencyBindingHash` |

Its canonical tuple type is:

```text
(address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32)
```

The adapter compares all 19 words with its immutables. The resolver computes
word 19 independently. No request may substitute a dependency, interface,
marker, schema, codehash, or wallet runtime.

### `IntentHeaderV1`: 18 ABI words

| Word | ABI type | Field |
| ---: | --- | --- |
| 1 | `uint256` | `chainId` |
| 2 | `address` | `resolver` |
| 3 | `address` | `adapter` |
| 4 | `bytes32` | `adapterCodehash` |
| 5 | `bytes4` | `adapterInterfaceId` |
| 6 | `bytes32` | `adapterMarker` |
| 7 | `uint16` | `adapterSchema` |
| 8 | `bytes4` | `resolverEntrySelector` |
| 9 | `address` | `authenticatedActor` |
| 10 | `bytes32` | `governanceActionId` |
| 11 | `uint8` | `governanceActionClass` |
| 12 | `bytes32` | `governanceScopeHash` |
| 13 | `bytes32` | `governanceOldStateHash` |
| 14 | `bytes32` | `governanceNewStateHash` |
| 15 | `bytes32` | `currentFrozenEconomicStateHash` |
| 16 | `bytes32` | `inheritedFrozenEconomicStateHash` |
| 17 | `bytes32` | `continuityManifestHash` |
| 18 | `bytes32` | `claimedFullIntentDigest` |

Its canonical tuple type is:

```text
(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)
```

Header word 18 is never included in its own preimage. The adapter recomputes
the intent from header words 1 through 17 and rejects unless the result equals
word 18.

For informational hashing, `authenticatedActor` and all five Governance words
are zero. Default-scope primary set, replace, and clear calls require the
staged Governance V2 executor as `authenticatedActor`; all five Governance
words are exact, and those calls use action class
`DELAYED_LOOSENING (1)`. Collection- and token-scope primary set, replace, and
clear calls use the current resolver owner as `authenticatedActor` and zero
Governance words; Core identity and artist economics consent are additional,
mandatory checks described below. O4 freeze authority is separately pinned:
every permanent freeze and every default freeze uses the Governance V2
executor and exact action context, while an advertised-loosening,
non-permanent collection/token exact freeze uses the current resolver owner
and zero Governance words. Governance V2 royalty writes use exact nonzero
Governance words where required. Artist freeze and mint snapshot use zero
Governance words and an `authenticatedActor` equal respectively to the relayer
or active manager proven by the resolver.

## Candidate adapter ABI

Every operation returns `bytes32[29]`. The marker and binding getters return
`bytes32`; the schema getter returns `uint16`; `supportsInterface` returns
`bool`. Return types do not affect selectors.

The following are the exact canonical signatures and independently recomputed
selectors:

```text
0xb3573c09 revenueResolverValidationAdapterMarkerV1()
0x94bf44c4 revenueResolverValidationAdapterSchemaV1()
0x371b62f3 dependencyBindingHash()
0xaa3a3b3e computePrimaryAssignmentHashV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bool)
0x6396e4ca validateSetPrimaryAssignmentV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,uint256,bytes32,bool,bool,uint256,uint256)
0xae8de4e2 validateClearPrimaryAssignmentV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint256,bool,uint256,uint256)
0xa76cbd87 validateFreezePrimaryAssignmentV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bool,bytes32,uint256,bool,uint8,bool,uint8,bool,uint8,bool,uint8,bool,uint8,bool,uint256,uint256,uint256)
0x7e18b9d4 validateSetRoyaltyAssignmentV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),uint8,uint256,bytes32,uint16,bool,bytes32,uint256,bytes32,uint256,uint8,uint8,uint256,uint256)
0x02c57ac5 validateClearRoyaltyAssignmentV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),uint8,uint256,uint256,bytes32,uint256,uint8,uint8,uint256,uint256)
0x5e1f43f2 validateFreezeRoyaltyAssignmentV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),uint8,uint256,uint8,bool,uint256,bytes32,bytes32,bytes32,uint256,uint256,uint256,uint256)
0x600e740d validateFreezeArtistRoyaltyAssignmentV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),uint256,bytes32,uint256,bytes32,bytes32,uint256,uint256,uint256)
0x2664335b validateSnapshotTokenRoyaltyAtMintV1((address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes32,bytes32),(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),uint256,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint256,bytes32,address,uint16,bytes32,bytes32,bytes32,bytes32,bool,bytes32,bytes32,bytes32,uint256,bytes32,bytes32,bytes32,uint256,uint256,uint8,uint8)
```

The adapter interface ID is:

```text
0xb3573c09 ^ 0x94bf44c4 ^ 0x371b62f3 ^ 0xaa3a3b3e
^ 0x6396e4ca ^ 0xae8de4e2 ^ 0xa76cbd87 ^ 0x7e18b9d4
^ 0x02c57ac5 ^ 0x5e1f43f2 ^ 0x600e740d ^ 0x2664335b
= 0xb4165b1a
```

Inherited `supportsInterface(bytes4)` is excluded from that XOR.

The corresponding candidate resolver entry selectors committed in header word
8 are:

| Adapter operation | Resolver signature | Selector |
| --- | --- | --- |
| compute primary profile hash | `primaryAssignmentHash(bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bool)` | `0x1e39dcdd` |
| set primary profile through O2 | `setPrimaryProfileAssignment(bytes32,uint8,uint256,bytes32,bytes32)` | `0xa68c7f3e` |
| set primary template through O2 | `setPrimaryTemplateAssignment(bytes32,uint8,uint256,bytes32,bytes32)` | `0x829477ad` |
| clear primary | `clearPrimaryAssignment(bytes32,uint8,uint256)` | `0xccd963df` |
| freeze primary | `freezePrimaryAssignment(bytes32,uint8,uint256)` | `0x14f0e30d` |
| set royalty | `setRoyaltyAssignment(uint8,uint256,bytes32,uint16,bool,bytes32)` | `0xc903cea7` |
| clear royalty | `clearRoyaltyAssignment(uint8,uint256)` | `0x4dab731a` |
| freeze royalty | `freezeRoyaltyAssignment(uint8,uint256,uint8,bool)` | `0x31e2dba8` |
| artist freeze | `freezeArtistRoyaltyAssignment(uint256,bytes32)` | `0x7dba2ad8` |
| mint snapshot candidate | `snapshotTokenRoyaltyAtMint(uint256,uint256,bytes32,bytes32,bytes32,bytes32)` | `0xc8323dfa` |

The prototype's stale three-argument snapshot selector `0x9697a717` is not in
the candidate packet.

## Nine operation tuples and exact calldata lengths

`D` below means the exact 19-word `DependenciesV1` tuple. `H` means the exact
18-word `IntentHeaderV1` tuple. Field order is normative if this candidate is
approved.

### O1. `ComputePrimaryAssignmentHashOpV1`

```text
(bytes32 revenueClass,
 uint8 scope,
 uint256 scopeId,
 uint8 assignmentType,
 bytes32 profileId,
 bytes32 templateId,
 bytes32 policyHash,
 bool frozen)
```

Candidate constraints: `assignmentType == 1`, `profileId != 0`, and
`templateId == 0`. This is a profile-only informational computation. Template
hashing remains resolver-local because the adapter cannot read resolver
template storage and this tuple carries no template entries or metadata hash.

Total calldata is exactly `4 + 32 * (19 + 18 + 8) = 1_444` bytes.

### O2. `SetPrimaryAssignmentOpV1`

```text
(bytes32 revenueClass,
 uint8 scope,
 uint256 scopeId,
 uint8 nextAssignmentType,
 bytes32 nextProfileId,
 bytes32 nextTemplateId,
 bytes32 nextPointerEntriesHash,
 bytes32 nextPointerMetadataURIHash,
 bytes32 nextPolicyHash,
 uint256 collectionId,
 bytes32 currentAssignmentHash,
 bool currentConfigured,
 bool currentFrozen,
 uint256 mutableDescendantsDefault,
 uint256 mutableDescendantsForCollection)
```

This entry covers create and replace for both profile and template assignments.
`revenueClass` and `nextPolicyHash` are nonzero. Scope is canonical and
`scopeId == 0` if and only if scope is default.

For a profile assignment, `nextAssignmentType == 1`,
`nextProfileId != 0`, `nextTemplateId == 0`, and the two pointer hashes must
equal the factory observations. For a template assignment,
`nextAssignmentType == 2`, `nextProfileId == 0`, `nextTemplateId != 0`, and
the two pointer hashes must equal the resolver's immutable stored template
entry and metadata hashes. The template route makes no factory or wallet call.

Create requires `currentConfigured == false`,
`currentAssignmentHash == bytes32(0)`, and `currentFrozen == false`. Replace
requires `currentConfigured == true`, a nonzero exact current hash, and
`currentFrozen == false`. The resolver binds both ancestor counters in the
intent and updates them from old configured/frozen state to new
configured/frozen state; the adapter never owns a counter.

For collection scope, `collectionId == scopeId != 0` and the requested ID must
not exceed Core's observed `lastAllocatedCollectionId`. For token scope, Core
must return `mappingExists == true` and an authoritative mapped collection
equal to `collectionId`; retained burned-token identity and same-transaction
prepared identity are both valid for O2/O3 exactly as they are for ordinary
minted identity. Default scope requires `collectionId == 0`.

Total calldata is exactly `4 + 32 * (19 + 18 + 15) = 1_668` bytes.

### O3. `ClearPrimaryAssignmentOpV1`

```text
(bytes32 revenueClass,
 uint8 scope,
 uint256 scopeId,
 uint8 currentAssignmentType,
 bytes32 currentProfileId,
 bytes32 currentTemplateId,
 bytes32 currentPointerEntriesHash,
 bytes32 currentPointerMetadataURIHash,
 bytes32 currentPolicyHash,
 bytes32 currentAssignmentHash,
 uint256 collectionId,
 bool currentFrozen,
 uint256 mutableDescendantsDefault,
 uint256 mutableDescendantsForCollection)
```

This entry covers profile and template clears. A profile input has
`currentAssignmentType == 1`, a nonzero profile ID, zero template ID, and
pointer hashes equal to the factory observations. A template input has
`currentAssignmentType == 2`, zero profile ID, a nonzero template ID, and
pointer hashes equal to immutable resolver template storage; no factory or
wallet call occurs for that route. Both routes require a nonzero policy and
current assignment hash and `currentFrozen == false`.

The adapter recomputes the current assignment hash, validates authoritative
Core identity for collection/token scope, and observes artist economics
consent over the exact resulting per-key hash `bytes32(0)`. The resolver binds
both current ancestor counters and performs the exact decrements only after
transcript acceptance.

Total calldata is exactly `4 + 32 * (19 + 18 + 14) = 1_636` bytes.

### Primary set/replace/clear authorization matrix

O2 and O3 cover the complete default/collection/token by profile/template
matrix. `set` means O2 with `currentConfigured == false`; `replace` means O2
with `currentConfigured == true`.

| Scope/type | Resolver-host checks before adapter | Adapter sequence | Resulting consent |
| --- | --- | --- | --- |
| default/profile | exact staged Governance V2 action, current state, freeze state, counters | `P(next/currentProfileId)` | no artist call because there is no collection |
| default/template | exact staged Governance V2 action, immutable template context, current state, freeze state, counters | no nested dependency call | no artist call because there is no collection |
| collection/profile | current resolver owner, scope identity request, current state, freeze state, counters | Core `lastAllocatedCollectionId` -> `P(next/currentProfileId)` -> artist `requireEconomicsConsent` | O2 uses computed next assignment hash; O3 uses zero |
| collection/template | current resolver owner, immutable template context, scope identity request, current state, freeze state, counters | Core `lastAllocatedCollectionId` -> artist `requireEconomicsConsent` | O2 uses computed next assignment hash; O3 uses zero |
| token/profile | current resolver owner, token and claimed collection request, current state, inherited freeze state, counters | Core `tokenCollectionIdentity` -> `P(next/currentProfileId)` -> artist `requireEconomicsConsent` | O2 uses computed next assignment hash; O3 uses zero |
| token/template | current resolver owner, immutable template context, token and claimed collection request, current state, inherited freeze state, counters | Core `tokenCollectionIdentity` -> artist `requireEconomicsConsent` | O2 uses computed next assignment hash; O3 uses zero |

The resolver-host order for a default-scope O2/O3 call is:

1. acquire the lock and require `msg.sender == governanceAuthority`;
2. load current assignment, freeze, template, and counter state;
3. perform one exact `currentAction()` read and validate executing, nonzero
   action ID, class `DELAYED_LOOSENING (1)`, and exact scope/old/new hashes;
4. commit the five non-boolean action payload words in `H`, require the
   uncommitted `executing` word to be canonical true, and commit the complete
   old/new assignment state and counters in `H` and the operation tuple;
5. call the adapter, which performs `P` only for profile type;
6. validate the transcript;
7. repeat `currentAction()` and require all six words byte-for-byte equal to
   the committed pre-call values;
8. recheck current assignment, freeze, template, and counters; and
9. update assignment and counters, then emit events.

The resolver-host order for collection/token O2/O3 is the same except that it
requires `msg.sender == owner()`, all Governance header words are zero, and
the adapter performs the exact Core and artist calls in the table. An
artist-registry call is mandatory for every collection/token set, replace, or
clear; the registry itself decides whether the collection is artist-bound or
platform works. The resolver never skips the call based on a locally inferred
artist mode.

The O2 artist call is exactly
`requireEconomicsConsent(collectionId,revenueClass,scope,scopeId,nextAssignmentHash)`.
The O3 artist call has the same first four arguments and
`bytes32(0)` as the exact resulting per-key assignment hash. A revert or any
nonempty returndata fails before state mutation.

Default primary Governance commitments are:

```solidity
primaryScopeHash = keccak256(
    abi.encode(
        PRIMARY_GOVERNANCE_SCOPE_DOMAIN_V1,
        block.chainid,
        address(resolver),
        boundCore,
        revenueClass,
        uint8(0),
        uint256(0),
        resolverEntrySelector
    )
);

primaryStateHash = keccak256(
    abi.encode(
        PRIMARY_GOVERNANCE_STATE_DOMAIN_V1,
        block.chainid,
        address(resolver),
        boundCore,
        revenueClass,
        scope,
        scopeId,
        configured,
        assignmentType,
        profileId,
        templateId,
        pointerEntriesHash,
        pointerMetadataURIHash,
        policyHash,
        assignmentHash,
        frozen,
        mutableDescendantsDefault,
        mutableDescendantsForCollection
    )
);
```

The old and new Governance hashes use the same exact state preimage with old
and new values respectively. Clear encodes the new assignment fields and
hashes as zero and `configured == false`. Create/replace uses O2's adapter-
computed next hash. Any Governance, Core, profile, artist, transcript, or
post-call recheck failure reverts before assignment, counter, continuity, or
event mutation.

Counter effects follow the formal revenue invariant:

- default set/replace/clear changes no ancestor counter;
- collection create increments the default counter once; mutable replace
  changes neither counter; clear decrements the default counter once;
- token create increments default and authoritative-collection counters once;
  mutable replace changes neither; clear decrements both once; and
- a frozen old assignment cannot be replaced or cleared.

### O4. `FreezePrimaryAssignmentOpV1`

```text
(bytes32 revenueClass,
 uint8 scope,
 uint256 scopeId,
 uint8 currentAssignmentType,
 bytes32 currentProfileId,
 bytes32 currentTemplateId,
 bytes32 currentPointerEntriesHash,
 bytes32 currentPointerMetadataURIHash,
 bytes32 currentAssignmentPolicyHash,
 bytes32 currentLooseningTermsHash,
 bool currentLooseningAdvertised,
 bytes32 currentAssignmentHash,
 uint256 collectionId,
 bool currentConfigured,
 uint8 currentFreezeMode,
 bool currentPermanent,
 uint8 inheritedFreezeMode,
 bool inheritedPermanent,
 uint8 revenueClassFreezeMode,
 bool revenueClassPermanent,
 uint8 allRevenueFreezeMode,
 bool allRevenuePermanent,
 uint8 requestedFreezeMode,
 bool requestedPermanent,
 uint256 mutableDescendantsAtScope,
 uint256 mutableDescendantsDefault,
 uint256 mutableDescendantsForCollection)
```

O4 covers the complete default/collection/token by profile/template exact-
freeze matrix. `currentConfigured` is true; `currentFreezeMode == NONE (0)`;
`currentPermanent == false`; and the current assignment hash is nonzero and
must recompute exactly with `frozen == false`. `requestedFreezeMode` is fixed
to `EXACT (1)`. `requestedPermanent` must equal
`!currentLooseningAdvertised`: a key that advertised no loosening becomes
terminal when frozen, while a key carrying the canonical nonzero loosening
commitment may later use only the separately governed loosening route.
`currentLooseningAdvertised == (currentLooseningTermsHash != bytes32(0))`,
and `currentAssignmentPolicyHash` must be zero for the no-loosening branch or
the canonical domain-separated loosening-policy commitment for the advertised
branch.

Profile type requires assignment type `1`, nonzero profile ID, zero template
ID, pointer hashes equal the exact `P(profileId)` observations, and the full
seven-call profile bundle. Template type requires assignment type `2`, zero
profile ID, nonzero template ID, pointer hashes byte-equal to immutable
resolver template storage, and no factory/wallet call. The adapter recomputes
both the current per-key assignment hash and the next hash with the identical
pointer and assignment-policy context and only the canonical frozen bit
changed from false to true.

Authority and identity are exact:

| O4 route | Resolver-host authority | Adapter sequence |
| --- | --- | --- |
| default/profile | staged Governance V2; `TERMINAL_FREEZE (2)` when permanent, otherwise `IMMEDIATE_TIGHTENING (0)`; exact pre/post `currentAction()` | `P(currentProfileId)` |
| default/template | same staged Governance V2 rule and immutable template-state commitment | no nested dependency call |
| collection/profile | `TERMINAL_FREEZE (2)` Governance V2 when permanent, otherwise current resolver owner with zero Governance words | Core `lastAllocatedCollectionId` -> `P(currentProfileId)` |
| collection/template | same authority split and immutable template-state commitment | Core `lastAllocatedCollectionId` |
| token/profile | `TERMINAL_FREEZE (2)` Governance V2 when permanent, otherwise current resolver owner with zero Governance words | Core `tokenCollectionIdentity` -> `P(currentProfileId)` |
| token/template | same authority split and immutable template-state commitment | Core `tokenCollectionIdentity` |

Governance-routed O4 uses the same exact `primaryScopeHash` formula as
O2/O3 and these exact old/new state commitments:

```solidity
primaryFreezeStateHash = keccak256(
    abi.encode(
        PRIMARY_FREEZE_GOVERNANCE_STATE_DOMAIN_V1,
        block.chainid,
        address(resolver),
        boundCore,
        revenueClass,
        scope,
        scopeId,
        currentConfigured,
        currentAssignmentType,
        currentProfileId,
        currentTemplateId,
        currentPointerEntriesHash,
        currentPointerMetadataURIHash,
        currentAssignmentPolicyHash,
        currentLooseningTermsHash,
        currentLooseningAdvertised,
        assignmentHash,
        collectionId,
        freezeMode,
        permanent,
        inheritedFreezeMode,
        inheritedPermanent,
        revenueClassFreezeMode,
        revenueClassPermanent,
        allRevenueFreezeMode,
        allRevenuePermanent,
        mutableDescendantsAtScope,
        mutableDescendantsDefault,
        mutableDescendantsForCollection
    )
);
```

The old Governance hash substitutes `currentAssignmentHash`,
`currentFreezeMode`, `currentPermanent`, and pre-freeze counters. The new hash
substitutes adapter-derived `nextAssignmentHash`, `requestedFreezeMode`,
`requestedPermanent`, and the exact post-freeze counters. Every other word is
byte-identical. The action class is `TERMINAL_FREEZE (2)` exactly when
`requestedPermanent` is true and `IMMEDIATE_TIGHTENING (0)` otherwise.

Collection identity requires `scopeId == collectionId != 0` and
`scopeId <= coreLastCollectionId`. Token identity requires a canonical
existing mapping to `collectionId`; ordinary minted, retained burned, and
same-transaction prepared identities are accepted. An exact freeze is a
tightening operation and requires no artist economics-consent call.

All eight raw freeze words are consumed, not decorative:
`currentFreezeMode/currentPermanent` describe this key;
`inheritedFreezeMode/inheritedPermanent` describe its nearest active
ancestor; and the revenue-class and all-revenue pairs describe the broader
freeze layers. They must match the two header freeze-state hashes and resolver
storage before and after the adapter call. Existing broader freezes do not
make a consistent exact freeze invalid, but no field may be omitted or
silently normalized. Governance routes observe `currentAction()` before the
adapter and require the exact six-word return again afterward. Owner routes
recheck owner, assignment, template, every freeze word, and counters after the
adapter. Any mismatch fails before the freeze write, continuity append,
counter delta, or event.

The counter transition compares old configured/frozen state with new
configured/frozen state exactly:

- default exact freeze changes no ancestor counter;
- collection exact freeze decrements
  `mutableDescendantsDefault` once and leaves
  `mutableDescendantsForCollection` and `mutableDescendantsAtScope`
  unchanged;
- token exact freeze decrements `mutableDescendantsDefault` and
  `mutableDescendantsForCollection` once each and leaves
  `mutableDescendantsAtScope == 0` unchanged; and
- an absent, already frozen, or otherwise inconsistent current key rejects
  instead of changing a counter.

These rules complete the adjacent set/clear arithmetic: mutable collection or
token create increments the same ancestors once, mutable replace changes no
counter, mutable clear decrements the same ancestors once, and exact freeze
performs the decrements above. Lower-scope descendants remain independently
counted; exact-freezing a default or collection key never bulk-freezes or
decrements descendants.

After transcript and state rechecks, the resolver applies only those deltas,
sets the exact key's freeze mode/permanence, stores the adapter-derived frozen
assignment hash, appends frozen continuity once, and emits the existing
`PrimaryAssignmentFrozenEvent` with the exact old/new hashes and authenticated
actor. It returns the frozen per-key assignment hash. No external call follows
the first write.

Total calldata is exactly `4 + 32 * (19 + 18 + 27) = 2_052` bytes.

### O5. `SetRoyaltyAssignmentOpV1`

```text
(uint8 scope,
 uint256 scopeId,
 bytes32 profileId,
 uint16 royaltyBps,
 bool looseningAdvertised,
 bytes32 looseningTermsHash,
 uint256 collectionId,
 bytes32 currentAssignmentHash,
 uint256 currentRoyaltyAnswer,
 uint8 revenueClassFreeze,
 uint8 allRevenueFreeze,
 uint256 defaultRoyaltyAnswer,
 uint256 collectionRoyaltyAnswer)
```

Candidate constraints include `profileId != 0`, `1 <= royaltyBps <= 1_000`,
and `looseningAdvertised == (looseningTermsHash != bytes32(0))`. The resolver
supplies all current state words and compares them with its storage before and
after the call. `collectionRoyaltyAnswer` is zero for default and collection
scope; for token scope it is the current answer at `collectionId`.

Total calldata is exactly `4 + 32 * (19 + 18 + 13) = 1_604` bytes.

### O6. `ClearRoyaltyAssignmentOpV1`

```text
(uint8 scope,
 uint256 scopeId,
 uint256 collectionId,
 bytes32 currentAssignmentHash,
 uint256 currentRoyaltyAnswer,
 uint8 revenueClassFreeze,
 uint8 allRevenueFreeze,
 uint256 defaultRoyaltyAnswer,
 uint256 collectionRoyaltyAnswer)
```

The current answer must be configured and mutable. The adapter validates Core
scope identity and the zero-assignment artist economics observation where a
collection is present. Governance remains resolver-side.

Total calldata is exactly `4 + 32 * (19 + 18 + 9) = 1_476` bytes.

### O7. `FreezeRoyaltyAssignmentOpV1`

```text
(uint8 scope,
 uint256 scopeId,
 uint8 freezeMode,
 bool permanent,
 uint256 collectionId,
 bytes32 profileId,
 bytes32 assignmentPolicyHash,
 bytes32 currentAssignmentHash,
 uint256 currentRoyaltyAnswer,
 uint256 mutableDescendantsAtScope,
 uint256 mutableDescendantsDefault,
 uint256 mutableDescendantsForCollection)
```

`freezeMode` is exact `1` or inherited `2`. An inherited freeze requires
`mutableDescendantsAtScope == 0`. The three counter words bind the test and the
resolver-owned decrement without giving the adapter counter authority.

Total calldata is exactly `4 + 32 * (19 + 18 + 12) = 1_572` bytes.

### O8. `FreezeArtistRoyaltyAssignmentOpV1`

```text
(uint256 collectionId,
 bytes32 expectedAssignmentHash,
 uint256 currentRoyaltyAnswer,
 bytes32 profileId,
 bytes32 assignmentPolicyHash,
 uint256 mutableDescendantsAtScope,
 uint256 mutableDescendantsDefault,
 uint256 mutableDescendantsForCollection)
```

The route is always collection scope, exact, and permanent. The adapter
physically observes the artist freeze record. The resolver authenticates the
relay context, requires the expected hash to equal current storage, owns all
counter changes, and writes the freeze.

Total calldata is exactly `1_444` bytes.

### O9. `SnapshotTokenRoyaltyAtMintOpV1`

```text
(uint256 tokenId,
 uint256 collectionId,
 bytes32 operationRoot,
 bytes32 operationId,
 bytes32 snapshotProofHash,
 bytes32 revenueClass,
 bytes32 expectedRoyaltyAssignmentHash,
 uint8 sourceScope,
 uint256 sourceScopeId,
 bytes32 sourceProfileId,
 address sourceWallet,
 uint16 sourceRoyaltyBps,
 bytes32 sourceAssignmentHash,
 bytes32 sourceAssignmentPolicyHash,
 bytes32 sourceRoyaltyAssignmentHash,
 bytes32 sourceLooseningTermsHash,
 bool sourceLooseningAdvertised,
 bytes32 recordedSourceAssignmentHash,
 bytes32 recordedSourceAssignmentPolicyHash,
 bytes32 recordedSourceRoyaltyAssignmentHash,
 uint256 currentTokenRoyaltyAnswer,
 bytes32 currentTokenAssignmentHash,
 bytes32 recordedSnapshotOperationRoot,
 bytes32 recordedSnapshotOperationId,
 uint256 mutableDescendantsDefault,
 uint256 mutableDescendantsForCollection,
 uint8 revenueClassFreeze,
 uint8 allRevenueFreeze)
```

`expectedRoyaltyAssignmentHash` has exactly its normative
[RSR-ROYALTY-HASH] meaning: it is the canonical resolved
`royaltyAssignmentHash` of the collection/default source assignment under
`ROYALTY_POLICY_DOMAIN`. It is not the source per-key `assignmentHash`, not
the assignment's loosening-metadata `assignmentPolicyHash`, and not the
derived token per-key `nextAssignmentHash`. The resolver return is likewise
the canonical token-context `royaltyAssignmentHash`, not a per-key assignment
hash.

The candidate requires nonzero token, collection, operation root, operation
ID, snapshot proof, and source profile; `revenueClass` equals
`ROYALTY_REVENUE_CLASS`; `sourceScope` is default or collection; the source
wallet and bps match the packed source answer authenticated resolver-side;
all source metadata matches resolver storage; and Core reports a canonical
existing, unburned token mapping to the requested collection. The resolver,
not the adapter, proves the active manager, used operation root, and exact
Core prepared record.

Default source requires `sourceScopeId == 0`; collection source requires
`sourceScopeId == collectionId`. The current token key must not be blocked by
the revenue-class or all-revenue freeze inputs. The adapter recomputes the
source per-key hash, metadata policy hash, resolved source royalty hash,
exact-permanent token answer, derived token per-key hash, and final canonical
token royalty hash independently from the tuple.

The four distinct commitments are pinned as follows:

1. `sourceAssignmentHash` is the canonical per-key hash of the resolved
   collection/default source under Assignment Semantics, including its actual
   frozen bit.
2. `sourceAssignmentPolicyHash` is only the immutable advertised-loosening
   metadata commitment inside that per-key hash. It is zero exactly when
   `sourceLooseningAdvertised == false`; otherwise it is the canonical
   domain-separated commitment to nonzero `sourceLooseningTermsHash`.
3. `sourceRoyaltyAssignmentHash` is the canonical resolved source hash and
   must equal `expectedRoyaltyAssignmentHash`:

   ```solidity
   sourceRoyaltyAssignmentHash = keccak256(
       abi.encode(
           ROYALTY_POLICY_DOMAIN,
           h.chainId,
           h.resolver,
           sourceScope == uint8(1) ? collectionId : uint256(0),
           uint256(0),
           sourceProfileId,
           sourceWallet,
           sourceRoyaltyBps,
           sourceAssignmentHash
       )
   );
   ```

4. `nextAssignmentHash` is the newly derived token-scope per-key assignment
   hash. It copies the source profile pointer and immutable
   `sourceAssignmentPolicyHash`, binds token scope and `tokenId`, and sets the
   canonical frozen bit true. The exact artist call consumes this
   `nextAssignmentHash`, because artist economics consent is over the
   resulting per-key assignment hash. It does not consume either canonical
   resolved royalty hash.

The adapter also returns the resolver hook's canonical result in result word
29:

```solidity
tokenRoyaltyAssignmentHash = keccak256(
    abi.encode(
        ROYALTY_POLICY_DOMAIN,
        h.chainId,
        h.resolver,
        collectionId,
        tokenId,
        sourceProfileId,
        sourceWallet,
        sourceRoyaltyBps,
        nextAssignmentHash
    )
);
```

On create, all three recorded source-provenance fields are zero because they
report existing resolver state. After validation, the resolver stores the
exact source per-key hash, metadata policy hash, and canonical source royalty
hash separately; no field is aliased or relabeled.

The resolver computes the exact proof commitment:

```solidity
snapshotProofHash = keccak256(
    abi.encode(
        SNAPSHOT_PROOF_DOMAIN_V1,
        block.chainid,
        address(resolver),
        boundCore,
        MINT_MANAGER_POINTER_ID,
        pointer.target,
        pointer.codeHash,
        pointer.frozen,
        pointer.moduleType,
        pointer.interfaceId,
        pointer.registry,
        pointer.registryStatus,
        pointer.moduleManifestHash,
        pointer.deploymentManifestHash,
        pointer.revision,
        extcodehash(pointer.target),
        mintLedger,
        extcodehash(mintLedger),
        operationRoot,
        true,
        tokenId,
        true,
        operationId,
        collectionId
    )
);
```

The first `true` commits the canonical ledger
`isManagerOperationRootUsed(pointer.target,operationRoot)` result. The second
commits `preparedMint(tokenId).exists`; the following two words commit its
exact operation and collection identities. The pointer target must equal both
`msg.sender` and `H.authenticatedActor`; its live codehash must equal
`pointer.codeHash`; `pointer.moduleType == MINT_MANAGER_POINTER_ID`;
`pointer.interfaceId == MINT_MANAGER_INTERFACE_ID`; and
`pointer.registryStatus == ACTIVE (1)`. The manager-returned ledger and its
live codehash must equal resolver-pinned constructor identities.

The resolver performs the first complete host proof before classifying
snapshot state, so create, no-op, and mismatch paths all enforce
active-manager authorization and the exact ledger/Core operation identity.
The snapshot state machine is then exact:

1. **Create.** This branch exists only when
   `recordedSourceAssignmentHash`,
   `recordedSourceAssignmentPolicyHash`,
   `recordedSourceRoyaltyAssignmentHash`, `currentTokenRoyaltyAnswer`,
   `currentTokenAssignmentHash`, `recordedSnapshotOperationRoot`, and
   `recordedSnapshotOperationId` are all zero. The resolver performs the full
   host proof before O9. The adapter then executes Core
   `tokenCollectionIdentity` -> `P(sourceProfileId)` -> artist
   `requireEconomicsConsent` over the computed exact-permanent token
   assignment, with exact arguments
   `(collectionId,revenueClass,uint8(2),tokenId,nextAssignmentHash)`. After
   accepting the transcript, the resolver repeats every
   pointer, manager, ledger, and prepared-mint proof call and requires an
   identical `snapshotProofHash`; rechecks that snapshot state is still
   absent and both counters are unchanged; then writes the exact-permanent
   token answer, token assignment metadata, authoritative token collection,
   the three distinct source-provenance hashes, operation root, and operation
   ID, and appends frozen continuity exactly once. Because the token assignment
   is born exact and permanent, neither mutable-descendant counter changes.
   The resolver returns `tokenRoyaltyAssignmentHash`.
2. **Idempotent no-op.** This branch exists only when the three stored source
   hashes equal the supplied/recomputed source assignment, assignment-policy,
   and expected canonical royalty hashes; the stored operation root and ID
   equal the request; the token answer and per-key assignment hash form the
   complete expected exact-permanent snapshot; and every remaining snapshot
   word is self-consistent. The resolver performs one complete host proof,
   makes no adapter call, changes no snapshot, counter, or continuity state,
   emits no event, and returns the recomputed canonical
   `tokenRoyaltyAssignmentHash`.
3. **Mismatch or partial existing state.** Any other nonempty or partial state
   rejects after that one host proof and before an adapter call. This includes
   a different expected source royalty hash, same expected hash with different
   source per-key or metadata hashes, same expected hash with a different root
   or operation ID, mismatched token answer/assignment, missing stored proof
   identity, or any partially populated snapshot. It performs no write and
   emits no event.

The create route emits the existing token-scope `RevenueAssignmentSet`, then
the existing token-scope `RevenueAssignmentFrozen`, then exactly:

```solidity
event RevenueRoyaltySnapshotRecorded(
    uint16 schemaVersion,
    uint256 indexed tokenId,
    uint256 indexed collectionId,
    bytes32 indexed operationId,
    bytes32 operationRoot,
    bytes32 sourceRoyaltyAssignmentHash,
    bytes32 tokenRoyaltyAssignmentHash
);
```

Its full topic is
`0x9759cccc3dc5dfb9a69774dba31ee80379f23bc686a951a46bdfbdb95227ea63`;
the three indexed values are token ID, collection ID, and operation ID, and
the 128 data bytes are schema version, operation root, canonical source
royalty-assignment hash, and canonical token royalty-assignment hash. The
no-op and every rejecting branch emit nothing.

Total calldata is exactly `4 + 32 * (19 + 18 + 28) = 2_084` bytes.

## Fixed 29-word result

Every operation entry returns exactly `bytes32[29]`, or 928 bytes:

| Word | Name | Canonical interpretation |
| ---: | --- | --- |
| 1 | `magic` | `bytes32`, equals `RESULT_MAGIC_V1` |
| 2 | `intent` | `bytes32`, equals the recomputed full intent |
| 3 | `observationsDigest` | `bytes32` |
| 4 | `resultDigest` | `bytes32` |
| 5 | `dependencyBinding` | `bytes32` |
| 6 | `observedCoreCodehash` | `bytes32` |
| 7 | `observedFactoryCodehash` | `bytes32` |
| 8 | `observedArtistCodehash` | `bytes32` |
| 9 | `observedAssetPolicyCodehash` | `bytes32` |
| 10 | `collectionId` | `uint256` word |
| 11 | `coreLastCollectionId` | `uint256` word |
| 12 | `coreMappingExists` | canonical `bool` word |
| 13 | `coreMappedCollectionId` | `uint256` word |
| 14 | `coreCollectionSerial` | `uint256` word |
| 15 | `coreBurned` | canonical `bool` word |
| 16 | `profileOrTemplateId` | `bytes32` |
| 17 | `profileExists` | canonical `bool` word |
| 18 | `splitWalletExists` | canonical `bool` word |
| 19 | `wallet` | canonical `address` word |
| 20 | `walletCodehash` | `bytes32` |
| 21 | `walletProfileId` | `bytes32` |
| 22 | `pointerEntriesHash` | `bytes32` |
| 23 | `pointerMetadataURIHash` | `bytes32` |
| 24 | `artistObservation` | canonical `bool` word |
| 25 | `assignmentPolicyHash` | `bytes32` |
| 26 | `currentAssignmentHash` | `bytes32`; snapshot uses current token assignment hash |
| 27 | `nextAssignmentHash` | `bytes32` |
| 28 | `packedRoyaltyAnswer` | canonical `uint256` word |
| 29 | `resolvedRoyaltyAssignmentHash` | `bytes32`; populated only by O9 create |

Words 5 through 9 are populated and must match the immutable dependency tuple
for every entry, even when that entry does not call a particular dependency.
They are live `EXTCODEHASH` observations, not authorization.

All fields not explicitly populated by the following table are exactly zero:

| Operation | Additional populated result words |
| --- | --- |
| O1 compute primary profile hash | 16-23; 25 is requested policy hash; 27 is computed profile assignment hash |
| O2 set primary | scope-specific 10-15; profile type populates 16-23, while template type populates 16 and 22-23 only; 24 is one only for collection/token artist consent; 25 is next policy hash; 26 is current assignment hash; 27 is next assignment hash |
| O3 clear primary | scope-specific 10-15; profile type populates 16-23, while template type populates 16 and 22-23 only; 24 is one only for collection/token zero-assignment artist consent; 25 is current policy hash; 26 is current assignment hash |
| O4 freeze primary | scope-specific 10-15; profile type populates 16-23, while template type populates 16 and 22-23 only; 25 is current assignment-policy hash; 26 is current assignment hash; 27 is exact-frozen assignment hash |
| O5 set royalty | scope-specific 10-15; 16-23; 24 is one only when economics consent was required and succeeded; 25 is computed assignment policy hash; 26 is current hash; 27 is next hash; 28 is next packed answer |
| O6 clear royalty | scope-specific 10-15; 24 is one only when zero-assignment economics consent was required and succeeded; 26 is current hash |
| O7 freeze royalty | 10 echoes authenticated collection ID; 16-23; 25 is assignment policy hash; 26 is current hash; 27 is frozen hash; 28 is frozen packed answer |
| O8 artist freeze | 10 is collection ID; 16-23; 24 is one; 25 is assignment policy hash; 26 is expected/current hash; 27 is frozen hash; 28 is exact-permanent packed answer |
| O9 snapshot create | 10 and 12-15 are the Core token observation; 16-23 are the source profile observation; 24 is one; 25 is source metadata `assignmentPolicyHash`; 26 is the zero current token per-key assignment hash; 27 is derived exact-frozen token per-key `nextAssignmentHash`; 28 is exact-permanent token answer; 29 is canonical token-context `royaltyAssignmentHash` returned by the resolver |

For collection-scope Core validation, word 10 is the requested collection and
word 11 is the observed last allocated collection; words 12 through 15 are
zero. For token-scope validation, word 10 is the observed mapped collection,
word 11 is zero, and words 12 through 15 are the exact
`tokenCollectionIdentity` return. Default scope uses zero for words 10 through
15. Skipped artist calls use zero for word 24.

The resolver independently recomputes expected hashes, answer packing, scope
identity, policy, and all state transitions. Matching digest words alone are
insufficient.

## Exact digest preimages

All preimages use `abi.encode`, never `abi.encodePacked`.

### Dependency binding

`DependenciesV1` word 19 is excluded from its own preimage:

```solidity
dependencyBindingHash = keccak256(
    abi.encode(
        DEPENDENCY_DOMAIN_V1,
        block.chainid,
        d.core,
        d.coreCodehash,
        d.coreReadInterfaceId,
        d.coreMarker,
        d.coreSchema,
        d.splitFactory,
        d.splitFactoryCodehash,
        d.splitFactoryReadInterfaceId,
        d.splitFactoryMarker,
        d.splitFactorySchema,
        d.artistRegistry,
        d.artistRegistryCodehash,
        d.artistRegistryReadInterfaceId,
        d.artistRegistryMarker,
        d.artistRegistrySchema,
        d.assetPolicyRegistry,
        d.assetPolicyRegistryCodehash,
        d.allowedSplitWalletRuntimeCodehash
    )
);
```

### Full intent

For each entry, `op` is that entry's exact static operation tuple. Header word
18 is excluded:

```solidity
fullIntentDigest = keccak256(
    abi.encode(
        INTENT_DOMAIN_V1,
        adapterEntrySelector,
        d,
        h.chainId,
        h.resolver,
        h.adapter,
        h.adapterCodehash,
        h.adapterInterfaceId,
        h.adapterMarker,
        h.adapterSchema,
        h.resolverEntrySelector,
        h.authenticatedActor,
        h.governanceActionId,
        h.governanceActionClass,
        h.governanceScopeHash,
        h.governanceOldStateHash,
        h.governanceNewStateHash,
        h.currentFrozenEconomicStateHash,
        h.inheritedFrozenEconomicStateHash,
        h.continuityManifestHash,
        op
    )
);
```

`d` includes all 19 dependency words, including the independently recomputed
binding. `adapterEntrySelector` is the called adapter selector. The distinct
`resolverEntrySelector` in the header prevents an adapter entry from being
reused for another resolver write.

### Observations digest

The digest uses the raw canonical 32-byte result words in exact order:

```solidity
observationsDigest = keccak256(
    abi.encode(
        OBSERVATIONS_DOMAIN_V1,
        fullIntentDigest,
        adapterEntrySelector,
        result[4],  // word 5 dependencyBinding
        result[5],  // word 6 observedCoreCodehash
        result[6],  // word 7 observedFactoryCodehash
        result[7],  // word 8 observedArtistCodehash
        result[8],  // word 9 observedAssetPolicyCodehash
        result[9],  // word 10 collectionId
        result[10], // word 11 coreLastCollectionId
        result[11], // word 12 coreMappingExists
        result[12], // word 13 coreMappedCollectionId
        result[13], // word 14 coreCollectionSerial
        result[14], // word 15 coreBurned
        result[15], // word 16 profileOrTemplateId
        result[16], // word 17 profileExists
        result[17], // word 18 splitWalletExists
        result[18], // word 19 wallet
        result[19], // word 20 walletCodehash
        result[20], // word 21 walletProfileId
        result[21], // word 22 pointerEntriesHash
        result[22], // word 23 pointerMetadataURIHash
        result[23]  // word 24 artistObservation
    )
);
```

### Result digest

The result digest covers every result word after the four-word envelope:

```solidity
resultDigest = keccak256(
    abi.encode(
        RESULT_DOMAIN_V1,
        fullIntentDigest,
        observationsDigest,
        adapterEntrySelector,
        result[4], result[5], result[6], result[7], result[8],
        result[9], result[10], result[11], result[12], result[13],
        result[14], result[15], result[16], result[17], result[18],
        result[19], result[20], result[21], result[22], result[23],
        result[24], result[25], result[26], result[27], result[28]
    )
);
```

The adapter writes words 1 through 4 last from the candidate constants and
recomputed digests. The resolver recomputes all four.

## Closed nested callgraph

The only candidate nested selectors are:

| Target | Canonical signature | Selector | Calldata | Exact returndata |
| --- | --- | --- | ---: | ---: |
| Core | `lastAllocatedCollectionId()` | `0x174a3aaf` | 4 | 32 |
| Core | `tokenCollectionIdentity(uint256)` | `0xa6b638c9` | 36 | 128 |
| split factory | `profileExists(bytes32)` | `0x93e9701b` | 36 | 32 |
| split factory | `splitWalletExists(bytes32)` | `0x33c0a3d3` | 36 | 32 |
| split factory | `walletFor(bytes32)` | `0x7730ab1a` | 36 | 32 |
| split factory | `profileEntriesHash(bytes32)` | `0x472f4153` | 36 | 32 |
| split factory | `profileMetadataURIHash(bytes32)` | `0x9236fe29` | 36 | 32 |
| derived split wallet | `profileId()` | `0x08386eba` | 4 | 32 |
| artist registry | `requireEconomicsConsent(uint256,bytes32,uint8,uint256,bytes32)` | `0xeb663bcc` | 164 | 0 |
| artist registry | `isRoyaltyFreezeAuthorized(uint256,bytes32)` | `0x0652d6ce` | 68 | 32 |

`tokenCollectionIdentity` returns exactly
`(bool mappingExists,uint256 collectionId,uint256 collectionSerial,bool burned)`.
Both boolean words must be canonical. `walletFor` must be a canonical nonzero
address. The wallet's live codehash must equal the pinned wallet runtime, and
`profileId()` must equal the requested profile.

The full profile bundle `P(profileId)` is the following fixed sequence:

1. factory `profileExists`;
2. factory `splitWalletExists`;
3. factory `walletFor`;
4. factory `profileEntriesHash`;
5. factory `profileMetadataURIHash`;
6. live wallet `EXTCODEHASH`; and
7. wallet `profileId`.

Both existence calls must return canonical true. No factory call may be
reordered, omitted, repeated, or added in an approved implementation without a
new packet version.

The exact per-entry graph is:

| Operation | Candidate nested sequence |
| --- | --- |
| O1 compute primary profile hash | `P(profileId)` |
| O2 set primary, default/profile | `P(nextProfileId)` |
| O2 set primary, default/template | no nested `STATICCALL` |
| O2 set primary, collection/profile | Core `lastAllocatedCollectionId` -> `P(nextProfileId)` -> artist `requireEconomicsConsent` |
| O2 set primary, collection/template | Core `lastAllocatedCollectionId` -> artist `requireEconomicsConsent` |
| O2 set primary, token/profile | Core `tokenCollectionIdentity` -> `P(nextProfileId)` -> artist `requireEconomicsConsent` |
| O2 set primary, token/template | Core `tokenCollectionIdentity` -> artist `requireEconomicsConsent` |
| O3 clear primary, default/profile | `P(currentProfileId)` |
| O3 clear primary, default/template | no nested `STATICCALL` |
| O3 clear primary, collection/profile | Core `lastAllocatedCollectionId` -> `P(currentProfileId)` -> artist `requireEconomicsConsent` |
| O3 clear primary, collection/template | Core `lastAllocatedCollectionId` -> artist `requireEconomicsConsent` |
| O3 clear primary, token/profile | Core `tokenCollectionIdentity` -> `P(currentProfileId)` -> artist `requireEconomicsConsent` |
| O3 clear primary, token/template | Core `tokenCollectionIdentity` -> artist `requireEconomicsConsent` |
| O4 freeze primary, default/profile | `P(currentProfileId)` |
| O4 freeze primary, default/template | no nested `STATICCALL` |
| O4 freeze primary, collection/profile | Core `lastAllocatedCollectionId` -> `P(currentProfileId)` |
| O4 freeze primary, collection/template | Core `lastAllocatedCollectionId` |
| O4 freeze primary, token/profile | Core `tokenCollectionIdentity` -> `P(currentProfileId)` |
| O4 freeze primary, token/template | Core `tokenCollectionIdentity` |
| O5 set royalty, default scope | `P(profileId)` |
| O5 set royalty, collection scope | Core `lastAllocatedCollectionId` -> `P(profileId)` -> artist `requireEconomicsConsent` |
| O5 set royalty, token scope | Core `tokenCollectionIdentity` -> `P(profileId)` -> artist `requireEconomicsConsent` |
| O6 clear royalty, default scope | no nested `STATICCALL` |
| O6 clear royalty, collection scope | Core `lastAllocatedCollectionId` -> artist `requireEconomicsConsent` |
| O6 clear royalty, token scope | Core `tokenCollectionIdentity` -> artist `requireEconomicsConsent` |
| O7 freeze royalty | `P(profileId)` |
| O8 artist freeze | `P(profileId)` -> artist `isRoyaltyFreezeAuthorized` |
| O9 mint snapshot, create | Core `tokenCollectionIdentity` -> `P(sourceProfileId)` -> artist `requireEconomicsConsent` |
| O9 mint snapshot, no-op/reject | no adapter call |

Each direct dependency codehash is checked before its first use. The derived
wallet codehash is checked before its call. Each call is zero-value
`staticcall(gas(), ...)`, fails closed, checks exact `returndatasize()` before
bounded copy, and never bubbles or dynamically allocates returndata.

The asset-policy registry has no nested call in V1. Its address and live
codehash are committed because they are part of the resolver assignment-hash
context.

The adapter must not call Governance V2, the mint manager, the mint ledger,
Core pointer discovery, Core prepared-mint reads, or the resolver. Those facts
are resolver-side authentication and become committed request fields.

### Resolver-host-only exact call inventory

These calls are outside the adapter's closed callgraph. They are nevertheless
part of the exact O2/O3 default-scope, governed O4, and O9 host transcripts
and may not be substituted with individual getters, cached guesses, alternate
manager discovery, or shorter decodes:

| Host target | Canonical signature | Selector | Calldata | Exact returndata |
| --- | --- | --- | ---: | ---: |
| Governance V2 | `currentAction()` | `0x546ea281` | 4 | 192 |
| Core | `getSatellitePointer(bytes32)` | `0x3528d53c` | 36 | 320 |
| active mint manager | `mintLedger()` | `0x7786e390` | 4 | 32 |
| mint ledger | `isManagerOperationRootUsed(address,bytes32)` | `0xe67d8006` | 68 | 32 |
| Core | `preparedMint(uint256)` | `0x06d25065` | 36 | 96 |

`currentAction()` returns exactly
`(bool executing,bytes32 actionId,uint8 actionClass,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)`.
`getSatellitePointer` returns exactly
`(address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)`.
`mintLedger()` returns one canonical nonzero address.
`isManagerOperationRootUsed` returns one canonical true boolean.
`preparedMint` returns exactly
`(bool exists,bytes32 operationId,uint256 collectionId)`.

Default O2/O3 and every Governance-routed O4 call make one `currentAction()`
call before the adapter and one after transcript validation; the two exact
192-byte returns must be byte-identical. O9 create makes the four
pointer/manager/ledger/prepared calls before the adapter and repeats all four
after transcript validation; the recomputed proof hash must be identical. O9
no-op and mismatch/reject make one complete set and reject on any proof
failure. A host-only call revert, wrong return length, noncanonical field,
wrong identity, codehash drift, or pre/post mismatch reverts before economic
mutation or event emission.

## Resolver-to-adapter call shapes

Construction uses only these exact probes:

| Probe | Selector | Calldata | Exact returndata | Required value |
| --- | --- | ---: | ---: | --- |
| `supportsInterface(0x01ffc9a7)` | `0x01ffc9a7` | 36 | 32 | canonical true |
| `supportsInterface(0xb4165b1a)` | `0x01ffc9a7` | 36 | 32 | canonical true |
| `supportsInterface(0xffffffff)` | `0x01ffc9a7` | 36 | 32 | canonical false |
| marker getter | `0xb3573c09` | 4 | 32 | `ADAPTER_MARKER_V1` |
| schema getter | `0x94bf44c4` | 4 | 32 | canonical `uint16(1)` |
| dependency binding getter | `0x371b62f3` | 4 | 32 | resolver-computed binding |

The resolver checks adapter code existence and exact runtime codehash before
the probes. Every probe is an available-gas, zero-value `STATICCALL`.

Every operation call uses the exact calldata length stated above and exact
928-byte result. Fallback-only success, short return, oversized return, revert,
and out-of-gas all fail before economic mutation or event emission.

## Canonical ABI and result checks

The adapter rejects noncanonical request calldata before performing a nested
call:

- exact selector and exact `calldatasize()`;
- no trailing bytes;
- every address has zero upper 96 bits;
- every `uint8` has zero upper 248 bits;
- every `uint16` has zero upper 240 bits;
- every boolean is exactly zero or one;
- every `bytes4` is left-aligned with 28 zero trailing bytes;
- every enum is in the candidate range;
- every required address, codehash, marker, interface, binding, ID, and digest
  is nonzero;
- all scope and scope-ID relationships are exact;
- all operation-specific zero fields are zero; and
- every dependency and header identity equals the adapter's immutable
  expectation.

Nested return checks are equally strict:

- an address word has zero upper 96 bits;
- a boolean is zero or one;
- `uint16` values have zero upper 240 bits;
- fixed bytes and integers have the exact ABI alignment;
- `requireEconomicsConsent` succeeds with exactly zero return bytes;
- `isRoyaltyFreezeAuthorized` returns exactly one canonical true word;
- Core and factory semantic values match the request; and
- skipped observations produce zero result words.

The resolver checks the 928-byte result in this order:

1. exact return size before copy;
2. magic, echoed intent, dependency binding, and all four observed codehashes;
3. canonical encoding of every typed result word;
4. zero unused words and operation-specific word 29 semantics;
5. observations digest;
6. result digest;
7. every operation-specific echo and independently computed value;
8. unchanged authenticated storage facts used to build the request; and
9. only then, the state transition and events.

No adapter revert data is bubbled. The resolver uses one local typed failure
class for adapter-call failure and separate local classes for malformed or
mismatched transcripts.

## Authority and state allocation

| Concern | Resolver | Adapter | Dependency |
| --- | --- | --- | --- |
| caller/relayer authentication | owns and enforces | never interprets `msg.sender` as authority | no authority granted by adapter caller |
| default primary set/replace/clear | requires staged Governance V2 executor; reads and byte-exactly rechecks `currentAction`; commits exact action and primary old/new state | validates committed fields and profile/template context only | Governance is not adapter-reachable |
| collection/token primary set/replace/clear | requires current resolver owner; commits zero Governance words; owns assignment, freeze, and counter state | validates authoritative Core identity, profile/template context, and exact artist economics consent | Core and artist return observations only |
| primary exact freeze | requires Governance V2 for default or permanent routes and owner for advertised-loosening non-permanent collection/token routes; owns all freeze layers and exact counter deltas | validates profile/template context, Core identity where scoped, raw freeze state, and old/new hashes | Governance is not adapter-reachable; Core supplies identity only |
| artist economics/freeze semantics | sole semantic enforcer | performs exact physical observation | artist registry returns observation only |
| active manager | discovers the Core pointer, pins identities, authenticates caller, and rechecks create proofs | no manager call | no adapter authority |
| ledger operation root | verifies the root is already used by the authenticated manager and commits the proof hash | commits root and proof hash only | ledger consumption occurred earlier in the mint flow |
| prepared mint | verifies and rechecks exact Core existence, operation ID, and collection | commits operation and proof identities only | no adapter authority |
| nonces/replay | owns | no nonce namespace | artist/ledger retain their own records |
| assignment/freeze/snapshot state | owns and writes | no storage | none |
| mutable-descendant counters | owns, checks, increments/decrements | validates committed arithmetic context only | none |
| continuity and frozen-state chain | owns and writes | commits prior values and computes candidate hashes only | none |
| events | sole emitter | emits none | dependency events remain their own history |
| profile/Core facts | compares with request and transition | observes exact pinned code | returns caller-insensitive read |
| marketplace royalty read | storage/pure only | unreachable | unreachable |

The artist registry observes the adapter as `msg.sender`. Therefore the two
artist reads must be caller-insensitive. This requires explicit reconciliation
of current prose that says the resolver itself calls the registry. The
resolver remains the authority and semantic consumer; the adapter is only the
physical observation boundary.

## Mutation order and atomicity

For every extracted write, the resolver candidate order is:

1. acquire the non-reentrant lock;
2. authenticate actor, selector, Governance or artist context, manager, ledger,
   prepared mint, nonce, and current resolver state;
3. compute the full operation tuple and local full-intent digest;
4. compare live adapter `EXTCODEHASH`;
5. issue the exact available-gas `STATICCALL`;
6. validate the complete 29-word transcript;
7. recheck resolver storage facts that could be changed only by recursion;
8. apply counters, assignments, freezes, snapshots, and continuity writes;
9. emit exact events; and
10. release the lock.

No dependency, adapter, or downstream call follows step 8. Any failure reverts
the lock and every attempted write. In particular, the frozen economic-route
append is resolver-local after transcript acceptance.

O9's exact branch rules refine this generic order: every branch completes the
full host proof before state classification; the create route repeats it after
step 6; the complete idempotent route returns without steps 4-9; and a
mismatched or partial existing route rejects before any adapter call. O2/O3
default scope and Governance-routed O4 perform the two exact
`currentAction()` observations around the adapter. Collection/token O2/O3
performs Core identity and artist consent inside the adapter; O4 performs Core
identity but no artist call. Each route then rechecks resolver-owned
assignment, template, freeze, and counter state before writing.

## Size and release gates

Approval of this packet would not prove deployability. Both contracts must
independently satisfy:

- optimized Solidity `0.8.19` via-IR runtime no larger than `22_576` bytes;
- full initcode, including exact encoded constructor arguments, no larger than
  `47_152` bytes;
- exact boundary tests: `22_576` passes and `22_577` fails; `47_152` passes
  and `47_153` fails;
- deployed runtime SHA-256 and EVM Keccak/`EXTCODEHASH`;
- canonical isolated compiler inputs and receipts; and
- final measurements after every relevant patch and on the serialized final
  base.

The issue #670 prototype measured the monolithic resolver at 30,167 runtime
bytes after optimization, 5,591 bytes above EIP-170 and 7,591 bytes above this
packet's margin gate. Extraction is accepted only if both resulting contracts
meet both margins without omitting behavior.

Deployment remains adapter-first, then resolver. Only the resolver is
registered. The 37 ordinary profile/Registry V2 entries remain 37; private
dependency ID 38 is carried on a separate versioned inventory surface. Old
manifests remain historical version-1 evidence, and adapter-first capture uses
a new versioned contract set.

## Hostile conformance matrix

An implementation cannot be accepted without at least these tests:

| Class | Required hostile cases |
| --- | --- |
| selector/interface | every selector recomputed; wrong literal; wrong XOR; omitted/extra selector; invalid ERC-165 probe; fallback-only support |
| construction | zero/code-less adapter; wrong runtime; marker; schema; binding; dependency address/codehash/interface/marker/schema; wallet runtime |
| request length | empty; every short word boundary; one-byte short; one-byte long; every oversized boundary; trailing zero and nonzero bytes |
| request canonicality | dirty address; dirty `bytes4`; dirty `uint8`; dirty `uint16`; bool 2; invalid scope/type/freeze mode; nonzero prohibited field |
| request substitution | chain, resolver, adapter, adapter codehash, entry selector, resolver selector, actor, action, continuity, dependency, and operation field changed one at a time |
| adapter identity drift | runtime drift after construction and between preflight and operation call |
| adapter failure | revert; empty return; every short return; every oversized return; out-of-gas; missing selector; arbitrary fallback success |
| result envelope | wrong magic, intent, observations digest, result digest, binding, codehash, or operation-specific word 29 |
| result canonicality | dirty address/bool/uint; every field mutated one at a time; nonzero unused word; operation-population rule violated |
| Core | missing code; wrong codehash; revert; out-of-gas; short/oversized return; noncanonical booleans; zero/incorrect collection; mapping absent; mapped ID mismatch; serial/burned mutation |
| factory | missing code; wrong codehash; each selector missing; false existence; zero/dirty wallet; short/oversized/malformed hash; call-order and call-count drift |
| wallet | zero address; wrong runtime; wrong profile ID; revert; out-of-gas; short/oversized result; profile/code drift |
| artist economics | missing/wrong artist code; revert; nonzero returndata; out-of-gas; stale or wrong consent; caller-sensitive mock |
| artist freeze | false; noncanonical bool; wrong assignment/collection; stale/revoked fact; caller-sensitive mock |
| primary authorization matrix | profile and template across default/collection/token and create/replace/clear; wrong owner; default without staged Governance; dirty/changed six-word `currentAction`; wrong old/new assignment-state hash; prohibited factory call on template; missing Core identity or artist call on collection/token; artist consent over wrong resulting hash |
| primary freeze matrix | profile and template across default/collection/token; wrong permanent/advertised-loosening derivation; permanent route without terminal Governance; default non-permanent route without tightening Governance; collection/token non-permanent wrong owner; wrong Core identity; prohibited template factory call; unexpected artist call; every raw current/inherited/class/global freeze field stale or substituted |
| primary counters | default set/replace/clear/exact-freeze `0`; collection create `+1`/replace `0`/clear `-1`/exact-freeze `-1` at default; token create `+1,+1`/replace `0,0`/clear `-1,-1`/exact-freeze `-1,-1`; descendant count unchanged by ancestor exact freeze; stale counter; underflow; frozen replace/clear; state or counter drift after adapter |
| authority | wrong relayer context, Governance caller/selector/action ID/class/scope/old/new hash, manager pointer, manager interface, manager codehash, ledger address/codehash/root, operation ID, or prepared record |
| snapshot hash separation | independently mutate source per-key `assignmentHash`, metadata `assignmentPolicyHash`, canonical source `royaltyAssignmentHash`, token per-key `nextAssignmentHash`, and canonical returned token `royaltyAssignmentHash`; expected accepts only canonical source hash; artist consumes only token per-key next hash; result word 29 and hook return accept only canonical token hash |
| snapshot branches | absent-state create; exact same-token/same-expected/root/operation and all three source-provenance hashes no-op; different expected canonical hash; same expected with different source per-key/metadata/root/operation; mismatched answer/hash; every partial existing-state permutation; no adapter call, write, continuity append, counter change, or event on no-op/reject |
| snapshot proof | pointer return wrong length/canonicality/target/codehash/module type/interface/registry status/manifests/revision; manager ledger wrong; ledger false/dirty; prepared absent/wrong token operation or collection; proof-hash substitution; every pre/post create proof field drift; no-op and mismatch-path proof failure |
| snapshot effects | exact-permanent answer/per-key hash; all three distinct source-provenance hashes; authoritative collection and stored proof identities; unchanged default/collection counters; one continuity append; create-only event order set -> frozen -> snapshot; exact topic/indexing/canonical source-and-token hash data; no-op returns recomputed canonical token hash and emits nothing |
| replay/staleness | nonce/root reuse; stale Governance/artist context; stale preview; old assignment; old counters; old continuity; old adapter/dependency codehash |
| reentrancy | adapter, Core, factory, wallet, and artist attempts to enter every resolver write; resolver lock remains effective |
| atomicity | no nonce/root consumption, counter, assignment, freeze, snapshot, continuity, or event survives any adapter, dependency, transcript, or downstream-local failure |
| differential | golden vectors versus repaired monolith and revenue specification for every successful and failing sequence, including storage, hashes, events, freeze, snapshot, continuity, and royalty answer |
| callgraph/opcode | no reachable adapter `CALL`, delegation, create, destruction, value, resolver callback, generic router, arbitrary target, arbitrary selector, or dynamic bytes |
| marketplace isolation | no external-call or creation opcode reachable from `royaltyReceiverAndBps` |
| gas | cold and warm dependencies; maximum conformant transcript; nested revert and out-of-gas; EIP-150 depth; parent post-call reserve; repricing-sensitive mocks |
| size | both exact runtime and full-initcode pass/fail boundaries and final isolated receipts |

Positive tests independently recompute dependency, intent, observation, result,
assignment, policy, state, event, and continuity hashes from raw inputs. They
must not reuse implementation helpers to prove themselves.

## BLOCKING REVIEW DECISIONS

Every item below must receive an explicit disposition before this packet can
be frozen. Silence, a passing documentation check, bot approval, or a merge of
this Proposed file is not a disposition.

### BLOCKING REVIEW DECISION R1: entry set and uniform transcript

Accept, revise, or reject the exact nine-entry extraction, the three identity
getters, and the uniform 29-word/928-byte result. ADR 0021 does not mechanically
dictate this exact split.

### BLOCKING REVIEW DECISION R2: primary type and authorization matrix

Accept or revise the complete O2/O3/O4 profile/template by
default/collection/token matrix, including staged Governance V2 for every
default set/replace/clear, current resolver owner for every collection/token
set/replace/clear, exact Core identity, mandatory artist economics consent,
the O4 permanent/default Governance and non-permanent owner split, complete
template/freeze context, the primary Governance scope/state preimages, and
set/clear/exact-freeze counter deltas. O1 remains profile-only. Any O2/O3/O4
field or ordering change changes its selector, length, interface XOR, result
population, and test matrix.

### BLOCKING REVIEW DECISION R3: snapshot ABI and hash semantics

Approve or revise the six-argument snapshot selector `0xc8323dfa`, normative
`ROYALTY_POLICY_DOMAIN` meaning of its expected argument and return, exact
separation of source per-key assignment hash, immutable metadata policy hash,
canonical source royalty hash, token per-key next hash, and canonical token
royalty hash, plus the create/no-op/mismatch state machine. No review may
reinterpret one of those values as another. The prototype's `0x9697a717`
three-argument function and `mintManager()` probe are stale and cannot be
frozen.

### BLOCKING REVIEW DECISION R4: manager and ledger discovery

Accept or revise `MINT_MANAGER_POINTER_ID`,
`MINT_MANAGER_INTERFACE_ID`, the five-entry host-only call inventory, all
pointer return fields, the exact snapshot-proof preimage, constructor-pinned
ledger identities, create pre/post proof rechecks, and no-op one-pass proof.
None of those calls may move into the adapter without a new packet callgraph.

### BLOCKING REVIEW DECISION R5: dependency markers and schemas

Accept the candidate Core/factory/artist marker constants and schema `1` as
codehash-bound non-ABI identity facts, or add exact marker/schema probes to
those dependencies. Adding probes changes the closed callgraph and requires
new selectors, lengths, and tests.

### BLOCKING REVIEW DECISION R6: artist dependency topology

ADR 0022's artist adapter topology and final artist-registry runtime/interface
are not frozen. Pin the exact artist address, runtime, interface, marker,
schema, and caller-insensitive economics/freeze behavior after that decision.

### BLOCKING REVIEW DECISION R7: operation state-word semantics

Approve or revise the exact O4-O9 field names and meanings, especially O4's
raw freeze/template/counter state, the three counter words in O7/O8, and O9's
proof, three stored source-provenance hashes, current snapshot,
root/operation, and counter fields. The ABI types and selectors above are
mechanically pinned to the candidate ordering; changing a type or order
changes the selector, calldata length, and interface ID.

### BLOCKING REVIEW DECISION R8: full profile bundle

Accept the exact seven-step `P(profileId)` sequence on every profile-bearing
entry, including freeze operations and O9 create, while template O2/O3/O4
routes make no factory/wallet call. Any accepted subset or template probe must
regenerate result population rules, gas measurements, and hostile call-count
tests.

### BLOCKING REVIEW DECISION R9: Core token-identity classes

Accept or revise the candidate rule that O2/O3 token-scope mutation accepts
ordinary minted, retained burned, and same-transaction prepared identities
when Core reports `mappingExists == true` and the exact collection, while O9
additionally requires the exact prepared record and `coreBurned == false`.
Golden vectors must cover all accepted identity classes and never-allocated
or incident-aborted rejection.

### BLOCKING REVIEW DECISION R10: adapter-mediated artist wording

Approve the interpretation that the resolver owns artist authorization while
the adapter physically performs the exact caller-insensitive artist
`STATICCALL`, and reconcile the revenue and artist specifications. If the
registry must observe the resolver address as `msg.sender`, this topology is
not conformant.

### BLOCKING REVIEW DECISION R11: available-gas measurements

All calls are `staticcall(gas(), ...)`; no cap or GGP is proposed. Before
freeze, publish measured cold-path gas, each nested EIP-150 reduction, minimum
parent post-call gas, maximum conformant return handling, and revert/out-of-gas
behavior. Reviewers must accept exact measurement thresholds or revise the
topology; no agent may invent a fixed reserve or overload an existing GGP.

### BLOCKING REVIEW DECISION R12: digest and ABI golden vectors

Generate and independently recompute at least one nontrivial golden vector per
entry, constructor probe vectors, all calldata lengths, all selectors, the
`0xb4165b1a` XOR, O2/O3/O4 matrix branches and counter deltas, O9's five
distinct hash roles, snapshot proof and three-way state-machine branches,
snapshot event topic, the four transcript digest preimages, and the primary
freeze-Governance and snapshot-proof preimages. This Proposed packet supplies
mechanical candidates, not independently approved vectors.

### BLOCKING REVIEW DECISION R13: deployability

Prove both resolver and adapter satisfy `22_576` runtime and `47_152`
full-initcode limits on the final isolated build. Failure requires a reviewed
versioned redesign, not omitted validation, zero stubs, or a readiness waiver.

## Approval and freeze procedure

A later approval change must:

1. resolve R1 through R13 in text;
2. update every affected signature, selector, XOR, length, tuple, result rule,
   preimage, and callgraph as one atomic packet;
3. include independent machine-generated vector evidence;
4. identify the exact approved commit;
5. state that approval authorizes only a conforming implementation, not
   deployment or production readiness; and
6. leave ADR 0021, revenue-spec reconciliation, implementation review,
   deployment evidence, audit, and release approval as separate gates.

Until then, this document is a review artifact only.
