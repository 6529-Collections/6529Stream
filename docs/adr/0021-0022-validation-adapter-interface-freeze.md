# ADR 0021/0022 Validation-Adapter Acceptance And Semantic Freeze

## Status

**Accepted as a pre-genesis architecture and semantic freeze decision.**

This is the accepted semantic interface decision only. Overall packet
acceptance, the broader normative/implementation freeze, and production-source
implementation authorization remain blocked pending the empirical evidence
gates and the finality supplement named below.

This decision:

- accepts ADR 0022's one-registry/one-stateless-adapter architecture;
- retains accepted ADR 0021's one-resolver/one-stateless-adapter architecture;
- accepts implementation-private dependency inventory IDs `38` and `39`;
- fixes the conservative protocol choices and semantic operation matrix below;
- authorizes measurement prototypes needed to prove gas and bytecode feasibility;
- does not authorize a production deployment, readiness promotion, audit claim,
  or implementation acceptance; and
- fails closed wherever this document or the matrix names an implementation
  stop.

The protocol remains pre-audit and not production-ready. A measurement
prototype is evidence, not an accepted protocol implementation.

## Decision Inputs

This decision was made against commit
`8a045029185efc807edeac08d6f76b95c4387dd1` and these inputs:

- [ADR 0021](0021-immutable-revenue-resolver-validation-adapter.md);
- the [ADR 0021 candidate packet](0021-revenue-resolver-validation-adapter-interface-packet.md);
- [ADR 0022](0022-immutable-artist-registry-validation-adapter.md);
- the [ADR 0022 candidate packet](0022-artist-registry-validation-adapter-interface-packet.md);
- [`stream-artist-authority.md`](../stream-artist-authority.md);
- [`revenue-splits-and-royalties.md`](../revenue-splits-and-royalties.md);
- [`mint-policy-and-accounting.md`](../mint-policy-and-accounting.md);
- [`collection-metadata-contract.md`](../collection-metadata-contract.md);
- [`stream-long-term-architecture.md`](../stream-long-term-architecture.md);
- ADR 0018's accepted operation-root and token-identity rules; and
- the machine-readable
  [artist operation matrix](../../release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json).

The matrix is part of this decision. The prose governs if a JSON description
of a global rule is less restrictive. An operation row governs its own field
order, mask, authority, signature rule, records, dependencies, events, and
stops.

## Accepted Topology And Inventory

The accepted dependency order is:

```text
upstream dependencies
  -> StreamArtistRegistryValidationAdapter (private ID 39)
  -> StreamArtistRegistry
  -> StreamRevenueResolverValidationAdapter (private ID 38)
  -> StreamRevenueResolver
  -> ordinary Registry V2 registrations and governed Core pointer installs
```

Both adapters are immutable, stateless, nonpayable, non-authoritative, and
implementation-private. Neither is a Registry V2 row, Core pointer target,
module type, proxy, owner, role holder, state store, or ordinary genesis
profile entry. Version 2 therefore has 39 complete deployed contracts and 37
ordinary registry entries. Historical version-1 evidence remains immutable.

The artist registry and revenue resolver remain the sole state owners and
authority boundaries. An adapter result is validation evidence only.

Deployment-specific addresses, constructor arguments, deployed runtime
Keccak/`EXTCODEHASH`, runtime SHA-256, and dependency code hashes are
deployment bindings. They are not literal ABI-freeze constants. Each
deployment must bind and publish them, and a live mismatch fails closed.

## Common Artist Freeze Rules

### Semantic write selectors

The matrix resolves the candidate packet's registry-write-selector ambiguity
without freezing implementation-tuned Solidity structs.

For each operation:

```solidity
registryWriteSelector =
    bytes4(keccak256(bytes(exactWriteSelectorPreimage)));
```

The exact preimage and result are in the row. This selector identifies a
semantic state transition and is committed in the validation transcript. It
is not the Solidity ABI selector. The final Solidity function signature and
ABI selector must be pinned separately in the implementation release
manifest, must map one-to-one to the semantic selector, and must not create a
generic record or operation router.

### Field bank and state commitments

Every operation receives the accepted 23-word context and 24-word field bank
from the artist packet. In each matrix row, the first listed field is
`fields[0]`, the next is `fields[1]`, and so on. `field_mask` is exact. Every
unused field is zero.

The current- and replay-state digest recipes in the matrix are accepted. The
registry computes each digest locally from:

- the domain, chain, registry, and semantic write selector;
- all 24 canonical field words;
- the row's ordered current-state or replay facts; and
- the complete signer-set hash where applicable.

The adapter recomputes only request-carried facts. It does not discover
authority or mutable registry state. A missing, reordered, stale, aliased, or
untyped fact fails before mutation.

### Signer bundle

The accepted bundle remains:

```solidity
abi.encode(
    ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1,
    SignerProofV1[]
)
```

with the nine-field `SignerProofV1` in the artist packet. There are between 1
and 33 strictly ordered participants, exactly two for rotation, and at most
one direct participant.

For each proof:

```solidity
rowHash = keccak256(abi.encode(
    participantIndex,
    signer,
    signerCodeHash,
    authorityClass,
    signatureMode,
    nonce,
    deadline,
    signedAt
));
```

The exact aggregate is:

```solidity
signerSetHash = keccak256(abi.encode(
    ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1,
    uint256(rowHashes.length),
    keccak256(abi.encode(rowHashes))
));
```

Raw signature bytes do not enter `rowHash`, `signerSetHash`, typed-data
digests, intent, or normative record hashes. They enter the canonical dynamic
signature hash and signer-observation transcript.

The aggregate raw signature-byte limit is 4,096 bytes across the whole
bundle. V1 has no oversized archival-proof transport. More than 4,096 raw
signature bytes fails before the adapter call.

### Nonces and time

The following rules are accepted:

- A direct call consumes the registry allocator nonce for the exact authority
  lane and records `block.timestamp`.
- A deadline-bearing signed payload signs `deadline`; its record/event
  `signedAt`-class timestamp is the registry-observed submission
  `block.timestamp`.
- A long-lived payload whose typehash contains `signedAt` signs that exact
  value and carries zero deadline.
- Delegation grants retain their validity-window and nonce-only normative
  payload. They do not invent an extra signed timestamp.
- Multi-party operations validate every participant's own nonce and time
  fields. Participant zero is only the fixed context echo.

All accepted nonces, revoked digests, delegation-use counters, direct
allocator lanes, and one-way transition keys are storage-backed and included
in the replay-state digest.

### New unambiguous typehashes

Refusal and delegation revocation receive distinct payloads:

```text
StreamArtistBindingRefusal(
  address core,
  uint256 collectionId,
  uint64 bindingGeneration,
  bytes32 bindingHash,
  bytes32 reasonHash,
  uint256 nonce,
  uint64 deadline
)
```

Its typehash is
`0xc893b08f32a42da1625fa6427599c670031a4718906493412194962b8605a4bc`.

```text
StreamArtistDelegationRevocation(
  bytes32 artistId,
  address delegate,
  bytes32 delegationRecordHash,
  bytes32 reasonHash,
  uint256 nonce,
  uint64 deadline
)
```

Its typehash is
`0x014fd1a66a54ed0ac8a6ec104ec6c3a2e593265b3cd018c918b44792cbd51369`.

Neither payload may reuse acceptance, delegation-grant, or generic-dispute
typed data.

### Dynamic inputs

V1 fixes these maxima:

| Input | Maximum |
| --- | ---: |
| collaborators | 32 |
| capability-policy overrides | 32 |
| guardians | 8 |
| content-lock classes | 16 |
| recovery supersession hashes | 64 |
| history Merkle-proof words | 64 |
| aggregate raw signature bytes | 4,096 |
| directive or identity-document bytes | 8,192 |
| identity or reason URI bytes | 2,048 |
| display-name bytes | 256 |

Root and nested offsets, contiguity, zero padding, exact final length, sorted
static arrays, and checked arithmetic follow the candidate packet.
`dynamic0Hash` is the operation-selector-bound ordered hash of every
non-signature dynamic argument's exact byte length and Keccak. `dynamic1Hash`
is the selector-bound ordered hash of every participant signature's exact byte
length and Keccak. An absent category is zero.

Identity bytes and display name are nonempty. The outer signer bundle is
nonempty on every signer-bearing family. Inner signature bytes are empty only
for the single direct participant. A reason URI may be empty only when the
owning operation permits an empty reason and its reason hash is zero.
Collaborator and capability arrays may be empty only with the corresponding
zero policy. A guardian array may be empty only with threshold zero. Lock and
supersession arrays are nonempty. A Merkle proof may be empty only for a
valid single-leaf root.

### Display name

The exact UTF-8 display name is state-carried. It is committed by the identity
document/record hash and mirrored by `artistDisplayName`. It is not duplicated
as an event string. `ArtistIdentityRegistered` and
`ArtistIdentityRevisionRecorded` retain the event declarations in
`AA-EVENTS`; their identity/revision record hashes commit the display value.
This rule applies equally to primary and collaborator identities.

### ERC-1271 and GGP

ERC-1271 accepts exactly 32 bytes:

```text
0x1626ba7e00000000000000000000000000000000000000000000000000000000
```

Empty, 4-byte, short, extra, dirty, wrong-magic, revert, and out-of-gas returns
fail.

`ARTIST_ERC1271_VERIFY_GAS` remains registry-owned. Its exact identifier is
`0x04bd88d7a1b04a4fc7476b74a962c2fea893f8ad4e6711b1c13e828f151458b5`.
`StreamArtistRegistry` implements the accepted
`IStreamGasParameterHost.gasParameterInfo(bytes32)` read, selector
`0xec2ef90a`, with exactly 128 return bytes decoded as:

```solidity
(uint256 value, uint256 floor, uint8 failureClass, uint64 revision)
```

For this identifier the immutable floor is 90,000, the genesis value is
150,000, `failureClass` is exactly `FAIL_CLOSED_PRECHECK` (`2`), and the
genesis revision is `1`. The registry rejects a zero or nonmonotonic revision,
a different floor or failure class, or a live value below the floor. It
authenticates the live value and revision before the adapter call, performs
the outer EIP-150 precheck, and commits both values.

The adapter receives those exact request-authenticated values and applies the
cap independently to each ERC-1271 participant. It never reads Governance,
the GGP host ABI, or the registry.

## Revenue Packet Dispositions

The following are the dispositions for R1 through R13:

| Decision | Disposition |
| --- | --- |
| R1 | Accept nine adapter entries, three probes, and the 29-word transcript only on adapter-invoked paths. O9 no-op and rejection remain host-only. |
| R2 | Accept the complete primary profile/template and scope/authority/counter matrix. |
| R3 | Accept the six-argument snapshot, five distinct hash roles, canonical expected/returned royalty-policy hashes, and create/no-op/mismatch state machine. |
| R4 | Accept pointer/manager/ledger discovery and the host-only proof inventory. |
| R5 | Accept codehash-bound dependency marker/schema facts without additional adapter probes. |
| R6 | Revise literal dependency binding: interface, marker, schema, and behavior are interface-freeze facts; artist address and runtime/code hash are deployment bindings. |
| R7 | Accept O4-O9 field meanings and resolver-owned state/counters. |
| R8 | Accept the seven-step profile bundle and no template factory/wallet call. |
| R9 | Accept ordinary, retained-burned, and prepared Core identities for O2/O3, and prepared-unburned only for O9. |
| R10 | Accept adapter-mediated caller-insensitive artist reads. The resolver owns authorization; the artist registry validates the resolver identity supplied in the consent/freeze record, never adapter `msg.sender`. |
| R11 | Accept available-gas topology with no new GGP. Empirical thresholds are an implementation-acceptance gate. |
| R12 | Accept the packet's preimages/selectors as the semantic target. Independent executable vectors remain an implementation-stop gate and are not claimed by this decision. |
| R13 | Move final isolated runtime/initcode proof to implementation acceptance under the measurement-prototype authorization below. The size limits and stop condition are unchanged. |

## Artist Packet Dispositions

The following are the dispositions for AR-01 through AR-33:

| Decision | Disposition |
| --- | --- |
| AR-01 | Accept one state-owning registry and one stateless validation adapter. |
| AR-02 | Accept the bounded mixed EOA/ERC-1271, at-most-33-participant callgraph. |
| AR-03 | Accept dedicated validation coverage for all 57 writes. |
| AR-04 | Accept the twelve ASCII hash constants, fixed probes, and binding preimage. |
| AR-05 | Accept chain-specific binding with transition-bound signer identities. |
| AR-06 | Accept the 23-word context and 24-word field bank. |
| AR-07 | Resolve through the exact masks and fields in the matrix. |
| AR-08 | Resolve through the exact current/replay recipes and row facts in the matrix. |
| AR-09 | Resolve through the nonce/time rules above. |
| AR-10 | Accept families F, Q, U, QU, B, CI, IR, G, R, L, X, D, and M. |
| AR-11 | Accept direct mode only as the one empty-signature inner row. |
| AR-12 | Accept the ordered bundle with the 4,096-byte aggregate raw-signature limit. |
| AR-13 | Accept the 57 validation selectors and packet XORs as semantic targets; executable recomputation remains an implementation gate. |
| AR-14 | Resolve with the distinct delegation-revocation typehash above. |
| AR-15 | Resolve with the semantic write-selector rule and per-row selectors; actual Solidity ABI selectors are release-manifest bindings. |
| AR-16 | Resolve with the dynamic emptiness rules above and row field masks. |
| AR-17 | Set the capability-policy override maximum to 32. |
| AR-18 | Set supersession and history-proof maxima to 64 words each. |
| AR-19 | Cap aggregate raw signatures at 4,096 bytes and reject oversized V1 transport. |
| AR-20 | Accept selector-bound ordered dynamic hashes and exact canonical ABI; executable boundary vectors remain an implementation gate. |
| AR-21 | Accept the 16-word result, flags, observation fold, and aggregate digests. |
| AR-22 | Resolve through each row's primary and secondary record assignment. |
| AR-23 | Accept exact 32-byte ERC-1271 return shape. |
| AR-24 | Accept reverse-composed EIP-150 design; measured reserves are an implementation-acceptance gate. |
| AR-25 | Pin the GGP value/revision source to registry-owned governed-parameter storage. |
| AR-26 | Resolve through each row's signature rule and authority. |
| AR-27 | Accept both 2,000-byte margins and the no-waiver stop condition. |
| AR-28 | Accept private ID 39, 39-contract/37-registry evidence, and the acyclic deployment order. |
| AR-29 | Resolve with the exact bundle, row-hash, aggregate signer-set hash, participant bounds, and per-row signature rules. |
| AR-30 | Resolve with state-carried, record-committed, nonduplicated display names. |
| AR-31 | Resolve semantically through the matrix and source-pinned typehash/record/event declarations; executable vectors remain an implementation gate. |
| AR-32 | Resolve the finality-dependency sub-gate for rows 12 and 13 through the reviewed versioned supplement; preserve row 22's stop pending Accepted ADR 0020 and merged issue #667 reconciliation. Every non-finality implementation gate remains unchanged. |
| AR-33 | Resolve with the distinct binding-refusal typehash above. |

## Implementation Stops

### Finality dependency

The reviewed
[`finality dependency supplement`](0021-0022-validation-adapter-finality-supplement.md)
and its
[`versioned machine overlay`](../../release-artifacts/issue-670-adapter-freeze/finality-dependency-supplement-v1.json)
resolve only `FINALITY_DEPENDENCY_ABI_AND_ADR0020_NOT_FROZEN` for matrix rows
12 (`recordArtistSanction`) and 13 (`confirmSanctionFinalized`), and only for
current Proposed-packet evaluation and measurement. They pin those rows'
deployment-bound code identities, exact selectors and canonical return
decoders, current-state preimages, predicates, rereads, events, and hostile
vectors. ADR 0020 recovery semantics are not a dependency of either row.

Machine precedence is fail-closed:

1. each matrix row contributes its base `implementation_stop` list;
2. generated `implementation_stop_overlays` apply afterward in listed order;
3. an overlay may remove only an exact stop from an exact listed row; and
4. every unlisted row and stop remains unchanged in
   `effective_implementation_stops`.

The repository generator emits that base-plus-overlay view, and the checker
requires the matrix overlay to equal the supplement's `matrix_overlay`.
Unknown overlays, row substitution, stop substitution, or effective-state
drift fail.

Row 22 (`recordRecoveryApproval`) remains NO-GO with the finality stop intact.
It requires Accepted ADR 0020 and merged issue `#667` reconciliation before a
later reviewed supplement can pin the recovery host/ABI, current executed
record and manifest predicates, reconciled current-state preimage, reread
rules, and event mapping.

Rows 12 and 13 are still not implementation-authorized: executable vectors,
gas and size evidence, static analysis, integration, deployment, and release
gates below remain unchanged. No implementation may omit an operation, ship a
zero stub, or substitute an optimistic truth bit.

### Executable vector evidence

Before implementation acceptance, independent code must regenerate and check:

- all validation and semantic write selectors;
- both artist interface XORs and the revenue interface XOR;
- every typehash and new record domain;
- all family root/nested offsets and exact lengths;
- all 57 field masks, state/replay digests, record hashes, events, and
  direct/signed branches;
- one-, two-, and 33-participant signer transcripts;
- maximum and maximum-plus-one dynamic boundaries;
- O1-O9 revenue transcripts, O9 host-only branches, and all five snapshot
  hashes; and
- hostile substitution, malformed return, recursion, rollback, and stale-state
  cases in both packet test matrices.

A documentation link check or automated prose review is not this evidence.

### Gas and size evidence

Measurement prototypes are explicitly authorized only to close empirical
gates. They may not be deployed as protocol instances or described as
accepted implementations.

Implementation acceptance requires:

- reproducible compiler and fork settings;
- measured reverse-composed EIP-150 reserves at all 1/2/33-signer boundaries;
- cold/warm, maximum-return, revert, out-of-gas, and parent-retention vectors;
- focused/full Foundry, Slither, and opcode/callgraph evidence;
- optimized isolated runtime at or below 22,576 bytes for each state owner and
  adapter;
- exact full initcode at or below 47,152 bytes;
- 22,576/22,577 and 47,152/47,153 boundary tests; and
- exact source commit, constructor encoding, bytecode hashes, and receipts.

Failure stops implementation acceptance and returns to a versioned design
review. It does not authorize omitted validation or a margin waiver.

## Required Source-Document Reconciliation

This decision is the disposition record. The following mirrors must be
updated before implementation acceptance:

1. `docs/adr/0022-immutable-artist-registry-validation-adapter.md`
   must mirror Accepted status and cite this decision.
2. Both candidate packet documents must replace Proposed status with a link
   to this decision, distinguish semantic freeze from implementation
   acceptance, and retain every empirical stop.
3. `docs/stream-artist-authority.md` must add the refusal and delegation-
   revocation typehash/domain rows, the accepted nonce/time and display-name
   rules, dynamic maxima, semantic write selectors, signer aggregate, GGP
   source/revision, and the matrix reference.
4. `docs/revenue-splits-and-royalties.md` must state the adapter-mediated,
   caller-insensitive artist observation boundary and deployment-bound artist
   address/runtime semantics.
5. `docs/mint-policy-and-accounting.md`, ADR 0018, and
   `docs/collection-metadata-contract.md` must remain byte-for-byte consistent
   with R3/R4/R9 snapshot, prepared-mint, burn-retained, and identity rules.
6. ADR 0020, `docs/stream-long-term-architecture.md`, and
   `docs/collection-metadata-contract.md` must close the finality stop or the
   artist implementation cannot proceed.
7. `docs/launch-v1-target-architecture.md` and
   `docs/launch-conformance-matrix.md` must add IDs 38/39, the 39/37 evidence
   shape, exact dependency order, matrix/vector gates, and finality stop.
8. `docs/tooling.md` must name deterministic generators/checkers for this
   decision and matrix.
9. `docs/status.md`, `docs/known-blockers.md`,
   `docs/release-readiness.md`, `ops/ROADMAP.md`, and
   `ops/EXECUTION_BACKLOG.md` must report architecture acceptance without
   implying implementation, audit, deployment, or release readiness.
10. `CHANGELOG.md` and generated release-integrity artifacts must be refreshed
    in the repository-prescribed order when the reconciliation change lands.

If any reconciliation changes a selector, field, typehash, record, event,
authority, dependency, or limit, this decision and matrix require a reviewed
version increment. A source document may not silently override the freeze.

## Freeze And Implementation Acceptance Criteria

This semantic freeze is complete when this decision and the exact matrix are
committed together. It becomes implementation-unblocking only when:

1. every matrix `implementation_stop` array is empty in a reviewed successor
   artifact;
2. the source-document reconciliation above is merged;
3. executable vector evidence passes independently;
4. measured gas and size evidence passes without waiver;
5. final Solidity ABI selectors map one-to-one to the semantic write
   selectors and are pinned in the release manifest;
6. deployment bindings and dependency code hashes are published and verified;
7. security and integration review find no unresolved actionable issue; and
8. the implementation commit and all evidence artifacts are named explicitly.

Even then, deployment, audit completion, production readiness, and release
approval remain separate user-owned gates.
