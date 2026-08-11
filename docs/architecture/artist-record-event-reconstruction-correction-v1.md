# Artist Record/Event Reconstruction Correction V1

Status: **Proposed correction packet only; pre-audit and source-blocking.**

This packet freezes the smallest complete typed correction needed to make the existing
37 record-domain, 54 normative-event, and 57 operation inventories mutually
reconstructible. It does not accept `normative_owner_events`, does not define
owner Solidity, and does not create the later dual-continuity or owner inner-
commitment packet.

## Decision

Four viable shapes were evaluated:

1. Weaken event-only reconstruction to permit current-state or storage joins.
   Rejected: those values are not immutable event evidence and weaken
   `[AA-RECON]`.
2. Fix only operation 12 and the original four examples. Rejected: that leaves
   the remaining 57-operation/37-domain component join unproved.
3. Build the complete per-created-record component map, append every minimal
   suffix it mechanically requires, and independently pin typed vectors.
   **Selected.** It preserves every existing prefix field in its existing order
   and indexed position, leaves 39 event rows exact, corrects 15, and keeps the
   typed event inventory at 54.
4. Accept packet-supplied vector words and hashes. Rejected: coordinated word,
   hash, and semantic-digest re-pins would remain possible.

The packet is authoritative only after independent review. Until then, and
afterwards until the remaining source gate closes, every interface, source,
authorization, deployment, and readiness flag remains false.

## Complete field-source proof

The machine-readable packet contains 40 ordered reconstruction rows, one for
each created primary or secondary record across the 57 operations. Together
they cover all 37 domains and all 430 ordered preimage components. Every
component names its exact Solidity type and maps either to one typed field in
an event emitted by that operation or to one of nine closed constants:
record domain, constructor-captured deployment chain, immutable Registry,
immutable Core or Finality Registry provider pins, and the exact artist/
collaborator acceptance or open/counter-statement discriminator.

No current-state read, storage lookup, live `block.chainid`, generic witness,
or opaque derived word is a permitted source. The full proof found fifteen
events requiring an append-only unindexed suffix:

| Event | Exact suffix |
| --- | --- |
| `ArtistAttributionStateChanged` | `bytes32 recordArtistId`, `bytes32 recordBindingHash`, `address recordSigner`, `uint256 recordNonce`, `uint64 recordSignedAt` |
| `ArtistDelegationRevoked` | `address signer`, `uint8 authorityClass`, `uint256 nonce`, `uint64 signedAt` |
| `ArtistHistoryLaneVerified` | `address predecessorRegistry`, `uint64 sequence`, `bytes32 recordHash`, `bytes32 recordChainHash` |
| `ArtistIdentityRecovered` | `bytes32[] supersededRecordHashes` |
| `CollaboratorAccepted` | `bytes32 bindingHash` |
| `ArtistSanctionRecorded` | `bytes32 artistId` |
| `ArtistPolicyConsentRecorded` | `address mintManager`, `bytes32 artistId` |
| `ArtistEconomicsConsentRecorded` | `address resolver`, `bytes32 artistId` |
| `ArtistSaleConsentRecorded` | `address saleAdapter`, `bytes32 artistId` |
| `ArtistContentConsentRecorded` | `address metadataContract`, `bytes32 artistId` |
| `ArtistRoyaltyFreezeAuthorized` | `address resolver`, `bytes32 revenueClass`, `bytes32 artistId` |
| `ArtistContentFreezeAuthorized` | `address metadataContract`, `bytes32 artistId` |
| `ArtistRecoveryApprovalRecorded` | `bytes32 artistId` |
| `ArtistAttestationRecorded` | `bytes32 artistId` |
| `ArtistContentRatificationRecorded` | `address metadataContract`, `bytes32 artistId` |

## Exact special-case rules

### Binding refusal

`ArtistAttributionStateChanged` retains its full existing prefix and appends:

```solidity
bytes32 recordArtistId,
bytes32 recordBindingHash,
address recordSigner,
uint256 recordNonce,
uint64 recordSignedAt
```

For operation 3 these values, together with the existing collection,
generation, authenticated signer, authority class, reason hash, and immutable chain,
Registry, and Core bindings, reconstruct
`BINDING_REFUSAL_RECORD_DOMAIN`. For every other operation emitting this event,
the five suffix values are zero. `actor` remains the immediate actor/relayer and
is never substituted for `recordSigner`. A nonzero suffix on another operation is a
collision and conformance failure.

### Delegation revocation

`ArtistDelegationRevoked` retains its existing prefix and appends:

```solidity
address signer,
uint8 authorityClass,
uint256 nonce,
uint64 signedAt
```

The complete typed event plus immutable chain and Registry bindings reconstructs
the revocation record hash. No generic record-witness event is permitted.

### History-import leaf

`ArtistHistoryLaneVerified` retains its existing prefix and appends:

```solidity
address predecessorRegistry,
uint64 sequence,
bytes32 recordHash,
bytes32 recordChainHash
```

The predecessor and sequence are event payload values; no binding-state lookup
is permitted. A valid event requires nonzero `predecessorRegistry`,
`recordCount > 0`, `sequence + 1 = recordCount`,
`recordChainHash == laneTip`, a valid lane kind, and nonzero record and chain
hashes. The leaf remains the exact double-hashed `[AA-IMPORT]` construction;
packed encoding is forbidden.

### Identity-recovery supersession

`ArtistIdentityRecovered` retains its existing prefix and appends:

```solidity
bytes32[] supersededRecordHashes
```

The array length is 0 through 64. Every element is nonzero, elements are
strictly ascending as unsigned `bytes32` values, and duplicates are forbidden.
The existing `supersededRecordsHash` must equal
`keccak256(abi.encode(IDENTITY_RECOVERY_SUPERSESSION_DOMAIN,
supersededRecordHashes))`. The dynamic-array offset and length are committed;
`abi.encodePacked` is forbidden.

## Preserved boundaries

- All 37 V1 semantic record domains and their exact preimages remain intact.
- Thirty-nine event declarations are byte-semantic carry-forwards. The other
  fifteen keep the complete legacy prefix and receive only the suffixes above.
- All 57 operation record/event joins retain their exact create/existing and
  source-order projections. Forty created-record rows map all 430 ordered
  preimage components without an implicit storage/current-state join.
- Historical commit `58599147cadd7bb36d74e5a37485ff5d49ae9129`
  (`6138e2431e86f906d71969c2b74bf9feba2a0780` root,
  `c4de81dc0654860d7665073d2beb43e10339803a` `smart-contracts` tree)
  covers only 21/54 normative events. Split prototype
  `1c991bc9f7d3a35e36f6fa2ec2a1044d1ed65ff7`
  (`e9b6e8e2c2084772ecf475cc94cb86191f214ac8` root,
  `9eb8e07bb564dbe8a95670695d867d2b786681cc` `smart-contracts` tree)
  covers only 2/54 while using generic `ArtistOperationCommitted`. Both commits
  were machine-local and are now archived as exact Git object payloads for
  compatibility evidence only, never as a source, deployment, audit, or
  readiness baseline.
- Shared mechanics remains exactly 3 accepted and 16 unresolved. All seven
  layout rows, all 64 replay rows, and all four owner inner preimages remain
  null, unresolved, and source-blocking.

## Review obligations

The checker independently derives all 37 domains, 54 event declarations, 57
operation joins, 40 created-record maps, 430 typed component sources, 15 exact
suffixes, and nine permitted constants from bound sources plus checker-owned
rules. It reconstructs every event topic and semantic digest. Every canonical
record vector has a named typed component schema; checker-owned typed fixture
values independently produce and pin every ABI word and record hash, including
the history inner/double hash and dynamic-array offset/length words.

Historical compatibility is self-contained in
`docs/architecture/artist-record-event-reconstruction-historical-git-objects-v1.json`
(raw SHA-256
`f867c363abfc6290e7fb9e1efad02bdcecbdb45c51e98fd664cf911e3eecae55`).
The archive contains two raw commit payloads, four raw tree payloads, and 38
unique raw blob payloads encoded as base64; the 39 selected paths deduplicate
the shared `StreamArtistApprovals.sol` blob. The checker uses no Git ref or Git
subprocess. It independently recomputes every Git SHA-1 from
`type + SP + decimal byte length + NUL + raw payload`, traverses each commit to
its root and direct `smart-contracts` tree, derives the exact Artist Solidity
path/blob inventory and event names, and reproduces 12/21 plus 27/2.

Hostile tests must reject omission, insertion, reordering, type/name/index
drift, topic drift, unmapped or storage-sourced components, provider/constant
substitution, record-preimage drift, packed encoding, array ambiguity,
cross-record and cross-event substitution, generic-event fallback, and
coordinated component/word/hash/semantic-digest re-pins for static, history,
and dynamic vectors. Historical archive hostiles additionally reject missing,
extra, duplicate, outside, symlinked, malformed-base64, object-ID, tree, path,
blob, archive-digest, commit/tree-ID, readiness, and source-promotion drift.

This packet changes architecture evidence only. It authorizes no Solidity,
deployment, live-chain action, audit claim, or readiness credit.
