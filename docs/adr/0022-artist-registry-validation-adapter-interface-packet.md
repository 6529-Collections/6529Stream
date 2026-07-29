# ADR 0022 Proposed Artist-Registry Validation Adapter Interface Packet

## Status

**Proposed for review. Not accepted. Not frozen. Not implementation-authorizing.**

This document is a candidate normative interface and transcript packet for
[ADR 0022](0022-immutable-artist-registry-validation-adapter.md). ADR 0022
itself remains `Proposed`. Neither this packet, a pull request containing it,
passing documentation checks, nor an automated review accepts ADR 0022,
freezes this interface, authorizes Solidity implementation, authorizes
deployment, or changes the protocol's pre-audit maturity.

Every item headed **BLOCKING REVIEW DECISION** must be resolved by an explicit
independent approval. Until then, all signatures, selectors, interface IDs,
field masks, encodings, digest preimages, limits, and gas reserves below are
candidate values only.

## Purpose And Scope

The candidate topology keeps one state-owning `StreamArtistRegistry` and adds
one immutable, stateless, implementation-private
`StreamArtistRegistryValidationAdapter`. This packet:

- inventories all 57 writes required by
  [`stream-artist-authority.md`](../stream-artist-authority.md);
- records the gap against the frozen issue #670 measurement checkpoint;
- proposes one dedicated adapter selector per normative write;
- proposes shared request and fixed response transcripts;
- limits the adapter's caller-independent nested observations to signature
  verification;
- allocates all authority, state, nonce, GGP, event, and continuity duties to
  the registry; and
- records every currently identified unresolved protocol choice as blocking.

This packet does not change the Permanent artist read interfaces, the Core ABI,
the artist module type, the Registry V2 ordinary row count, the 22-GGP/3-GTP
inventory, any accepted ADR, or any generated or release artifact.

## Evidence Baseline And Current Gaps

The frozen issue #670 checkpoint measured:

| Contract | Optimized via-IR runtime | Creation/init checkpoint | Status |
| --- | ---: | ---: | --- |
| incomplete `StreamArtistRegistry` | 23,614 bytes | 25,609 bytes | 962 bytes below EIP-170, but 1,038 bytes above ADR 0022's 22,576-byte production ceiling |

That checkpoint implements 13 of the 57 normative artist writes. The other 44
are absent. Its inherited `raiseGasParameter(bytes32,uint256)` entry is not one
of the 57 artist-lifecycle writes.

The checkpoint also has these known nonconformities:

- `operativeIdentityRecord` has no operative revision state and
  `recordIdentityRevision` is absent.
- Guardian sets, pending rotations, and prior-address standing revocations
  read as permanently empty.
- Only one binding per collection is stored; prior generations are not
  retained for `attributionBinding`.
- Collaborator count is permanently zero, enumeration reverts, and the
  collaborator payout mapping has no write path.
- Pending repudiation is permanently empty.
- Platform-works declarations, contests, claims, corrections, and
  artist-bound attribution claims read as permanently empty.
- Attestation, delegation, successor, steward-sanction-grant, dormancy, and
  estate-activation reads are permanently empty.
- Recording a sanction does not make the required
  `ARTIST_ACCEPTED -> ARTIST_SANCTIONED` transition reachable because
  `confirmSanctionFinalized` is absent.
- Only recovery approval stores signature evidence. Other checkpoint writes
  use a sequential counter, while the normative model requires independently
  consumable unordered nonces scoped to each `artistId`.
- The checkpoint permits 16,384 identity-document bytes, while
  `[AA-LIMITS]` fixes 8,192, and it does not consistently enforce the URI,
  reason, array, and signature bounds required by the specification.

The strict extraction lower bound is therefore not merely the 1,038 bytes
needed to bring the incomplete checkpoint to 22,576 bytes. The completed
registry must also add all 44 absent transitions, their state, records,
events, historical reads, hostile checks, and tests. No honest final size is
derivable before a conforming implementation is compiled.

## Candidate Architecture Boundary

### Registry-only authority and state

The registry remains the sole owner and enforcer of:

- every caller, role, artist, collaborator, delegate, guardian, prior-address,
  successor, steward, arbiter, and Governance V2 authorization;
- all nonces, revoked digests, deadlines, liveness clocks, capability masks,
  collaborator thresholds, current-state checks, and replay state;
- the `ARTIST_ERC1271_VERIFY_GAS` GGP and its live value, floor, revision,
  raise authority, and evidence;
- every identity, binding generation, collaborator, consent, payout,
  sanction/finality, platform-work, claim, attestation, delegation, guardian,
  rotation, repudiation, succession, dormancy, estate, recovery, import,
  record-chain, payload-index, and cutover fact;
- every Core, role-registry, Governance V2, pointer, finality-registry, and
  predecessor-registry read;
- the reentrancy lock, exact adapter-code-hash check, response comparison,
  state transition, record append, payload storage, and event emission; and
- all Permanent reads and all Registry V2 continuity.

No adapter result is authorization. A conforming registry rejects a validly
encoded adapter transcript whenever its own authenticated caller, authority,
state, nonce, deadline, capability, GGP, or dependency facts do not match.

### Adapter-only candidate extraction

The adapter candidate owns only:

- canonical EOA signature recovery and contract-signature verification;
- bounded canonical dynamic-ABI validation;
- operation-specific scalar, enum, ordering, uniqueness, mask, and reserved
  word validation;
- computation of the operation's typed-data, record, dynamic-input,
  full-intent, observation, and result digests; and
- construction of one exact fixed 512-byte response.

The adapter owns no storage, nonce, authority, role, event, GGP, module row,
pointer, continuity fact, or recovery path. It has no payable path, fallback,
receive function, arbitrary target, arbitrary selector, generic `bytes`
router, proxy, delegatecall, deployment opcode, self-destruct path, or callback
into the registry.

### Bounded multi-signer nested callgraph

The candidate closed callgraph is:

```text
registry write
  -> acquire the registry-wide non-reentrant lock
  -> registry-local authority/state/GGP/dependency checks
  -> registry validates the ordered signer-proof bundle:
       at most 33 participants (primary plus at most 32 collaborators);
       exactly two participants for two-sided rotation;
       mixed direct/EOA/ERC-1271 modes under the per-operation policy
  -> registry verifies live adapter EXTCODEHASH
  -> zero-value available-gas STATICCALL to dedicated adapter selector
       -> process signer proofs in canonical participant order
       -> for each EOA proof: canonical ECDSA recovery through the fixed
          ecrecover precompile
       -> for each contract proof: one capped zero-value STATICCALL to that
          exact request-bound signer:
             isValidSignature(bytes32,bytes)
       -> fold every per-signer observation into one ordered observation chain
  -> exact 512-byte return
  -> registry recomputation and word-for-word comparison
  -> registry state writes and events
```

The only direct state-bearing or arbitrary-code targets selected and called by
the adapter are the exact ordered ERC-1271 signers in the authenticated proof
bundle. The fixed ecrecover precompile is the only EOA-path call target. An
ERC-1271 signer is opaque adversarial code: while executing under `STATICCALL`
and the per-signer cap it may perform arbitrary transitive static execution,
consume the cap, revert, return malformed data, or attempt callbacks. Those
transitive targets are not adapter-controlled dependencies, are not pinned by
this packet, and confer no authority. Static context, the registry lock,
bounded return handling, and fail-closed transcript comparison contain that
execution. Core, role-registry, Governance V2, pointer, finality-registry, and
predecessor-registry observations remain registry-side. The adapter may not
call any of them directly.

The registry follows lock-first checks-effects-interactions:

1. acquire the registry-wide lock before any validation or external call;
2. complete every authority, state, nonce, deadline, bound, hash, GGP,
   code-hash, signer-bundle, adapter-transcript, and semantic comparison;
3. permit no durable mutation or normative event before the complete
   transcript is accepted;
4. apply state, nonce, record-chain, payload-index, signature-storage, and
   event effects atomically; and
5. make no external call after the first durable write.

The lock's transient state is the only write permitted before transcript
acceptance. Any failure reverts that lock together with the whole call.

**BLOCKING REVIEW DECISION AR-01:** Accept ADR 0022's one-registry/one-stateless-
adapter topology, or reject this packet.

**BLOCKING REVIEW DECISION AR-02:** Accept the bounded multi-signer callgraph:
at most 33 ordered participants, mixed EOA/ERC-1271 proofs, exactly two sides
for rotation, only request-bound signers as direct adapter-controlled external
targets, and all non-signer dependency reads kept registry-side.

**BLOCKING REVIEW DECISION AR-03:** Accept validation extraction for all 57
writes. A smaller selector set changes the candidate interface ID, byte-size
tradeoff, and registry/adapter audit boundary and requires a replacement
packet.

## Candidate Constants And Fixed Probes

Each value below is `keccak256` of the exact ASCII preimage.

| Constant | Exact preimage | Candidate value |
| --- | --- | --- |
| `ARTIST_REGISTRY_VALIDATION_ADAPTER_MARKER_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_ADAPTER_V1` | `0xaa8aa162210fdc2e9a4bb1a699c8ca727caa6e32678e485c3ca393ded0b8942f` |
| `ARTIST_REGISTRY_VALIDATION_SCHEMA_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_SCHEMA_V1` | `0x79bb8f9129afd2d202da49e0fd1b7989e53c315752c11c10a5a16414edfb87fc` |
| `ARTIST_REGISTRY_VALIDATION_DEPENDENCIES_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_DEPENDENCIES_V1` | `0x3c8dc77e31156b5173be953d6318b2ed2f7385fed0cc546f97b7c7a6c7554ac1` |
| `ARTIST_REGISTRY_VALIDATION_INTENT_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_INTENT_V1` | `0x9ec5b1e09aed7dfbcea902df5b082256071bd6c98268111c9c3007bf154a16e4` |
| `ARTIST_REGISTRY_VALIDATION_OBSERVATIONS_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_OBSERVATIONS_V1` | `0xd5835935f8ae892842ce8d3bbc7cdbf26454812f2c2abf9a27675d66cd6d8920` |
| `ARTIST_REGISTRY_VALIDATION_RESULT_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_RESULT_V1` | `0x80973b34d65ec99ded29f2d7840b5b1fc129e41912f0298f3241ea368a529416` |
| `ARTIST_REGISTRY_VALIDATION_MAGIC_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_MAGIC_V1` | `0xe04bcf39e2e84f086ebf44b37096beeb7597e2df673b4c97ccfc20f9915ef2b5` |
| `ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1` | `0x1eddbd561e9bd9eb26cd6b9e19ebbfcdc94808c742f6a32f56cd702da252d04a` |
| `ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_V1` | `0x48477ab2fb17edcff85463270a97705efaba45d72f70e5f37d3d5add0cc05488` |
| `ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_CHAIN_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_CHAIN_V1` | `0x161c975cc642f7680061b276d2d7a11062ec67ca04c9bad95f2121ee59304f5f` |
| `ARTIST_REGISTRY_VALIDATION_EIP150_RESERVE_V1` | `6529STREAM_ARTIST_REGISTRY_VALIDATION_EIP150_RESERVE_V1` | `0xf28c4b5041a05e5148691cfe47726e171ba67f114f903d81767b4f869a8551df` |
| `ERC1271_SELECTOR_AND_MAGIC` | `isValidSignature(bytes32,bytes)` selector | `0x1626ba7e` |
| `GGP_ARTIST_ERC1271_VERIFY_GAS` | `6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS` | `0x04bd88d7a1b04a4fc7476b74a962c2fea893f8ad4e6711b1c13e828f151458b5` |

Candidate fixed probes:

| Probe | Selector | Exact return |
| --- | --- | --- |
| `supportsInterface(bytes4)` | `0x01ffc9a7` | one canonical 32-byte ABI boolean |
| `artistRegistryValidationAdapterMarker()` | `0x24a325eb` | the marker word above |
| `artistRegistryValidationAdapterSchema()` | `0x41995c51` | the schema word above |
| `dependencyBindingHash()` | `0x371b62f3` | the dependency binding below |

Construction executes these probes in this exact order after checking
`adapter != address(0)`, `adapter.code.length != 0`, and the expected live
`EXTCODEHASH`:

| Order | Exact calldata | Required exact 32-byte returndata |
| ---: | --- | --- |
| 1 | `0x01ffc9a701ffc9a700000000000000000000000000000000000000000000000000000000` | `0x0000000000000000000000000000000000000000000000000000000000000001` |
| 2 | `0x01ffc9a77cdddcdd00000000000000000000000000000000000000000000000000000000` | `0x0000000000000000000000000000000000000000000000000000000000000001` |
| 3 | `0x01ffc9a7ffffffff00000000000000000000000000000000000000000000000000000000` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| 4 | `0x24a325eb` | `0xaa8aa162210fdc2e9a4bb1a699c8ca727caa6e32678e485c3ca393ded0b8942f` |
| 5 | `0x41995c51` | `0x79bb8f9129afd2d202da49e0fd1b7989e53c315752c11c10a5a16414edfb87fc` |
| 6 | `0x371b62f3` | exact registry-computed dependency binding |

Probe 1 is ERC-165 true, probe 2 is the candidate versioned interface true,
and probe 3 is invalid-interface false. Each call is a zero-value
available-gas `STATICCALL`. The registry requires `success == true` and
`returndatasize() == 32` before copying exactly one word. It does not decode or
bubble any other returndata. No probe may be reordered, omitted, cached from a
different address, or satisfied through fallback-only behavior.

The candidate dependency binding has no fixed external dependency address:

```solidity
keccak256(abi.encode(
    ARTIST_REGISTRY_VALIDATION_DEPENDENCIES_V1,
    uint256(block.chainid),
    bytes4(ERC1271_SELECTOR_AND_MAGIC),
    bytes32(GGP_ARTIST_ERC1271_VERIFY_GAS),
    uint256(MAX_STORED_SIGNATURE_BYTES),
    bytes4(versionedAdapterInterfaceId),
    bytes32(ARTIST_REGISTRY_VALIDATION_ADAPTER_MARKER_V1),
    bytes32(ARTIST_REGISTRY_VALIDATION_SCHEMA_V1)
))
```

The bounded signer set is transition-specific. Every address and live runtime
code hash is bound in the ordered request and observation transcript, not in
the adapter's constructor dependency binding.

Construction probes use zero value and fixed calldata. Every validation call
uses zero value and a fixed canonical head with bounded variable tails. Both
use exact returndata length, bounded copy, canonical decoding, and no
returndata bubbling. Revert, out-of-gas, fallback-only success, short,
oversized, malformed, or noncanonical data fails closed.

**BLOCKING REVIEW DECISION AR-04:** Approve the eleven preimages and values, all
probe names/selectors, the exact six-probe construction order/calldata/results,
and the dependency-binding preimage. Probe 2 and both interface XORs must be
updated together if any candidate selector changes.

**BLOCKING REVIEW DECISION AR-05:** Approve the chain-specific dependency
binding with no fixed external address and a transition-bound ordered signer
set, or pin a different immutable dependency model.

## Shared Candidate Request

Every dedicated entry begins with this exact candidate 23-word ABI tuple:

```solidity
struct ValidationContextV1 {
    address registry;                 // word 0
    address core;                     // word 1
    address adapter;                  // word 2
    bytes32 adapterCodeHash;          // word 3
    bytes32 dependencyBindingHash;    // word 4
    bytes32 currentStateDigest;       // word 5
    bytes32 replayStateDigest;        // word 6
    bytes32 governanceActionId;       // word 7
    bytes32 governanceScopeHash;      // word 8
    bytes32 governanceOldStateHash;   // word 9
    bytes32 governanceNewStateHash;   // word 10
    address authenticatedCaller;      // word 11
    address primarySigner;            // word 12
    bytes32 signerSetHash;             // word 13
    uint256 primaryNonce;              // word 14
    uint64 primaryDeadline;            // word 15
    uint64 primarySignedAt;            // word 16
    uint256 erc1271GasCap;            // word 17
    uint64 erc1271GasRevision;         // word 18
    uint32 capabilityMask;             // word 19
    uint8 authorityClass;              // word 20
    uint8 governanceActionClass;       // word 21
    bytes4 registryWriteSelector;      // word 22
}
```

Each entry then receives one fixed `bytes32[24] fields` bank. The dedicated
selector, not an operation enum, assigns the meaning of each field. Every
unused field must be zero. The registry locally constructs and hashes the same
field bank and compares the returned transcript. A selector may not accept a
field assigned to another selector.

Context rules:

- `registry`, `core`, `adapter`, adapter code hash, dependency binding,
  interface, marker, schema, entry selector, and registry write selector are
  included in the full-intent digest.
- Addresses must have zero upper 96 bits; small integers, enums, `bytes4`, and
  masks must have zero unused upper bits.
- Governance words are all zero for non-governance operations.
- Signature words are all zero for operations with no artist-side signer.
- For signed or direct-authority operations, `primarySigner` is the first
  canonical participant, `signerSetHash` commits the complete ordered proof
  bundle, and the three primary nonce/time words echo participant zero.
- `erc1271GasCap` and `erc1271GasRevision` are zero only when the ordered proof
  bundle contains no ERC-1271 participant. Mixed EOA/ERC-1271 bundles carry the
  one live registry-owned cap/revision applied independently at every contract
  signer call.
- `primaryDeadline` is zero for long-lived `signedAt` payloads and for unsigned
  registry-only transitions.
- `primarySignedAt` and every per-participant timestamp are never inferred by
  the adapter. The registry authenticates their source and commits them.

**BLOCKING REVIEW DECISION AR-06:** Approve the exact 23-word context, types,
word order, zero rules, and the 24-word per-selector field-bank pattern.

**BLOCKING REVIEW DECISION AR-07:** Publish and independently approve a
separate complete field-mask table assigning every used `fields[0..23]` word
for every selector below. This document intentionally does not invent those
57 operation-specific semantic assignments.

**BLOCKING REVIEW DECISION AR-08:** Pin exact `currentStateDigest` and
`replayStateDigest` preimages for every operation, including all binding,
collaborator, authority, provisional/superseded-record, nonce, digest-
revocation, imported-lane, and cutover facts consumed by the transition.

**BLOCKING REVIEW DECISION AR-09:** Pin whether each deadline-bearing record's
stored `signedAt` is a separately signed field or the registry-observed
submission timestamp, and pin the direct-call timestamp rule. The current
specification mixes deadline-bearing typed payloads with record/event
`signedAt` fields and cannot be frozen by assumption.

### Ordered signer-proof bundle

Every family described as carrying a signature instead carries one exact
`bytes signerProofBundle`, whose bytes are candidate-canonical
`abi.encode(ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1, proofs)`:

```solidity
struct SignerProofV1 {
    uint32 participantIndex;
    address signer;
    bytes32 signerCodeHash;
    uint8 authorityClass;
    uint8 signatureMode; // 1 direct, 2 EOA, 3 ERC-1271
    uint256 nonce;
    uint64 deadline;
    uint64 signedAt;
    bytes signature;
}
```

Bundle rules:

- `1 <= proofs.length <= 33`; the maximum represents one primary plus the
  normative maximum 32 collaborators.
- `participantIndex` is strictly increasing and unique. For collaborator
  actions, index zero is the primary and indices `1..32` are the immutable
  stored collaborator-row positions plus one. The registry decides which
  indices must appear for `PRIMARY_ONLY`, `ALL_COLLABORATORS`, `THRESHOLD`, and
  `COLLABORATOR_QUORUM`.
- A one-authority operation requires exactly one proof at participant index
  zero.
- `rotateArtistAddress` requires exactly two proofs: old authority at index
  zero and new authority at index one. Either side may be direct, EOA, or
  ERC-1271 independently.
- At most one proof may use direct mode, its signer must equal
  `context.authenticatedCaller`, and its signature length is zero. The
  registry alone proves that `context.authenticatedCaller` was the original
  registry-call `msg.sender`; the adapter never authorizes from its own
  `msg.sender`. Every other participant uses EOA or ERC-1271 mode with
  nonempty signature bytes.
- EOA mode requires `signerCodeHash == 0` and exact live `signer.code.length ==
  0`. ERC-1271 mode requires a nonzero registry-authenticated code hash and an
  exact live adapter recheck. Direct mode's code hash follows the signer's
  actual EOA/contract class but performs no signature call.
- Duplicate participant indices, duplicate signer addresses, reordered
  proofs, surplus signers, omitted required signers, and a signer not linked
  to the registry-authenticated participant row fail before the adapter call.
- `signerSetHash` is
  `keccak256(abi.encode(ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1,
   participantIndex, signer, signerCodeHash, authorityClass, signatureMode,
  nonce, deadline, signedAt)...)` in proof order. Raw signature bytes, their
  length, and their hash are deliberately excluded so the authorization
  intent, typed-data digest, and normative record hashes are signature-
  representation independent. The exact flattened preimage must be published
  as a freeze vector rather than implemented from this ellipsis notation.

The registry validates the same count, ordering, identities, authority
classes, modes, code hashes, nonce/deadline/timestamp rules, per-signer
signature-byte bounds, and aggregate hashes before calling the adapter. The
adapter repeats all structural, canonical-ABI, code-hash, ECDSA, ERC-1271, and
digest checks. This intentional mirroring prevents a permissive registry ABI
decoder from using the adapter as its first bound or hash oracle.

**BLOCKING REVIEW DECISION AR-29:** Approve the exact `SignerProofV1` fields,
canonical bundle codec, participant-index vocabulary, 33-signer bound,
single-direct-participant rule, mixed EOA/ERC-1271 behavior, signer-set hash,
and per-operation required-participant policy. The displayed flattened hash
ellipsis is not implementation-authorizing; exact empty/direct/EOA/ERC-1271,
mixed, 32-collaborator, and two-sided-rotation vectors are still required.

## Candidate Selector Families

Let `C` denote the exact canonical tuple type:

```text
(address,address,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,
 bytes32,bytes32,address,address,bytes32,uint256,uint64,uint64,uint256,
 uint64,uint32,uint8,uint8,bytes4)
```

Whitespace above is illustrative; selector computation uses the canonical
one-line ABI type. Every family returns the fixed result defined later.

| Family | Canonical argument suffix after the dedicated function name | Purpose |
| --- | --- | --- |
| `F` | `(C,bytes32[24])` | fixed-only validation |
| `Q` | `(C,bytes32[24],bytes)` | one ordered signer-proof bundle |
| `U` | `(C,bytes32[24],string)` | one bounded reason/identity URI, no signature |
| `QU` | `(C,bytes32[24],bytes,string)` | one ordered signer-proof bundle and one bounded URI |
| `B` | `(C,bytes32[24],(address,bytes32,bytes32)[],(uint32,uint8,uint32)[],bytes,string,string,string)` | binding proposal: collaborators, capability overrides, identity document, display name, identity URI, reason URI |
| `CI` | `(C,bytes32[24],bytes,string,string,string)` | collaborator identity document, display name, identity URI, reason URI |
| `IR` | `(C,bytes32[24],bytes,string,string,bytes)` | revised identity document, display name, identity URI, signer-proof bundle |
| `G` | `(C,bytes32[24],address[],bytes)` | guardian set and signer-proof bundle |
| `R` | `(C,bytes32[24],bytes)` | exact two-participant old/new signer-proof bundle |
| `L` | `(C,bytes32[24],bytes32[],bytes)` | content lock classes and signer-proof bundle |
| `X` | `(C,bytes32[24],bytes32[],bytes)` | superseded record hashes and new-authority signer-proof bundle |
| `D` | `(C,bytes32[24],bytes,bytes)` | directive payload and signer-proof bundle |
| `M` | `(C,bytes32[24],(uint8,bytes32,uint64,bytes32,bytes32),bytes32[])` | import tip leaf and Merkle proof |

The completed packet analysis originally proposed `B` without the capability
override array. This draft adds `(uint32,uint8,uint32)[]` because
`ArtistBindingProposal` normatively includes sorted, disjoint
`CapabilityPolicyOverride[]` and the proposed extraction assigns bounded
ordering/mask validation to the adapter.

**BLOCKING REVIEW DECISION AR-10:** Approve the family grammar, including the
added capability-policy array in `B`, or choose registry-side validation and
regenerate the affected selector and interface ID.

**BLOCKING REVIEW DECISION AR-11:** Approve direct authorization only as a
mode-1 `SignerProofV1` row with empty inner signature bytes. The outer bundle
is never empty, and empty signature bytes in EOA or ERC-1271 mode are invalid.

**BLOCKING REVIEW DECISION AR-12:** Approve the same canonical ordered signer
bundle for one-signer, collaborator-policy, and rotation actions, including
per-signature offsets, duplicate rejection, participant ordering, authority-
class allocation, and maximum aggregate raw signature bytes.

**BLOCKING REVIEW DECISION AR-30:** Reconcile `displayName` normatively.
`ArtistIdentityRegistered` does not currently event `displayName`, while the
Permanent `artistDisplayName` read and identity requirements require an
operative mirror. This candidate adds `displayName` to `CI` and `IR`, as the
checkpoint already does for primary registration, but implementation remains
blocked until the specification pins whether every registration/revision
event carries the exact display string or only a committed hash plus the
state-carried identity document.

## Complete 57-Write Inventory And Candidate Mapping

`Present` means the frozen checkpoint contains a native mutator with that
name. It does not mean the implementation is conforming. `Absent` means the
normative write does not exist in that checkpoint.

Selectors below are candidate values computed from the dedicated
`validate<Name>V1` name and the family grammar above. After adding
`displayName` to `CI`/`IR` and replacing rotation's two independent `bytes`
arguments with one ordered two-participant bundle, the candidate validation-
entry XOR is `0x2efcc794`. Including the marker, schema, and dependency-binding
probes produces candidate versioned interface ID `0x7cdddcdd`;
`supportsInterface(bytes4)` is inherited and excluded from that XOR.

| # | Normative registry write | Checkpoint | Family | Candidate selector | Registry-only authority gate |
| ---: | --- | --- | --- | --- | --- |
| 1 | `proposeArtistBinding` | Present | `B` | `0xd413fdec` | `ROLE_ARTIST_REGISTRY_ADMIN`; corrective path also binds terminal arbiter approval |
| 2 | `acceptArtistBinding` | Present | `Q` | `0xbff12590` | exact proposed artist, direct or verified signature; no admin bypass |
| 3 | `refuseArtistBinding` | Absent | `QU` | `0x9f94e137` | exact proposed artist, direct or verified signature |
| 4 | `withdrawArtistBinding` | Absent | `U` | `0x55cc8780` | exact proposal author under the stored proposal |
| 5 | `proposeCollaboratorIdentity` | Absent | `CI` | `0xfb6d79d5` | `ROLE_ARTIST_REGISTRY_ADMIN` |
| 6 | `acceptCollaboratorIdentity` | Absent | `Q` | `0x8dd23f69` | exact named account, direct or verified signature |
| 7 | `acceptCollaborator` | Absent | `Q` | `0x50a122eb` | exact listed collaborator, direct or verified signature |
| 8 | `declarePlatformWorks` | Absent | `F` | `0xd483390f` | `ROLE_ARTIST_REGISTRY_ADMIN` before policy registration |
| 9 | `filePlatformWorksClaim` | Absent | `U` | `0x9f2ab3c0` | permissionless claimant; caller is permanently recorded |
| 10 | `fileAttributionClaim` | Absent | `U` | `0x2b9f95ab` | permissionless claimant; caller is permanently recorded |
| 11 | `setPlatformWorksContest` | Absent | `F` | `0xc4b983cc` | `ROLE_ATTRIBUTION_ARBITER` through exact staged Governance V2 context |
| 12 | `recordArtistSanction` | Present | `Q` | `0xb8cc3b3e` | artist/successor/steward/delegate under `CAP_SANCTION` and collaborator policy |
| 13 | `confirmSanctionFinalized` | Absent | `F` | `0x9c32b4f8` | permissionless truth confirmation against registry-authenticated finality facts |
| 14 | `recordPolicyConsent` | Present | `Q` | `0xcdaecafe` | consent-mode authority; delegate only where `ARTIST_DELEGATED`; collaborator policy |
| 15 | `recordEconomicsConsent` | Present | `Q` | `0x795e4001` | artist economics authority, designation prerequisites, collaborator policy |
| 16 | `recordSaleConsent` | Present | `Q` | `0x417c166a` | sale-consent authority; delegate only where permitted; collaborator policy |
| 17 | `recordContentConsent` | Present | `Q` | `0x6d52cdea` | content-consent authority under consent mode and collaborator policy |
| 18 | `recordPayoutDesignation` | Present | `Q` | `0x43fd541e` | `AUTH_ARTIST` or capable `AUTH_SUCCESSOR`; never delegate or steward |
| 19 | `recordStewardSanctionGrant` | Absent | `Q` | `0x8c4a56d2` | `AUTH_ARTIST` only |
| 20 | `authorizeArtistRoyaltyFreeze` | Present | `Q` | `0x63633323` | defensive royalty-freeze authority and collaborator policy |
| 21 | `authorizeArtistContentFreeze` | Present | `L` | `0x9e07a80c` | defensive content-freeze authority and collaborator policy |
| 22 | `recordRecoveryApproval` | Present | `Q` | `0x696ed9d5` | sanction-class authority; steward restricted to collection scope; collaborator policy |
| 23 | `recordUnavailabilityFinding` | Present | `F` | `0xfedbc352` | `ROLE_ATTRIBUTION_ARBITER` through delayed Governance V2 context |
| 24 | `recordArtistAttestation` | Absent | `Q` | `0x45001de2` | artist/successor/steward/delegate under `CAP_ATTEST`; collaborator policy where applicable |
| 25 | `recordIdentityRevision` | Absent | `IR` | `0x88ba1b08` | `AUTH_ARTIST` or capable `AUTH_SUCCESSOR`; never delegate or steward |
| 26 | `grantArtistDelegation` | Absent | `Q` | `0xfd29f33e` | artist authority only; nondelegable capability bits rejected |
| 27 | `revokeArtistDelegation` | Absent | `Q` | `0x37c7ed3b` | exact granting artist authority, direct or independently pinned signed revocation |
| 28 | `setArtistGuardians` | Absent | `G` | `0x8857dc0e` | artist/capable successor/steward; displacement requires the separate capability |
| 29 | `rotateArtistAddress` | Absent | `R` | `0x8de2d745` | current authority old-side evidence plus exact new-address acceptance |
| 30 | `approveArtistRotation` | Absent | `F` | `0x46f527b9` | direct registered guardian only |
| 31 | `vetoArtistRotation` | Absent | `F` | `0xd143916d` | direct guardian/current authority/designated successor/unrevoked prior address |
| 32 | `executeArtistRotation` | Absent | `F` | `0x4ff765e7` | permissionless after the window or after registry-counted guardian quorum |
| 33 | `contestArtistIdentity` | Absent | `F` | `0x46fef903` | guardian, unrevoked prior address, designated successor, or staged arbiter path |
| 34 | `vetoIdentityRecovery` | Absent | `F` | `0x81ab3e62` | direct eligible pre-transition guardian |
| 35 | `recoverArtistIdentity` | Absent | `X` | `0xee2e0831` | terminal-freeze arbiter action plus new-address acceptance and guardian-veto checks |
| 36 | `designateSuccessor` | Absent | `Q` | `0x2e8b0ad5` | `AUTH_ARTIST` only |
| 37 | `recordEstateDirective` | Absent | `D` | `0x55c714a4` | `AUTH_ARTIST` only |
| 38 | `requestEstateActivation` | Absent | `Q` | `0x219a1989` | exact operative successor, direct or verified signature |
| 39 | `cancelEstateActivation` | Absent | `F` | `0xdf4208c9` | living artist-side authority under the active request |
| 40 | `executeEstateActivation` | Absent | `F` | `0x405071c7` | permissionless after notice, or exact delayed governance accelerator |
| 41 | `initiateArtistDormancy` | Absent | `U` | `0x36857dd3` | `ROLE_ARTIST_DORMANCY_ADMIN` through staged Governance V2 context |
| 42 | `cancelArtistDormancy` | Absent | `F` | `0xa1d218c5` | authenticated artist/delegate/designated-successor liveness |
| 43 | `completeArtistDormancy` | Absent | `F` | `0x414e73ba` | second staged Governance V2 action after notice; contest checks |
| 44 | `openAttributionDispute` | Absent | `QU` | `0xe5faa2a1` | named standing: artist/successor/delegate/collaborator/prior artist or staged arbiter |
| 45 | `recordCounterStatement` | Absent | `QU` | `0xa3c13205` | disputed binding authority under `CAP_DISPUTE` and collaborator policy |
| 46 | `resolveAttributionDispute` | Absent | `F` | `0xd082de90` | staged arbiter Governance V2 action; terminal class where the spec requires |
| 47 | `revokeAttribution` | Absent | `QU` | `0xaeed9215` | bound artist-side repudiation authority and collaborator policy |
| 48 | `vetoAttributionRepudiation` | Absent | `F` | `0x252d66bd` | direct registered guardian |
| 49 | `cancelAttributionRepudiation` | Absent | `F` | `0xb0f5885f` | exact authority that staged the repudiation |
| 50 | `executeAttributionRepudiation` | Absent | `F` | `0xd61f0e0e` | permissionless after the contest window and all registry rechecks |
| 51 | `revokePriorAddressStanding` | Absent | `Q` | `0x8381ab55` | `AUTH_ARTIST` or capable `AUTH_SUCCESSOR`; never steward or delegate |
| 52 | `recordContentRatification` | Present | `Q` | `0x9f5e1872` | content-consent authority under consent mode and collaborator policy |
| 53 | `approvePlatformWorksCorrection` | Absent | `F` | `0x8b1b5cb4` | terminal-freeze `ROLE_ATTRIBUTION_ARBITER` Governance V2 action |
| 54 | `revokeArtistAuthorization` | Absent | `Q` | `0x798ea3ac` | exact identity authority; revocation remains identity-scoped |
| 55 | `commitArtistHistoryImportRoot` | Absent | `F` | `0x1910f961` | staged Governance V2 action on the successor registry |
| 56 | `verifyImportedLaneTip` | Absent | `M` | `0xf53d3e24` | permissionless truth verification; Core and predecessor reads stay registry-side |
| 57 | `observeRegistryCutover` | Absent | `F` | `0x8d630c57` | permissionless one-way truth observation |

The candidate selectors are meaningful only as one indivisible candidate set.
Changing any name, type, tuple order, family, or the `B` capability-policy
array changes the affected selector and both XOR values.

**BLOCKING REVIEW DECISION AR-13:** Independently regenerate and approve all 57
canonical signatures and selectors, validation-entry XOR `0x2efcc794`, full
interface ID `0x7cdddcdd`, and the rule that marker/schema/dependency probes
are included while inherited ERC-165 is excluded.

**BLOCKING REVIEW DECISION AR-14:** Pin the signed revocation payload for
`revokeArtistDelegation`. The normative text permits a verified signature but
does not publish a distinct delegation-revocation typehash.

**BLOCKING REVIEW DECISION AR-33:** Pin the signed refusal payload for
`refuseArtistBinding`. The normative text permits the named artist to refuse,
and this candidate carries a signer bundle, but no refusal-specific typehash
or authorized reuse of `StreamArtistAcceptance` is published. Acceptance and
refusal must not share an ambiguous signed digest.

**BLOCKING REVIEW DECISION AR-15:** Pin the exact registry write signatures and
selectors carried in `registryWriteSelector`. The normative specification
allows implementation-tuned write structs, so names alone are insufficient.

## Candidate EIP-712 And Signature-Independent Freeze Artifacts

Every signed proof uses the registry's one normative EIP-712 domain. The
candidate construction is exact:

```solidity
domainSeparator = keccak256(abi.encode(
    bytes32(0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f),
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32(0xf598bd397eb1358772013bea6e869e4f30d34b382f011690ecba0449911c2c06),
    // keccak256("6529StreamArtistRegistry")
    bytes32(0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6),
    // keccak256("1")
    uint256(block.chainid),
    address(registry)
));

structHash = keccak256(abi.encode(
    operationTypehash,
    // the operation's exact typed fields, types, and order
));

signedDigest = keccak256(abi.encodePacked(
    bytes2(0x1901),
    domainSeparator,
    structHash
));
```

For the two existing dynamic-array payloads, the value placed in the
`structHash` preimage is the EIP-712 array hash, not an ABI offset:
`keccak256(abi.encodePacked(bytes32(uint256(uint160(guardian_0))), ...))` for
`address[] guardians`, and `keccak256(abi.encodePacked(lockClass_0, ...))` for
`bytes32[] lockClasses`, in the same already-validated order. Empty arrays use
`keccak256("")`. No other array convention is implied.

The current normative typehash assignment for every candidate selector that
can consume a signed proof is:

| Registry write | Exact typehash assignment for signed mode |
| --- | --- |
| `acceptArtistBinding` | `STREAM_ARTIST_ACCEPTANCE_TYPEHASH` = `0x863408883ac6994b06f1a735545fd486c6a1a53866fb8851488d56d1b54f92af` |
| `refuseArtistBinding` | **gap: no pinned refusal typehash** |
| `acceptCollaboratorIdentity` | `STREAM_COLLABORATOR_IDENTITY_ACCEPTANCE_TYPEHASH` = `0x9a40f74dcb1bb82d3fa4b33ed2dedc82fab75d7dd6c4b04f86cf263a0b867380` |
| `acceptCollaborator` | `STREAM_COLLABORATOR_ACCEPTANCE_TYPEHASH` = `0x636ddaeeea1f3879203e4707eba02a65484041c3869c8a04560af9a57886343b` |
| `recordArtistSanction` | `STREAM_ARTIST_SANCTION_TYPEHASH` = `0x0651c04c186a25456f0dc9ca0a4a29a5537f2aeb0fe7e69cb2d3d202b41549b3` |
| `recordPolicyConsent` | `STREAM_ARTIST_POLICY_CONSENT_TYPEHASH` = `0xbb408425c14bb658b72c5c6d190446d6d3cce65e6cb127239882bff780982c2b` |
| `recordEconomicsConsent` | `STREAM_ARTIST_ECONOMICS_CONSENT_TYPEHASH` = `0x38c2c794170472cc1bbd6385664d7d8a409ce16455caa0db97392b80fbc4b434` |
| `recordSaleConsent` | `STREAM_ARTIST_SALE_CONSENT_TYPEHASH` = `0x5a0d2fee9c2248ad2b0735d54beb28b1decdd1adeb65c63c4016da70ec399045` |
| `recordContentConsent` | `STREAM_ARTIST_CONTENT_CONSENT_TYPEHASH` = `0x7908964dc70554ffd5c82353690255d1a8c338be77ffc0f8fb925a27d890587d` |
| `recordPayoutDesignation` | `STREAM_ARTIST_PAYOUT_DESIGNATION_TYPEHASH` = `0xfd30c946c20c3c9415f06991c291231ff12c255c9cc849164de44f91cb72c213` |
| `recordStewardSanctionGrant` | `STREAM_STEWARD_SANCTION_GRANT_TYPEHASH` = `0xb48c9f264543966930485ab31e707d91b18c4f9e8644f8dd4a8cbb38c2aea9f2` |
| `authorizeArtistRoyaltyFreeze` | `STREAM_ARTIST_ROYALTY_FREEZE_TYPEHASH` = `0x34f54304a829e6bd32c4bcd8d63f31f7652adf9d1d653b874107a0a93eee73c4` |
| `authorizeArtistContentFreeze` | `STREAM_ARTIST_CONTENT_FREEZE_TYPEHASH` = `0xfcb15d96b29996a5852bf06058ae82a7e8acaf7d7601b13fe881ada5d30fc63b` |
| `recordRecoveryApproval` | `STREAM_ARTIST_RECOVERY_APPROVAL_TYPEHASH` = `0x242bffdf15416a6743c57bd362683aa2933edcd42a4ef176f4e983a745eee511` |
| `recordArtistAttestation` | `STREAM_ARTIST_ATTESTATION_TYPEHASH` = `0x74b9521f5d5caa162fb97b3a7f8e6aa5352156e3a1ff7c8e8103092eaaeaaa08` |
| `recordIdentityRevision` | `STREAM_ARTIST_IDENTITY_REVISION_TYPEHASH` = `0xbfb7a5d3bc248c8eefbe4f8dfc2ea7d75d18c5cb3f2ab0d56000fd87f4b58603` |
| `grantArtistDelegation` | `STREAM_ARTIST_DELEGATION_TYPEHASH` = `0x259b01d4bf9aa04d6f900a2f85548eebdbb07661fdf1eac68031895cadae6d0d` |
| `revokeArtistDelegation` | **gap: no pinned delegation-revocation typehash** |
| `setArtistGuardians` | `STREAM_ARTIST_GUARDIAN_SET_TYPEHASH` = `0x397aa6a887bb93367eab618ebf56732031f29da75f932c71ea556746542ebafe` |
| `rotateArtistAddress`, old side | `STREAM_ARTIST_KEY_ROTATION_TYPEHASH` = `0x5b4e68760703787cefafa5c70864d397b1de70e70818739680256a123fe7a184` |
| `rotateArtistAddress`, new side | `STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH` = `0x87eea3b0d5e1275bbdc74e691b4e19a12e9e76b634bac03ae439ae584859ecd0` |
| `recoverArtistIdentity`, new side | `STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH` above |
| `designateSuccessor` | `STREAM_ARTIST_SUCCESSOR_DESIGNATION_TYPEHASH` = `0x978b9dfcca0968239ea043e735357728a9489fe40067fea6673256206c83de15` |
| `recordEstateDirective` | `STREAM_ARTIST_ESTATE_DIRECTIVE_TYPEHASH` = `0xa1f146b360069294c6453e91242bb36bb0245545d57b3c89e1cc73c25e953d31` |
| `requestEstateActivation` | `STREAM_ARTIST_ESTATE_ACTIVATION_TYPEHASH` = `0x35ad5d0278eb067119334d7d4fddd596cad723598851900a95e6ad9a94e51a8a` |
| `openAttributionDispute`, signed path | `STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH` = `0x8b535108c442947650eb1dec541e1e10f715f240a1554e488f2d4a51afb31541`, `disputeAction = 1` |
| `recordCounterStatement` | the same dispute typehash, `disputeAction = 3` |
| `revokeAttribution` | the same dispute typehash, `disputeAction = 4` |
| `revokePriorAddressStanding` | `STREAM_ARTIST_STANDING_REVOCATION_TYPEHASH` = `0xc3782eba55027b9bef1f60b09cfbcfa48bbd834194f743ae92029711ae18f936` |
| `recordContentRatification` | `STREAM_ARTIST_CONTENT_RATIFICATION_TYPEHASH` = `0x56c622946d6da26c6684a8bfd94e3142562ae44e7da904bebe454f049c01b1f5` |
| `revokeArtistAuthorization` | `STREAM_ARTIST_AUTHORIZATION_REVOCATION_TYPEHASH` = `0xd1d93f1d81c2c2b5353543093ebfca89c460de55b540dfed4a019c7ac448f214` |

The other 27 candidate selectors have no EIP-712 payload. Their operation
matrix entry must be `NONE`, with all signature-only context/result fields
zero. A governance or permissionless branch of a selector listed above also
uses no typed payload; if it carries a direct mode-1 proof, that proof is an
authenticated-caller transcript and never fabricates a `structHash` or
`signedDigest`.

Typed-data, intent, and normative record preimages are signature-independent.
The exact typehash string and typed values determine `structHash`; no raw
signature, signature length, signature hash, recovery result, ERC-1271 return,
or bundle-storage pointer enters it. Likewise every `primaryRecordHash` or
`secondaryRecordHash` is the exact applicable `AA-DOMAINS` record preimage and
never contains signature bytes. Raw signatures enter only
`dynamic1Hash`, the ordered signer-observation transcript, and the separately
stored `signatureBundle(recordHash)` evidence (or an approved archival
bundle-hash/reference exception). `fullIntentDigest` binds `signerSetHash` but
not `dynamic1Hash`, so 64-byte and 65-byte canonical representations of the
same authorization do not create different intent or record identities.

**BLOCKING REVIEW DECISION AR-31:** Publish and independently approve one
57-row freeze matrix. Each row must name: exact typehash constant, string and
value (or `NONE`); domain-separator preimage; every `structHash` field/type/
order and array hash; exact `signedDigest`; direct/governance branch rules;
signature-independent primary/secondary record-domain preimages; signature
evidence pointer/hash rules; and exact event topics/data. Resolve the refusal
and delegation-revocation gaps before implementation. The assignment table
above is an audit map, not a substitute for those executable vectors.

## Canonical Dynamic ABI Candidate

For every family containing dynamic arguments, the adapter performs a manual
canonicality check before semantic validation:

1. The first tail starts exactly at the end of the fixed ABI head.
2. Every offset is a minimal 32-byte-aligned offset to the next tail in
   declared argument order.
3. Tails are contiguous: no overlap, alias, gap, backward offset, or
   out-of-order tail.
4. Each byte/string tail is `length || data || zero right-padding`.
5. Each static-element array tail is
   `count || element[0] || ... || element[count-1]` with canonical words.
6. Nested tuple-array elements contain no offsets because every approved
   element is static.
7. Checked arithmetic proves `offset + 32 + paddedLength` and every
   multiplication cannot overflow.
8. The computed end of the last tail equals `calldatasize()` exactly. Trailing
   data is rejected.
9. Every address, enum, bool, small integer, and fixed byte word is canonical.
10. Dynamic input length never affects returndata length.

The registry performs the same raw-calldata walk before calling the adapter.
It does not treat Solidity's high-level ABI decoder or an adapter revert as
its first bound. In particular, the registry independently checks every
length, offset, count, canonical word, sort/uniqueness rule, aggregate raw-
signature bound, and operation maximum; computes every dynamic hash and the
signer-set hash locally; and compares those values to its locally constructed
context and field bank before the external call.

For exact-length review, let:

```text
P(x)   = 32 * ceil(x / 32)
T(x)   = 32 + P(x)                 // bytes or string tail
A_w(n) = 32 + (32 * w * n)        // n static tuples of w words
```

All root offsets below are measured from the first byte after the four-byte
selector. `H` is the root-head word count. Candidate canonical formulas are:

| Family | `H` | First/root tail offsets and exact total calldata length |
| --- | ---: | --- |
| `F` | 47 | no tail; `4 + 47*32 = 1,508` |
| `Q`, `U`, `R` | 48 | offset `1,536`; total `4 + 1,536 + T(x0)` |
| `QU`, `G`, `L`, `X`, `D` | 49 | offsets `1,568`, `1,568 + S0`; total `4 + 1,568 + S0 + S1` |
| `B` | 53 | first offset `1,696`; each later offset is `1,696` plus the cumulative preceding tail sizes; total `4 + 1,696 + A_3(nCollaborators) + A_3(nOverrides) + T(identityBytes) + T(displayNameBytes) + T(identityURIBytes) + T(reasonURIBytes)` |
| `CI` | 51 | first offset `1,632`; cumulative declared-order offsets; total `4 + 1,632 + T(identityBytes) + T(displayNameBytes) + T(identityURIBytes) + T(reasonURIBytes)` |
| `IR` | 51 | first offset `1,632`; cumulative declared-order offsets; total `4 + 1,632 + T(identityBytes) + T(displayNameBytes) + T(identityURIBytes) + T(signerBundleBytes)` |
| `M` | 53 | proof offset `1,696`; total `4 + 1,696 + A_1(nProofWords)` |

For the two-tail row, `S0/S1` in declared order are: `QU = T(bundle) /
T(uri)`, `G = A_1(guardians) / T(bundle)`, `L` and `X = A_1(words) /
T(bundle)`, and `D = T(directive) / T(bundle)`. The one-tail row uses
`T(bundle)` for `Q` and `R`, and `T(uri)` for `U`. These formulas make the
`displayName` additions to `CI` and `IR` part of the ABI freeze rather than an
event-only convention.

For `signerProofBundle = abi.encode(domain, proofs)`, let `n` be the proof
count and `s_i` each raw signature length. The inner byte length is exactly:

```text
96 + 32*n + sum(i=0..n-1, 320 + P(s_i))
```

The outer `bytes` tail therefore has size `T(innerLength)`. Within the inner
encoding the top-level proof-array offset is `64`; after the array's count
word, element `i`'s offset is `32*n` plus all preceding encoded element
lengths, measured from the first element-offset word; and each element's
signature offset is exactly `288`. Count zero, a different top offset,
nonminimal element or signature offsets, aliased elements or signatures,
nonzero padding, or bytes remaining after the last signature fails in both
registry and adapter.

Candidate dynamic hashes:

```solidity
dynamic0Hash = keccak256(abi.encode(
    validationEntrySelector,
    // exact lengths and keccak256 values of all non-signature
    // dynamic arguments in declared order
));

dynamic1Hash = keccak256(abi.encode(
    validationEntrySelector,
    // exact lengths and keccak256 values of every signature or
    // signature-bundle argument in declared order
));
```

When a category is absent, its returned hash is zero rather than the Keccak of
an empty tuple.

The following `[AA-LIMITS]` maxima are already normative and are candidates for
the adapter and registry to enforce identically:

| Dynamic input | Maximum |
| --- | ---: |
| collaborators | 32 |
| guardians | 8 |
| guardian `minContestSeconds` | 2,592,000 seconds |
| content-freeze lock classes | 16 |
| stored signature bytes | 4,096 bytes |
| directive payload | 8,192 bytes |
| identity document | 8,192 bytes |
| identity-record URI | 2,048 bytes |
| display name | 256 bytes |
| reason URI | 2,048 bytes |

Additional canonical semantic rules:

- collaborator rows are strictly sorted by
  `(account, role, shareLabelId)`, all accounts are nonzero, and duplicate
  `(account, role)` pairs are rejected;
- capability-policy rows are strictly sorted by nonzero `capabilityMask`,
  masks are disjoint, enum and threshold values are canonical, and empty is
  permitted;
- guardians are strictly ascending, unique, and nonzero; an empty set requires
  threshold zero, while a nonempty set requires
  `1 <= threshold <= guardians.length`;
- lock classes and superseded record hashes are strictly ascending, unique,
  and nonzero;
- Merkle proof elements are canonical `bytes32` values and use the sorted-pair,
  double-hashed-leaf construction owned by `[AA-IMPORT]`;
- identity-document and display-name bytes are nonempty in this candidate;
- every hash that the owning normative requirement says must be nonzero is
  checked per selector, never globally; and
- the adapter returns only aggregate dynamic hashes, never dynamic data.

**BLOCKING REVIEW DECISION AR-16:** Pin whether empty identity-record URI,
reason URI, display name, identity bytes, directive bytes, signature, guardian
set, collaborator set, capability-policy set, lock-class set, supersession
set, and Merkle proof are legal for each selector. The candidate rejects empty
identity/display bytes, never permits an empty outer signer bundle on a family
that carries one, permits empty inner signature bytes only for its single
mode-1 direct row, permits empty collaborator/capability/guardian arrays only
with their zero-policy fields, and otherwise defers to the per-operation mask.

**BLOCKING REVIEW DECISION AR-17:** Pin a maximum capability-policy override
count. `[AA-LIMITS]` bounds collaborators but not this array.

**BLOCKING REVIEW DECISION AR-18:** Pin maxima for recovery supersession hashes
and history Merkle-proof words. The engineering handoff proposed 64 words for
each, but the normative specification currently provides no bound.

**BLOCKING REVIEW DECISION AR-19:** Pin the oversized-signature archival-proof
exception. `[AA-SIGVER]` permits a bundle over 4,096 bytes when accompanied by
a dual-family archival proof, but it is unclear whether 4,096 is per signer or
the aggregate 33-participant bundle and no exact adapter calldata, aggregate
raw/encoded bound, proof bound, stored prefix/hash rule, or signature-
verification transport is frozen.

**BLOCKING REVIEW DECISION AR-20:** Approve `dynamic0Hash` and `dynamic1Hash`
as ordered aggregate hashes, and publish their exact per-family preimages.
Also independently regenerate every root and nested offset and exact-length
formula above, including maximum-size and overflow vectors; high-level ABI
decode success is not sufficient evidence of canonicality.

## Fixed 512-Byte Candidate Result

Every validation entry returns exactly 16 canonical ABI words, or 512 bytes:

```solidity
struct ValidationResultV1 {
    bytes32 magic;                 // word 0
    bytes32 fullIntentDigest;      // word 1
    bytes32 observationsDigest;    // word 2
    bytes32 resultDigest;          // word 3
    bytes32 primaryRecordHash;     // word 4
    bytes32 secondaryRecordHash;   // word 5
    bytes32 dynamic0Hash;          // word 6
    bytes32 dynamic1Hash;          // word 7
    bytes32 signerSetHash;         // word 8
    address primarySigner;         // word 9
    uint256 primaryNonce;          // word 10
    uint64 primarySignedAt;        // word 11
    uint8 primaryAuthorityClass;   // word 12
    uint8 resultFlags;             // word 13
    bytes32 reserved0;             // word 14
    bytes32 reserved1;             // word 15
}
```

Candidate result flags:

| Bit | Candidate meaning |
| ---: | --- |
| 0 | one or more cryptographic signatures were verified |
| 1 | one or more EOA proofs were verified |
| 2 | one or more ERC-1271 proofs were verified |
| 3 | the accepted bundle contains more than one participant |
| 4 | one direct-call proof was accepted |
| 5 | the two distinct old/new rotation typed payloads were verified |
| 6-7 | zero, reserved |

Mutually incompatible flag combinations are rejected. All unassigned bits and
both reserved words are zero. Bit 5 requires exactly two participants and bit
3; bit 0 is set if and only if bit 1 or bit 2 is set; and bit 4 is compatible
with at most one direct-mode participant row. Unused record hashes, dynamic
hashes, signer-set hash, primary signer, primary nonce, primary timestamp, and
primary authority fields are zero per the approved operation mask.

Candidate full-intent digest:

```solidity
keccak256(abi.encode(
    ARTIST_REGISTRY_VALIDATION_INTENT_V1,
    uint256(block.chainid),
    context.registry,
    context.core,
    context.adapter,
    context.adapterCodeHash,
    bytes4(versionedAdapterInterfaceId),
    ARTIST_REGISTRY_VALIDATION_ADAPTER_MARKER_V1,
    ARTIST_REGISTRY_VALIDATION_SCHEMA_V1,
    context.dependencyBindingHash,
    bytes4(validationEntrySelector),
    context.registryWriteSelector,
    context.authenticatedCaller,
    context.primarySigner,
    context.signerSetHash,
    context.primaryNonce,
    context.primaryDeadline,
    context.primarySignedAt,
    context.erc1271GasCap,
    context.erc1271GasRevision,
    context.capabilityMask,
    context.authorityClass,
    context.governanceActionClass,
    context.governanceActionId,
    context.governanceScopeHash,
    context.governanceOldStateHash,
    context.governanceNewStateHash,
    context.currentStateDigest,
    context.replayStateDigest,
    keccak256(abi.encode(fields)),
    dynamic0Hash,
    context.signerSetHash
))
```

`dynamic1Hash` is deliberately absent from `fullIntentDigest`: it commits the
exact signature-evidence transport, while `signerSetHash` commits the
signature-independent ordered authorization intent. It remains committed by
the observations and result digests.

Candidate ordered signer observations:

```solidity
signerObservation_i = keccak256(abi.encode(
    ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_V1,
    fullIntentDigest,
    bytes4(validationEntrySelector),
    uint32(i),
    proof.participantIndex,
    proof.signer,
    proof.signerCodeHash,
    proof.authorityClass,
    proof.signatureMode,
    proof.nonce,
    proof.deadline,
    proof.signedAt,
    signedDigest_i,
    signatureHash_i,
    perSignerGasCap_i,
    perSignerGasRevision_i,
    recoveredSigner_i,
    bool(erc1271CallSuccess),
    uint256(erc1271ReturnSize),
    bytes32(erc1271ReturnWord)
));

observationChain_0 = bytes32(0);
observationChain_i_plus_1 = keccak256(abi.encode(
    ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_CHAIN_V1,
    uint32(i),
    observationChain_i,
    signerObservation_i
));

observationsDigest = keccak256(abi.encode(
    ARTIST_REGISTRY_VALIDATION_OBSERVATIONS_V1,
    fullIntentDigest,
    bytes4(validationEntrySelector),
    signerSetHash,
    uint32(proofCount),
    uint32(eoaCount),
    uint32(erc1271Count),
    uint32(directCount),
    observationChain_n,
    dynamic1Hash,
    aggregateReserveCommitment
));
```

`signedDigest_i` is zero only for a direct or non-EIP-712 authority row.
`signatureHash_i` is zero only for direct mode; otherwise it is
`keccak256(proof.signature)`. `perSignerGasCap_i`,
`perSignerGasRevision_i`, and all ERC-1271 call observations are zero outside
ERC-1271 mode. `recoveredSigner_i` is populated only for EOA mode. On the
ERC-1271 path, the adapter accepts only successful `STATICCALL`, exact 32-byte
returndata, and canonical ABI bytes whose leading `bytes4` equals
`0x1626ba7e` and whose remaining bytes are zero.

Candidate result digest:

```solidity
keccak256(abi.encode(
    ARTIST_REGISTRY_VALIDATION_RESULT_V1,
    bytes4(validationEntrySelector),
    ARTIST_REGISTRY_VALIDATION_MAGIC_V1,
    fullIntentDigest,
    observationsDigest,
    primaryRecordHash,
    secondaryRecordHash,
    dynamic0Hash,
    dynamic1Hash,
    signerSetHash,
    primarySigner,
    primaryNonce,
    primarySignedAt,
    primaryAuthorityClass,
    resultFlags,
    bytes32(0),
    bytes32(0)
))
```

The registry independently recomputes all three digests and compares every
word. It requires `returndatasize() == 512` before a fixed 512-byte copy.
Empty, short, oversized, malformed, noncanonical, wrong-magic, wrong-intent,
wrong-observation, wrong-result, wrong-field, or nonzero-reserved data fails
before any durable write or event.

**BLOCKING REVIEW DECISION AR-21:** Approve the exact 16-word result, the
512-byte invariant, multi-signer flag assignments, zero rules, per-signer
observation, ordered fold, and three aggregate digest preimages. Publish exact
one-, two-, and 33-participant response vectors.

**BLOCKING REVIEW DECISION AR-22:** Pin the per-operation meaning of
`primaryRecordHash` and `secondaryRecordHash`, including transitions that
create no record, create a state-change record plus an authority record, or
supersede multiple records.

**BLOCKING REVIEW DECISION AR-23:** Pin whether ERC-1271 accepts exactly the
standard ABI 32-byte word `0x1626ba7e` followed by 28 zero bytes, as proposed,
or another exact standard-compatible shape. Empty, 4-byte, short, and
extra-length returns remain rejected in either case.

## Signature And GGP Rules

EOA signatures:

- only canonical 65-byte `(r,s,v)` and 64-byte EIP-2098 forms are candidates;
- recovered signer must be nonzero and equal the registry-authenticated
  signer;
- `s` must not exceed the secp256k1 half order;
- `v` must be exactly 27 or 28 after EIP-2098 expansion; and
- the exact raw signature hash enters only the per-signer observation and
  `dynamic1Hash`; the full intent and normative record hashes remain
  signature-representation independent.

Contract signatures:

- the registry authenticates the signer address, live signer code hash,
  GGP value, and GGP revision before the adapter call;
- the adapter rechecks exact live signer `EXTCODEHASH`;
- the adapter calls only
  `isValidSignature(bytes32,bytes)` on that signer;
- each contract signer receives exactly the same request-authenticated
  `erc1271GasCap`, independently; there is no shared first-come gas pool;
- the call is zero-value `STATICCALL`, with the exact typed digest and
  bounded signature bytes;
- parent gas is checked with overflow-safe EIP-150 arithmetic before the
  call; and
- missing code, code drift, failure, out-of-gas, malformed returndata, wrong
  magic, callback attempt, or transcript mismatch fails closed.

GGP allocation:

- `StreamArtistRegistry` remains the only GGP host and reader.
- The parameter remains exactly `ARTIST_ERC1271_VERIFY_GAS`, identifier
  `0x04bd...58b5`, failure class `FAIL_CLOSED_PRECHECK`, planning floor
  90,000, and planning genesis value 150,000.
- The adapter has no GGP storage, getter, raise entry, authority, or alternate
  cap.
- The registry-to-adapter call forwards available gas and is not a GGP.
- No fixed adapter-call cap, caller-selected cap, new twenty-third GGP,
  overloaded GGP, probe, lower, emergency, conditional, or rebind path is
  permitted.
- Issue #684 must bind the live candidate host instance, floor, genesis value,
  raise chain, fixed-stipend compatibility, cold/worst-wallet measurement,
  and exact reserve evidence. This packet does not mark that row complete.

The current checkpoint's `gasleft() >= gasCap * 64 / 63 + 10_000` expression
is not frozen evidence for the adapter topology.

The multi-signer candidate requires a reverse-composed reserve, not a
one-call check. Define overflow-safe:

```text
ceil64_63(x) = x + floor(x / 63) + (x % 63 == 0 ? 0 : 1)
```

Let `tail_n` be the measured adapter finish/encode/return reserve after the
last participant. Walking proofs from `n-1` to zero:

```text
ERC1271:
  tail_i = measuredStepOverhead_i
         + max(ceil64_63(erc1271GasCap),
               erc1271GasCap + tail_i_plus_1)

EOA:
  tail_i = measuredStepOverhead_i
         + max(ceil64_63(measuredEcrecoverCallGas),
               measuredEcrecoverCallGas + tail_i_plus_1)

DIRECT:
  tail_i = measuredStepOverhead_i + tail_i_plus_1
```

`measuredStepOverhead_i` covers the cold/warm account state actually promised,
calldata and memory expansion at the maximum applicable signature size,
code-hash check, hashing, count/fold work, call opcode cost, and checked-
arithmetic margin, but excludes the separately named callee allowance. The
implementation must precompute the complete reverse reserve before the first
signer call and reject if it cannot be represented or `gasleft()` is below
the exact required boundary. It may not optimistically check each signer only
when reached.

Let `adapterNeed = tail_0` plus measured entry/canonical-ABI work before the
first proof. The registry's available-gas adapter boundary similarly requires:

```text
registryRequiredBeforeAdapter =
    measuredRegistryCallOverhead
  + max(ceil64_63(adapterNeed),
        adapterNeed + measuredRegistryPostValidationGas)
```

The post-validation term includes exact 512-byte copy/compare, all remaining
internal validation, durable writes, record/payload/signature effects, events,
lock release, and return for the heaviest selector. A failure path has a
separately measured sufficient revert reserve. Arithmetic must remain safe for
33 participants and the largest permitted bundle.

The adapter commits the exact calculation as:

```solidity
aggregateReserveCommitment = keccak256(abi.encode(
    ARTIST_REGISTRY_VALIDATION_EIP150_RESERVE_V1,
    bytes4(validationEntrySelector),
    signerSetHash,
    erc1271GasCap,
    erc1271GasRevision,
    proofCount,
    keccak256(abi.encode(orderedModes)),
    keccak256(abi.encode(orderedSignatureLengths)),
    signerStepConstantsDigest,
    adapterFinishReserve,
    adapterNeed,
    registryBoundaryConstantsDigest,
    measuredRegistryPostValidationGas,
    registryRequiredBeforeAdapter
));
```

The registry recomputes this value from the same frozen measurement artifact.
No constants named in this formula currently have approved measurements, so
the formula is a review shape, not executable authorization.

**BLOCKING REVIEW DECISION AR-24:** Approve measured overflow-safe EIP-150
reverse-composed reserves for the registry-to-adapter available-gas boundary
and every ordered adapter-to-signer boundary. Freeze fork/compiler settings,
all mode- and size-dependent overheads, 1/2/33-participant mixed vectors,
failure-path reserve, both constants digests, and the aggregate commitment.
The `+10_000` checkpoint constant and a per-call-only check are not accepted
by this packet.

**BLOCKING REVIEW DECISION AR-25:** Pin the exact authenticated source and ABI
for `erc1271GasRevision` and prove the adapter receives the same live GGP value
and revision that the registry used in its precheck.

**BLOCKING REVIEW DECISION AR-26:** Pin the canonical EOA/contract/direct
signature-mode rules for each of the 57 selectors, including two-sided
rotation and collaborator-policy bundles.

## Steward Sanction And Recovery Proof Packet

The adapter never decides steward reach and never reads Core or finality
state. For an `AUTH_STEWARD` `recordArtistSanction`, the registry must prove
and commit all of these facts before the adapter call:

- the authenticated signer is the identity's currently vested steward and the
  stored `stewardAppointedAtBlock` is nonzero;
- the effective, non-forbidden capability mask contains `CAP_SANCTION`, from
  either the operative, nonprovisional, non-superseded artist-signed steward
  sanction grant or a separately executed `TERMINAL_FREEZE` governance grant;
- `scopeType == COLLECTION == 0`, `tokenId == 0`, and `scopeId == 0`; token,
  release, season, view, and unknown scope values fail;
- the collection is the exact bound collection for the same `artistId` and
  binding generation; and
- the bound Core's live
  `collectionBurnsBlockedAtBlock(collectionId)` is nonzero and no greater than
  `stewardAppointedAtBlock`.

The registry includes the exact binding, vested-steward, appointment,
capability/grant, scope, Core address/code hash, burn-block activation height,
and burn-block one-way-state facts in `currentStateDigest` and the applicable
field-bank assignment. The adapter checks only that the supplied scalar scope
and proof commitments match the candidate operation mask. It may not turn
those committed facts into authority.

For an `AUTH_STEWARD` `recordRecoveryApproval`, all rules above apply and the
registry additionally proves that:

- `finalityRecordHash` is the exact current executed finality record named by
  the approval;
- the finality registry's authenticated record is collection scope for the
  same Core and `collectionId`, with token/release/season/view identifiers
  zero or absent as fixed by that ABI;
- the recovery manifest hash in the typed payload and finality-side staged
  recovery facts are exact, and the artist-approval path is the
  artwork-bytes-changing path to which `[AA-RECOVERY]` applies; and
- the finality record and burn-cutoff observations are still current at the
  lock-held transition point.

No steward approval may be generalized from a collection-scope record to a
token, release, season, or view. No `AUTH_STEWARD` result is reusable across a
different Core, collection, binding generation, finality registry, finality
record, recovery manifest, appointment height, or sanction-grant lineage.
All Core/finality reads occur while the registry lock is held and before the
adapter call; no dependency call is permitted after the first durable write.

**BLOCKING REVIEW DECISION AR-32:** Freeze the exact Core burn-cutoff and
finality-registry construction/runtime code-hash dependencies; called
selectors, calldata, success/returndata shapes, and canonical decoding; exact
collection-scope and executed/current predicates; grant/governance lineage;
`currentStateDigest` and field-bank preimages; one-way latch assumptions and
same-transaction reread policy; and sanction/recovery event mappings. Publish
positive and hostile vectors for zero/after-appointment burn heights, every
forbidden scope, stale or foreign finality records, changed recovery
manifests, superseded/provisional grants, forbidden capabilities, and
dependency code drift.

## Hostile Test Matrix

A conforming implementation requires all applicable cells below for every
selector, not one representative per family.

| Boundary | Required hostile and positive coverage |
| --- | --- |
| 57-write completeness | every write's create/update/conflict/finality/supersession path; all 44 formerly absent writes; every Permanent nonempty read; exact legitimate empty state |
| authority | wrong caller, role, artist, collaborator, delegate, guardian, prior address, successor, steward, arbiter, capability, collaborator threshold, governance class/action/scope/old/new state |
| selector isolation | unknown selector, fallback-only success, cross-selector field reuse, cross-selector transcript transplantation, wrong registry write selector, wrong field mask, nonzero unused field |
| adapter identity | zero/non-contract adapter, wrong interface/XOR, marker, schema, dependency hash, code hash, runtime drift before call, runtime drift during callback attempt |
| fixed context | mutation of each of 23 context words; noncanonical upper bits; forbidden governance/signature/GGP words on inapplicable operations |
| field bank | mutation of every used field; nonzero every unused field; wrong enum, bool, address, count, threshold, bitmask, sort order, duplicate, zero-forbidden value |
| dynamic ABI | independent registry and adapter rejection of empty where forbidden, every short head, offset into head, nonminimal root/element/signature offset, unaligned offset, overlap, alias, gap, out-of-order tail, nonzero padding, trailing data, count/length overflow; exact family formulas; zero/maximum/maximum-plus-one |
| collaborator policy | 0/1/32/33 collaborators; sorted and unsorted; duplicate pair/index/signer; primary-only/all/threshold/quorum; missing, duplicate, extra, or reordered signer; capability override overlap and gap behavior |
| EIP-712 | each assigned typehash string/value, domain name/version/chain/registry, every struct field/order, empty/nonempty array hash, `0x1901` digest, action-code specialization, direct/governance `NONE`, refusal and delegation-revocation gap closure |
| signatures | 1/2/33 proof bundles; all EOA, all ERC-1271, and mixed order; mixed EOA/ERC-1271 old/new rotation; EOA 64/65 success, bad length, zero recovery, high-`s`, wrong `v`, wrong signer/digest/chain/registry/Core/nonce/deadline; ERC-1271 success, wrong code hash, wrong magic, revert, out-of-gas, empty/4-byte/short/extra return, malformed upper bytes |
| direct path | exact permitted direct caller, empty-signature ambiguity, relayed empty signature, direct/signed transcript collision |
| nonce/replay | unordered reverse submission, duplicate use, revoked digest, revoked nonce, cross-identity isolation, old authority after rotation/recovery, stale delegation use count |
| signer callbacks | every ERC-1271 signer treated as opaque adversarial transitive static execution; reentry into every registry write, deep/cyclic static calls, gas grief, huge/malformed returndata, signer self-observation/code-hash drift attempt, and state-dependent transcript reuse |
| digest/result | wrong magic, intent, ordered observation/fold, aggregate reserve commitment, result, record hash, dynamic hash, signer-set hash, primary signer/nonce/signedAt/authority, every flag bit, reserved words; signature-representation independence of intent/records; 511/512/513-byte return |
| record/event atomicity | lock acquired first; no mutation or event before accepted transcript; no external call after first durable write; exact no-change rollback of lock, nonce, digest revocation, state, chain tip, payload index, signature storage, GGP state, and events on every failure and downstream internal revert |
| imported history | malformed leaf, wrong lane kind/key/sequence/chain hash, 0/max/max+1 proof, wrong root, unfinal predecessor, predecessor read mismatch, unverified-lane consumer read, continuation from wrong tip |
| formerly empty reads | identity revision, guardians, rotation, prior standing, historical generations, collaborators, repudiation, platform state, claims, attestation, delegation, succession, steward, dormancy, estate |
| steward boundary | sanction and recovery collection scope only; token/release/season/view rejection; exact binding/steward/appointment/grant capability; burn block zero, before/equal/after appointment; stale/foreign/wrong-scope finality record; changed manifest; dependency code drift |
| external callgraph | adapter directly targets only the fixed ecrecover precompile and exact request-bound ERC-1271 signers; no adapter Core/role/Governance/finality/predecessor/registry call; signer transitive static execution is allowed but untrusted and capped; no adapter `CALL`, value path, arbitrary direct target/selector, state write, create, delegate, or self-destruct |
| direct adapter determinism | identical calldata and signer observation from registry and third-party caller returns identical data; `msg.sender` never authorizes |
| gas | 0/1/2/33 participants; cold unique and warm adversarial paths; all-contract and mixed bundles; maximum per-signature and aggregate bundle; heaviest approved wallet class; cap floor/genesis/raised values; each reverse-fold and outer-boundary exact-minus-one/exact pass; overflow and outer-call starvation |
| size | registry and adapter runtime 22,576 pass / 22,577 fail; full exact-argument initcode 47,152 pass / 47,153 fail |

Positive tests independently recompute typed-data hashes, dynamic hashes,
intent, observations, results, record preimages, record chains, stored state,
and event topics/data without calling production helpers.

## Size, Deployment, And Evidence Gates

Both registry and adapter independently require:

- optimized Solidity 0.8.19 via-IR runtime no larger than 22,576 bytes;
- exact full initcode, including encoded constructor arguments, no larger than
  47,152 bytes;
- 2,000-byte margins under EIP-170 and EIP-3860 respectively;
- runtime bytes and remaining margin after every relevant patch and on the
  final serialized base;
- creation bytecode, exact constructor encoding, full initcode, initcode hash,
  runtime SHA-256, runtime EVM Keccak/`EXTCODEHASH`, canonical isolated compiler
  inputs, and deployment receipt; and
- boundary tests at 22,576/22,577 and 47,152/47,153.

If either contract cannot meet both ceilings without omitting normative
behavior, implementation acceptance stops. A second adapter, state split,
proxy, delegatecall, mutable dependency, or reduced behavior requires a new
reviewed architecture.

If later accepted, the adapter is implementation-private dependency
`ARTIST_REGISTRY_VALIDATION_ADAPTER`, complete-contract inventory ID 39. It is
not a module, Registry V2 row, Core pointer, module type, or ordinary genesis-
profile entry. The ordinary profile remains 37 entries. Contract-set version
2 contains 39 complete deployed contracts and 37 registry entries, with the
ADR 0021 adapter at ID 38 and this candidate at ID 39. Historical version 1
evidence remains immutable.

Final evidence must include focused/full Foundry, optimized isolated build,
Slither, opcode/callgraph proof, issue #669 closed external-call inventory,
issue #684 candidate-bound GGP proof, Registry V2 and Governance V2 pointer
rehearsal, source verification, exact constructor and code-hash binding,
versioned 39-contract/37-registry projection, deployment receipts, release
tail, checksums, Windows aggregate gate, and whitespace checks. No passing
gate is a production-readiness claim.

**BLOCKING REVIEW DECISION AR-27:** Approve the two independent 2,000-byte
margin gates and the stop condition, acknowledging that the incomplete
checkpoint provides no proof that the proposed split fits.

**BLOCKING REVIEW DECISION AR-28:** Approve private dependency ID 39, the
version-2 39-contract/37-registry evidence shape, and the acyclic order:
upstream dependencies -> artist adapter -> artist registry -> revenue adapter
-> revenue resolver -> ordinary registrations and governed pointer installs.

## Remaining Freeze Procedure

This proposed packet may advance only in this order:

1. Independently review and explicitly accept, revise, or reject ADR 0022.
2. Resolve every **BLOCKING REVIEW DECISION** in this document.
3. Publish the complete 57-row field-mask table, exact registry write ABI,
   exact signature-bundle codec, exact per-family root/nested ABI and dynamic-
   hash preimages, the 57-row EIP-712/record/event matrix, exact
   current/replay-state and steward Core/finality proof preimages, and measured
   reverse-composed EIP-150 reserves.
4. Regenerate and independently verify every selector and both interface XORs.
5. Record an explicit freeze commit that names this packet revision and all
   reviewed supplements.
6. Only then reconcile the artist-authority specification and authorize a
   conforming implementation in a separate change.

Until all six steps complete, implementation remains prohibited. This packet
preserves honest pre-audit maturity and leaves protocol approval to the user.
