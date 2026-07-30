# ADR 0021/0022 Validation Adapter Finality Dependency Supplement

## Status

**Reviewed Proposed-packet supplement: rows 12 and 13 GO; row 22 NO-GO.**

This supplement closes the finality-dependency design question for
`recordArtistSanction` and `confirmSanctionFinalized` in the current Proposed
packet. It does not accept the overall packet, authorize production source,
authorize deployment, or promote readiness. The protocol remains pre-audit
and not production-ready.

`recordRecoveryApproval` remains a hard NO-GO until
[ADR 0020](0020-executor-only-finality-recovery.md) is Accepted and issue
`#667`'s recovery reconciliation is merged. No ABI or optimistic truth bit is
invented for that row.

The machine-readable mirror is
[`finality-dependency-supplement-v1.json`](../../release-artifacts/issue-670-adapter-freeze/finality-dependency-supplement-v1.json).

## Decision

This document supplements the accepted semantic decision in
[`0021-0022-validation-adapter-interface-freeze.md`](0021-0022-validation-adapter-interface-freeze.md)
and its
[`artist-operation-matrix-v1.json`](../../release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json).
It has this narrow overlay effect:

| Matrix row | Operation | Decision | Effect |
| --- | --- | --- | --- |
| 12 | `recordArtistSanction` | GO | The finality-dependency stop is resolved for current Proposed-packet evaluation and measurement only |
| 13 | `confirmSanctionFinalized` | GO | The finality-dependency stop is resolved for current Proposed-packet evaluation and measurement only |
| 22 | `recordRecoveryApproval` | NO-GO | `FINALITY_DEPENDENCY_ABI_AND_ADR0020_NOT_FROZEN` remains a hard implementation stop |

The table is not an independent prose override. Its machine authority is the
supplement artifact's `matrix_overlay`, whose precedence is:

1. start from every operation's generated base `implementation_stop` list;
2. apply `artist-finality-dependency-supplement-v1` afterward;
3. remove only
   `FINALITY_DEPENDENCY_ABI_AND_ADR0020_NOT_FROZEN` from rows 12 and 13; and
4. preserve row 22, every unlisted row, and every unlisted stop exactly.

The generated matrix publishes the resulting
`effective_implementation_stops`, and the issue-670 checker requires its
overlay object to equal this supplement's object byte-for-structure. A GO in
this document has no effect unless that generated precedence calculation
produces an empty effective list for the same row. Unknown overlays,
additional row resolutions, stop substitution, and effective-state drift
fail closed.

Rows 12 and 13 do not depend on finality recovery. Row 12 records a sanction
that the current finality registry can later consume. Row 13 confirms an
already executed, immutable collection-finality record through the current
read surface. ADR 0020 therefore does not need to be accepted for those two
operations.

The adapter remains stateless and never calls Core or the finality registry.
The artist registry owns the lock, deployment identities, code-hash checks,
dependency calls, canonical decoding, predicates, current-state commitment,
same-transaction reread, durable writes, and events.

## Deployment-bound identities

This supplement intentionally supplies no literal deployment address or
runtime code hash. For Core, the finality registry, and the artist registry as
a finality component, the deployment packet supplies:

1. the exact nonzero constructor-bound address;
2. the compiler-produced creation-code hash;
3. the exact initcode hash including constructor arguments;
4. the expected deployed runtime `EXTCODEHASH`; and
5. the deployment manifest and receipt that bind those values.

The registry requires nonempty live code and exact equality between
`EXTCODEHASH(target)` and the deployment-supplied expected runtime code hash
before every relevant read and again during the reread pass. A source-artifact
hash, a zero hash, a mutable lookup, a successful call, or a "latest release"
selection is not a deployment binding. The finality-registry deployment record
must also bind it to the same Core and artist-registry line used by the
operation.

## Frozen dependency ABI

Every call below is a bounded-returndata `STATICCALL` to the constructor-bound
address while the registry-wide lock is held. Call failure, revert, wrong
length, noncanonical encoding, predicate failure, or reread drift reverts
without a durable write or normative event. Revert data is not bubbled.

### Core burn cutoff

Only the `AUTH_STEWARD` branch of row 12 calls Core:

```text
signature: collectionBurnsBlockedAtBlock(uint256)
selector:  0x74a5ded9
calldata:  0x74a5ded9 || abi.encode(uint256(collectionId))
length:    36 bytes
return:    exactly 32 bytes, decoded as uint64
```

The upper 192 bits must be zero. The decoded height must be nonzero and no
greater than `stewardAppointedAtBlock`.

Non-steward row-12 paths make no Core function call. Row 12 makes no finality
registry function call: it commits the bound finality identity and the
candidate finality-component facts, while finality later recomputes and
verifies the sanction subject.

### Executed collection-finality record

Row 13 makes this exact call:

```text
signature: collectionFinalityRecord(uint256)
selector:  0x980d80c5
calldata:  0x980d80c5 || abi.encode(uint256(collectionId))
length:    36 bytes
```

The single dynamic tuple return is decoded as:

```solidity
(
    bool finalized,
    bytes32 finalityRecordHash,
    bytes32 manifestContentHash,
    bytes32 manifestURIHash,
    string finalityManifestURI,
    bytes32 componentsHash,
    address manifestPointer,
    uint64 finalizedAt
)
```

Canonical encoding requires:

- outer tuple offset exactly `0x20`;
- an eight-word tuple head;
- boolean word exactly zero or one;
- string offset, relative to the tuple start, exactly `0x100`;
- the string tail immediately after the head with zero padding;
- zero upper 96 address bits and zero upper 192 `uint64` bits; and
- exact return length
  `320 + ceil32(length(bytes(finalityManifestURI)))`, with no gap, alias,
  overlap, or trailing bytes.

### Component count and array

Row 13 then calls:

```text
signature: finalityComponentCount(uint256)
selector:  0x880b294f
calldata:  0x880b294f || abi.encode(uint256(collectionId))
length:    36 bytes
return:    exactly 32 bytes, decoded as uint256 componentCount
predicate: 1 <= componentCount <= 32
```

It uses that exact count in:

```text
signature: finalityComponents(uint256,uint256,uint256)
selector:  0x1825f65a
calldata:  0x1825f65a ||
           abi.encode(uint256(collectionId), uint256(0), uint256(componentCount))
length:    100 bytes
```

The return is:

```solidity
(
    bytes32 componentType,
    address component,
    bytes4 interfaceId,
    bytes32 codeHash,
    bytes32 moduleVersion,
    bytes32 manifestHash,
    bytes32 dataHash
)[] components
```

Canonical encoding requires outer offset `0x20`, array length exactly
`componentCount`, seven static words per entry, zero upper 96 address bits,
left-aligned `bytes4` with zero lower 224 bits, and exact return length
`64 + 224 * componentCount`. Element offsets, gaps, aliases, overlaps, and
trailing bytes fail.

### Current-route verification

Finally, row 13 calls:

```text
signature: verifyFinality(uint256)
selector:  0xf060d767
calldata:  0xf060d767 || abi.encode(uint256(collectionId))
length:    36 bytes
return:    exactly 96 bytes
decode:    (bool currentRouteMatches,
            bytes32 finalityRecordHash,
            bytes32 componentsHash)
```

The boolean word must be exactly zero or one and no trailing bytes are
accepted.

## Row 12: `recordArtistSanction`

Row 12 is GO against the current Proposed packet under all existing authority,
signature, collaborator, replay, record, and atomicity rules plus this
supplement.

All authority classes require the exact live collection binding and
generation, a sanction-permitted attribution state, current authority and
collaborator policy, canonical scope shape, and deployment-bound Core,
finality-registry, and artist-registry code identities. The candidate
collection finality component is exactly:

```solidity
abi.encode(
    bytes32(keccak256("ARTIST_SANCTION")),
    address(registry),
    bytes4(0x1300f2d7), // finalityState(uint256)
    expectedArtistRegistryRuntimeCodeHash,
    artistRegistryModuleVersion,
    artistRegistryModuleManifestHash,
    candidateSanctionRecordHash
)
```

`keccak256("ARTIST_SANCTION")` is
`0x1e14b418e60392f62e7baf2e6edfcfb6dfeab92fb4428eff216b492ed5cef047`.
The runtime hash, module version, and module manifest hash are
deployment-supplied values. The component `dataHash` is the exact
`SANCTION_RECORD_DOMAIN` record hash.

For `AUTH_STEWARD`, all of these additional predicates hold:

1. the signer is the currently vested steward;
2. `stewardAppointedAtBlock` is nonzero;
3. the effective, non-forbidden mask contains `CAP_SANCTION`;
4. the capability comes from an operative, nonprovisional, nonsuperseded,
   nonrevoked artist-signed steward sanction grant or a separately executed
   `TERMINAL_FREEZE` governance grant;
5. scope is exactly `COLLECTION == 0`, with `tokenId == 0` and
   `scopeId == bytes32(0)`; and
6. the Core burn-cutoff read is nonzero and no greater than the appointment
   block.

Token, release, season, view, and unknown steward scope values fail.

### Row-12 current-state preimage

The outer recipe remains the matrix recipe:

```solidity
keccak256(abi.encode(
    CURRENT_STATE_DOMAIN,
    block.chainid,
    registry,
    registryWriteSelector,
    keccak256(abi.encode(fields[0], ..., fields[23])),
    keccak256(abi.encode(rowCurrentStateFactsInOrder))
))
```

For row 12, `registryWriteSelector` is `0xb569ac0b`; fields zero through seven
are, in order, `artistId`, `scopeType`, `collectionId`, `tokenId`, `scopeId`,
`sanctionSubjectHash`, `statementHash`, and `bindingGeneration`; fields eight
through 23 are zero.

`rowCurrentStateFactsInOrder` is:

1. `boundCore`;
2. expected and observed Core runtime code hashes;
3. `boundFinalityRegistry`;
4. expected and observed finality runtime code hashes;
5. `bindingHash`, binding `artistId`, generation, and attribution state;
6. signer, authority class, and `authorityStateHash`;
7. `collaboratorPolicyHash`;
8. steward appointment block;
9. sanction-grant record, source class, lineage hash, and effective capability
   mask;
10. Core burn-block activation height;
11. component type, address, interface ID, code hash, module version, manifest
    hash, and candidate sanction record hash.

The exact nested hashes are:

```solidity
authorityStateHash = keccak256(abi.encode(
    artistId,
    signer,
    authorityClass,
    operativeAuthorityRecordHash,
    authorityRevision,
    delegationRecordHash,
    delegationUseCount,
    delegationMaxUses
));

sanctionGrantLineageHash = keccak256(abi.encode(
    grantSourceClass,
    grantRecordHash,
    grantingArtistId,
    grantedSteward,
    grantedCapabilityMask,
    provisional,
    superseded,
    revoked,
    terminalGovernanceActionId
));
```

Every narrow fact is canonically ABI-extended.

### Row-12 event

After the accepted reread and durable sanction writes, row 12 emits exactly
the source-owned event:

```solidity
ArtistSanctionRecorded(
    1,
    collectionId,
    sanctionSubjectHash,
    acceptedPrimarySigner,
    scopeType,
    tokenId,
    scopeId,
    sanctionRecordHash,
    acceptedAuthorityClass,
    statementHash,
    acceptedPrimaryNonce,
    acceptedSignedAt
)
```

Its topic zero is
`0x00cfc4063860e8d8cd8c29da90a36444dccff1df759a393fcc583a01a700218b`;
`collectionId`, `sanctionSubjectHash`, and signer are indexed.

## Row 13: `confirmSanctionFinalized`

Row 13 is GO against the current Proposed packet. It is a permissionless truth
confirmation, not caller authority.

The live binding and generation must be exact, the prior attribution state
must be `ARTIST_ACCEPTED == 2`, and the stored sanction must be verified,
undisputed, unrevoked, collection scope, and exact for the collection, artist,
and generation.

The decoded finality observations must prove:

1. `record.finalized == true`;
2. `record.finalityRecordHash` equals the supplied nonzero record hash;
3. `record.finalizedAt != 0` and `record.componentsHash != 0`;
4. `verifyFinality` returns `currentRouteMatches == true` and the same finality
   record and components hashes;
5. the count equals the returned array length and is in `[1, 32]`;
6. the canonical sorted-unique component array contains exactly one
   `ARTIST_SANCTION` entry;
7. that entry names `address(registry)`, interface ID `0x1300f2d7`, the
   deployment-supplied registry runtime code hash, and the deployment-bound
   module version and manifest hash; and
8. that entry's `dataHash` is the exact `sanctionRecordHash`.

### Row-13 current-state preimage

The outer recipe is the same one above. For row 13,
`registryWriteSelector` is `0x20afefab`; fields zero through five are, in
order, `collectionId`, `artistId`, `bindingGeneration`,
`sanctionRecordHash`, `finalityRecordHash`, and `priorAttributionState`;
fields six through 23 are zero.

`rowCurrentStateFactsInOrder` is:

1. bound Core plus expected and observed Core runtime code hashes;
2. bound finality registry plus expected and observed finality runtime code
   hashes;
3. binding hash, artist ID, generation, and prior attribution state;
4. sanction record hash, signer, and authority class;
5. all eight decoded collection-record values, committing the string as
   `keccak256(bytes(finalityManifestURI))`;
6. component count and `keccak256(abi.encode(components))`;
7. the unique sanction component's index and all seven component fields; and
8. all three `verifyFinality` outputs.

Every narrow fact is canonically ABI-extended.

### Row-13 event

After the accepted reread and attribution-state write, row 13 emits:

```solidity
ArtistAttributionStateChanged(
    1,
    collectionId,
    3, // ARTIST_SANCTIONED
    bindingGeneration,
    2, // ARTIST_ACCEPTED
    msg.sender,
    storedSanctionAuthorityClass,
    sanctionRecordHash,
    finalityRecordHash,
    ""
)
```

Its topic zero is
`0x877e2283bb85a0b53841839cfca5709d9d3df88f3c606a3cbfb567996d774da5`;
`collectionId` and new state are indexed.

## Same-transaction reread

The registry follows this exact order:

1. acquire the registry-wide lock;
2. check deployment addresses and live runtime code hashes;
3. perform the complete first observation pass;
4. compute `currentStateDigest`;
5. call and accept the stateless adapter;
6. repeat every applicable code check and dependency call with identical
   calldata;
7. require exact raw-return and decoded-value equality with the first pass;
8. recheck all host-local binding, authority, grant, sanction, and transition
   facts;
9. perform durable writes;
10. emit the normative event; and
11. release the lock and return.

For steward row 12, the second pass repeats the Core burn-height call. For
non-steward row 12, no dependency function call is introduced, but all code
identities and host-local facts are rechecked. Row 13 repeats all four
finality calls.

Core burn activation is accepted as a zero-until-set, then immutable latch.
An executed collection-finality record and its stored component array are
accepted as immutable on the current finality line. Those one-way properties
do not waive the exact reread. Any drift reverts atomically; no dependency call
is allowed after the first durable write.

## Row 22: explicit NO-GO

ADR 0020 remains Proposed and explicitly defers artist-registry
reconciliation. Until ADR 0020 is Accepted and issue `#667`'s reconciliation
is merged, this packet cannot pin:

- the accepted recovery authority and host identity;
- the exact current executed recovery-record ABI;
- the exact collection-scope and old-record predicates;
- the exact staged recovery-manifest ABI and artwork-bytes-changing
  predicate;
- the reconciled one-way and reread behavior;
- the exact row-22 current-state preimage; or
- the reconciled `ArtistRecoveryApprovalRecorded` mapping.

Therefore row 22 remains implementation-prohibited. It may not emit
`ArtistRecoveryApprovalRecorded`, accept validation selector `0x696ed9d5` as
implementation evidence, or substitute a boolean claim for authenticated
recovery state. A later reviewed supplement must freeze the reconciled
surface.

## Required vectors

Rows 12 and 13 still require executable positive and hostile vectors before
implementation acceptance. At minimum they cover:

- artist, successor, delegate, and steward sanction paths;
- steward burn height before and equal to appointment;
- zero and after-appointment burn height;
- every prohibited steward scope and nonzero collection-scope identifier;
- operative artist-signed and terminal-governance grants;
- provisional, superseded, revoked, wrong-steward, and forbidden-capability
  grants;
- exact permissionless finality confirmation;
- unfinalized, stale, foreign, duplicate-sanction, missing-sanction,
  wrong-component, wrong-codehash, and current-route-mismatch records;
- malformed, short, long, aliased, gapped, overlapping, noncanonical, and
  trailing returndata for every frozen ABI; and
- dependency code, record, component-array, route, grant, binding, and
  authority drift between observation passes.

Passing those vectors does not by itself clear the remaining packet,
gas/size, static-analysis, integration, deployment, or release gates.
