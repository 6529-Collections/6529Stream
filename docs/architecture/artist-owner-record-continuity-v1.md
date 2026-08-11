# Artist owner dual-record continuity prerequisite

Status: **Proposed, pre-audit, source-blocking**.

This packet freezes one dependency of the modular artist-authority successor: how an exact retained semantic record hash is paired with an owner-local V2 commitment and folded into bounded owner history. It does not accept `owner_storage`, `owner_snapshots`, or `replay_keys`; authorize any owner or Coordinator source; define an entrypoint ABI; or provide deployment, audit, or readiness credit.

The machine-readable authority is [artist-owner-record-continuity-v1.json](artist-owner-record-continuity-v1.json). Its independent checker and hostile suite are `scripts/check_artist_owner_record_continuity.py` and `scripts/test_artist_owner_record_continuity.py`.

## Selected continuity shape

Four viable shapes were evaluated:

1. Retain the semantic record hash as the only identity. This preserves compatibility but fails to bind the isolated V2 owner, suite, revision, sequence, original caller, or history.
2. Replace each semantic hash with a new owner-local V2 hash. This binds V2 provenance but breaks the retained 37-family record vocabulary and historical reconstruction.
3. Retain both identities. The semantic hash remains the compatibility identity; the authoritative owner receipt is a domain-separated V2 commitment over the immutable suite and owner identity, successful owner revision, checked record sequence, accepted original caller, exact record domain, and retained semantic hash.
4. Wait for the full entrypoint ABI or accept an opaque Coordinator word. Waiting is unnecessary for record continuity, while an opaque word would violate owner-side recomputation.

Option 3 is selected. Recipe, action, and exact typed calldata identity remain the responsibility of the still-unresolved `actionCommitment`. The record receipt neither invents those fields nor weakens their later gate.

## Exact retained input

The merged reconstruction correction is the record-semantic authority:

- 37 ordered record domains;
- 54 normative event surfaces, including 15 corrected surfaces;
- 57 operation joins;
- 40 created-record bindings;
- 430 event-field or permitted-immutable component bindings;
- no implicit current-state or storage join.

The typed owner recomputes the semantic hash from those exact fields and constructor-captured immutable values. `block.chainid`, `abi.encodePacked`, caller-supplied hashes, current-state lookups, and Archive reads are forbidden inputs.

## Owner domain identity

Each of the seven owner-domain IDs is `keccak256(bytes(storage_namespace))`, where `storage_namespace` is the exact merged foundation string. This yields stable, independently recomputable bytes32 identifiers without selecting any owner storage struct or physical mapping slot.

The owner V2 record commitment is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ARTIST_OWNER_RECORD_COMMITMENT_V2"),
  uint16(2),
  deploymentChainId,
  RegistryV2,
  Coordinator,
  ArchiveV2,
  owner,
  ownerDomainId,
  ownerRevision,
  recordSequence,
  originalCaller,
  recordDomain,
  semanticRecordHash
))
```

`deploymentChainId` is constructor-captured; it is never read live. Registry, Coordinator, and Archive are immutable bindings; `owner` is the typed owner itself. `ownerRevision` is the successful action's checked next revision. `recordSequence` is the checked prior sequence plus the record's one-based position. `originalCaller` is the nonzero immediate Registry submitter already accepted by the shared ingress decision. The domain and semantic hash must be exact, nonzero, and owned by that owner domain.

## Logical dual mapping

The logical receipt coordinate is the typed pair `(recordDomain, semanticRecordHash)`, whose value is the owner V2 commitment. It is insertion-only:

- no deletion, overwrite, enumeration, current pointer, or latest pointer;
- the same semantic record retry reverts before changing sequence, tip, receipt, or event state;
- the same 32-byte semantic hash under a different record domain is a different typed coordinate;
- supersession creates a new semantic record and owner commitment while every predecessor receipt remains immutable.

The physical mapping slot and surrounding domain storage remain unresolved. Freezing this logical receipt therefore does not accept `owner_storage`.

## Bounded ordering and record chain

The record/event correction supplies exact operation record bindings. They are filtered per owner and ordered `primary`, then `secondary`. There are 39 owner-record batches and 40 created records. Operation 35, `recoverArtistIdentity`, is the only two-record owner batch: `IDENTITY_RECOVERY_RECORD_DOMAIN` followed by `IDENTITY_RECOVERY_SUPERSESSION_DOMAIN`. Every other owner batch has one record; owner actions without a created record have zero.

Each present record applies the already-frozen foundation transition:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"),
  deploymentChainId,
  RegistryV2,
  Coordinator,
  ArchiveV2,
  owner,
  ownerDomainId,
  priorRecordSequence,
  nextRecordSequence,
  priorRecordChainTip,
  ownerRecordCommitment
))
```

The transition runs exactly zero, one, or two times. A zero-record action preserves sequence and tip. Record-sequence overflow reverts before any mutation or event. Dynamic arrays, enumeration, and owner-local history loops are prohibited.

## Fixed record delta

`recordDeltaCommitment` is `keccak256(abi.encode(...))` over:

- its independently owned V2 domain and schema version;
- the immutable suite/owner identity;
- successful owner revision;
- prior and next record sequences;
- prior record-chain tip;
- a `uint8` count;
- two fixed `(recordDomain, semanticRecordHash, ownerRecordCommitment)` slots;
- the final record-chain tip.

For count zero, both slots are all-zero and sequence/tip are unchanged; the resulting delta commitment is nevertheless nonzero and exact. For count one, slot zero is present and slot one is all-zero. For count two, both are present in primary-then-secondary order. A present slot must contain three nonzero, independently recomputed values. An absent slot must contain three zero words.

This resolves only `record_delta_commitment_preimage`. `action_commitment_preimage`, `domain_state_commitment_preimage`, and `replay_delta_commitment_preimage` remain unresolved, so the foundation's aggregate `four_inner_commitments_resolved` flag remains false.

## Archive boundary

ArchiveV2 remains evidence-only. It cannot authorize an owner transition, answer replay or current state, or supply any owner commitment word. Owners never read it. Content hash, pointer, appended block, and evidence bytes do not enter the owner commitment.

A future evidence protocol may use `evidenceId = ownerRecordCommitment` and `evidenceVersion = recordSequence`, which satisfies ArchiveV2's nonzero exact-key shape. This packet does not accept when Archive must be called or the evidence byte schema. Archive's same-content retry returning `appended=false` is transport idempotency only; it cannot turn a duplicate semantic owner transition into success.

If a later Coordinator calls Archive in the same transaction, an Archive conflict or any later owner, event, evidence, recipe, or Coordinator failure must revert the entire transaction. Partial owner or Archive success is forbidden.

## Failure and hostile obligations

The packet and checker reject:

- live `block.chainid`, `tx.origin`, `abi.encodePacked`, opaque external commitment words, or implicit state joins;
- zero or unknown domains, wrong-owner records, zero semantic hashes, zero original caller, stale revision/sequence/tip, overflow, duplicate receipt, count/order drift, and no-op success;
- receipt deletion/overwrite, sequence reuse/decrement, tip rewind, generic hash-only identity, enumeration/history loops, Archive authority, delegatecall, proxy/upgrade, or mutable rebinding;
- omission, addition, or reordering of any of the 37 domains, 40 created records, 39 owner batches, or seven owner identities;
- coordinated packet/schema/authority/vector digest re-pins;
- field, type, order, domain, version, address, chain, owner, caller, sequence, semantic-hash, count, absent-slot, or final-tip vector drift.

Canonical vectors cover both owner-record commitments, both ordered chain transitions, and fixed zero-, one-, and two-record deltas. The checker owns every domain, type sequence, fixture word, and expected hash independently of the packet.

## Maturity boundary

After this prerequisite, all of the following remain false or unresolved:

- `owner_storage`, `owner_snapshots`, and `replay_keys` acceptance;
- seven typed operative owner layouts and all 64 replay rows;
- three other inner commitments;
- entrypoint and mutation ABI, event acceptance, provider/role/signer protocols, recipe/composite/evidence/construction/errors/lock/gas decisions;
- interface/full freeze, source presence, implementation/deployment authorization, audit, or readiness.

RegistryV2 remains a directory only. ArchiveV2 remains evidence only. The Coordinator remains absent and non-authoritative. All 57 operations remain source-absent and unauthorized.
