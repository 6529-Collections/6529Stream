# Canonical acquisition packet V2 owner authority

`STREAM_ACQUISITION_PACKET_V2` adds an explicit native OwnerRecords authority
variant to accession and title-binding record references. The original V1
packet/object schemas, classed record shapes, validators and recorded packages
remain unchanged. Numeric packet version `2` selects the new schema.

The source adapter closes item 9's representation gap by replaying an existing
[ACCESSION/history package](museum-acquisition-accession.md), deriving the new
record reference and validating it against the separately pinned V2 definition.
Its partial assembly retains all 19 requirements. Items 2, 9 and 19 are derived;
item 10 is partial; the remaining evidence is unresolved. Complete-packet export
remains blocked. An existing reader for another requirement does not imply that
its evidence was supplied to this assembly.

## Exact authority discriminator

The additional record branch uses:

```json
{"kind":"native_owner_receipt","version":"1"}
```

These are the `authority` object's discriminator fields; the complete closed
object additionally requires `receipt`, `publication`, `ownerState` and
`provenance`. Common record fields retain their original meaning, including
native `recordHash`, original `host`, `subjectId`, `schemaId`, `signer` and
`recordedBlock`. Native owner references have no `authorityClass`.

The branch is admitted **only** at:

- `legalInstrument.accession`;
- `ownershipProvenance.titleBindings[].record`.

Every existing classed reference keeps its original V1 shape and values.
Artist, General and institutional references in other roles cannot accept the
owner branch. The V1 validator rejects V2 packet identity and native-owner
references; callers must explicitly choose the new schema and authority profile.

| Evidence | Retained meaning and checks |
| --- | --- |
| `receipt` | All 13 original `IStreamOwnerRecords.Receipt` fields, with native names and widths: tokenId, owner, recordedAt, recordIndex, recordChainHash, relayed, authorizationDigest, nonce, deadline, schemaDefinitionHash, canonicalizationDefinitionHash, signatureScheme, signatureBundleHash. |
| `publication` | Original block hash/number, transaction hash/index and log index from the checked OwnerRecordRecorded receipt. |
| `ownerState` | Exact preceding Core transfer, its block hash and position, the transfer-history index and source block hash/timestamp. Signer, receipt owner and the preceding transfer recipient agree. This index describes ownership at publication; it need not equal the instrument's declared title-transfer index. |
| `provenance` | Exact original acquisition manifest, both source profile/anchor/transcript/snapshot commitments, and Keccak commitments to extracted original-record JSON, payload bytes and recorded signature-bundle bytes. |

The original package remains byte-for-byte under `acquisition/`. The new adapter
replays it before deriving any compatibility result. It preserves direct,
EIP-712 and ERC-1271 historical receipt semantics and original signature bytes;
it does not perform a fresh authorization or reinterpret an owner as an Artist.

The explicit `sourceBlockTimestamp` binds publication times without changing
the original `sourceState.examinedAt` examination-time meaning. Examination may
occur later than the source block. Shared block, transaction and log coordinates
must agree across every supplied native-owner reference.

Full packets also join each native receipt to its supplied owner-lane head:
the index must be below the count, and a final indexed receipt must match the
head hash. Supplied records in one lane must follow publication order; gaps
between their indices remain allowed. Fragment validation has no independent
head or complete-history input.

Schema validation alone checks supplied shape and internal joins. It does not
replay RPC sources or authenticate supplied signatures. Only the source-replaying
adapter emits `canonicalPacketCompatible: true` for item 9 under the explicitly
declared V2 profile. Source provenance remains either `synthetic_fixture` or
externally admitted `trusted_rpc`, and `actualChainAcceptance` remains false.
Compatibility does not establish legal title, physical custody or institutional
identity. Missing instrument bytes remain explicit in the original package.

## Definitions and commands

The three additive definitions are:

- [STREAM_ACQUISITION_PACKET_V2](../schemas/records/STREAM_ACQUISITION_PACKET_V2.json);
- [STREAM_ACQUISITION_LEGAL_INSTRUMENT_V2](../schemas/records/STREAM_ACQUISITION_LEGAL_INSTRUMENT_V2.json);
- [STREAM_NATIVE_OWNER_RECORD_AUTHORITY_V1](../schemas/records/profiles/STREAM_NATIVE_OWNER_RECORD_AUTHORITY_V1.json).

They are prospective registration inputs. No contract registration or governance
action occurs during generation:

```powershell
python -m tools.metadata.acquisition_packet_v2 --check
python -m tools.museum.acquisition_packet_v2 profiles
```

The second command prints the exact packet, legal-instrument, authority, assembly
profile and assembly schema hashes. Supply the explicit packet/authority pins
when assembling from an unchanged, externally pinned accession package:

```powershell
python -m tools.museum.acquisition_packet_v2 assemble --acquisition out/acquisition-accession --acquisition-hash 0xACQUISITION --packet-schema-hash 0xV2SCHEMA --authority-profile-hash 0xAUTHORITY --disclosure public --output out/acquisition-packet-v2
python -m tools.museum.acquisition_packet_v2 verify out/acquisition-packet-v2 --manifest-hash 0xMANIFEST
```

Assembly is offline, verifies every derived file before publication, and requires
a new output directory. The common museum package verifier recognizes the new
distinct assembly mode. `complete-packet` verifies the package and reports all
unresolved requirements; it cannot silently create a complete packet from this
partial evidence set.

## Required producer dependencies

The [conservation and condition dependency ledger](museum-packet-producer-dependencies.md)
records implementation gaps and accountable owners for items 13 and 15. Their
missing declaration, canonical-host and current-selection evidence cannot be
replaced with a waiver, empty arbitrary-host query or assumed default.
