# Recorded preservation objects and rights

`STREAM_MUSEUM_PRESERVATION_RESOURCES_V1` adds canonical preservation-object
subjects and structured historical rights statements to the museum exporter.
It retains the existing file-only, fixity and event profiles unchanged. It is a
finite supplemental profile, not a claim that the complete registered PREMIS
crosswalk or institutional conformance requirements have been met.

## Object evidence

The exact prospective schemas and profile are under
[schemas/museum/preservation-resources](../schemas/museum/preservation-resources/profile.json).
`STREAM_MUSEUM_PRESERVATION_OBJECT_V1` requires the complete original
`PreservationObjectRef`, collection ID, an explicit raw-content hash algorithm,
format evidence, significant properties and relationships. It is published under
the existing `INDEPENDENT_SEMANTIC_ASSERTION` family. The reader requires its
actual registered schema bytes, original JCS canonicalization, whole-record
selector and historical independent-account authority.

The containing record's subject must be exactly
`STREAM_SUBJECT_MEDIA_V1(chainId, Core, collectionId, objectId)` from
[CMC-SUBJECT-ID](collection-metadata-contract.md#subject-identity-cmc-subject-id).
PREMIS `objectIdentifier` uses type `6529STREAM_SUBJECT` and this derived subject.
The original object ID remains separately retained; a media URI, record hash and
subject hash are not interchangeable identifiers.

| Original fact | PREMIS rendering |
| --- | --- |
| contentHash and explicit SHA256/KECCAK256 | Declared message digest and algorithm; no measured check or event |
| byteSize | Exact size, with explicit unsupported result above PREMIS xs:long |
| formatId and PRONOM PUID | Require `keccak256("PRONOM:" + puid)`; record the registry key |
| mimeType | Original format designation |
| objectRole | Explicit significant property using one of the twelve adopted role labels |
| significantProperties | Exact recorded type and value text |
| relationships | Only explicit structural/derivation links to selected objects in the same collection |
| uri | Original content location, without fetching |
| schemaId | Complete original typed source and correspondence; zero is never replaced by a guessed schema |

All twelve roles from SOURCE_CAPTURE through ACCESSIBILITY_TRANSCRIPT are
supported. The adapter never invents a master/derivative relationship from role
labels. A registered Stream format-catalog mapping is not yet supported by this
version; an unavailable mapping gives an exact unsupported result. A PRONOM
reference checks declared identity and syntax, not detected format, registry
availability or actual file bytes. Multiple versions of one object subject need
an explicit prior selection; duplicate selected subjects reject.

## Historical Metadata rights source

An independent account statement cannot be promoted to a `RIGHTS_STATEMENT`.
`MetadataRightsSource` reads a separate, externally pinned Metadata deployment at
one canonical block. It accepts actual original class 7/8 receipts only, with the
original `RIGHTS_STATEMENT` family, exact `STREAM_RIGHTS_V1` and
`STREAM_RIGHTS_JSON_PROFILE_V1` bytes, original JCS definition, canonical subject,
record hash, stored index and immediate record-chain join. Payload bytes come
from the pinned original immutable store. Core, Metadata, registry and store
addresses and code hashes must agree, including the Core's selected Metadata
pointer at the anchor block.

The selected records may be collection- or token-scoped. Their original receipts
prove admitted scope within the trusted native/RPC boundary; current memberships
are not substituted for historical authorship. The reader does not infer which
record is currently selected, traverse or claim a complete rights history, apply
token-over-collection precedence, or reauthorize a historical writer. Declared
predecessors remain source evidence, not an independently accepted current
lineage. These are historical-row exports, not the current rights reducer.

The reader requires external block, code and transcript commitments. It supports
exact offline replay through the existing read-only transport. It does not prove
Ethereum state tries, consensus finality, the honesty of an RPC endpoint or the
truth of externally admitted deployment evidence. No capture or broadcast occurs
when building or verifying a package.

## Rights links and serialization

`STREAM_MUSEUM_PRESERVATION_RIGHTS_LINK_V1` is a separately recorded independent
link, containing the complete `PreservationRightsRef`, selected Metadata record
hash and explicit object IDs. Its subject must equal the actual rights statement
subject; basis, URI and payload hash must match that statement. Linked objects
must belong to its original collection. The link remains an account assertion;
it does not grant rights or establish licensor authority.

The original registered rights schema is reused without modification. All six
use classes appear: reproduction, publication, exhibition, print, derivative and
ai_training. Each exact status becomes an act/restriction pair; denied and
unspecified remain explicitly denied and unspecified. Conditions, document
commitments and free-text extensions survive without being recast as permission.
`AI_TRAINING_PERMISSION`, when present, must agree with the original grant.

The original six bases, licensor identity variant, instrument URI/HashRef and
effective dates are preserved. The licensor is a reported `rightsHolder` link;
artist IDs and addresses do not create names or a guessed person/organization
type. Each licensor reference is scoped to the selected RIGHTS record, so equal
names in separate statements do not merge legal identities. Estate and institution
names remain names asserted in that statement.
Instrument and conditions bytes are not fetched, and a hash is not a claim that
the instrument is available or legally effective.

Date-only grant dates remain date-only in PREMIS. The independent
PreservationRightsRef supplies its own Unix seconds, retained in correspondence;
these must agree with the source calendar dates. Explicit null end remains open,
and invalid order rejects. Missing/unrepresentable reference times withhold XML
rather than inventing midnight, current time or a replacement date.

The source and export are notice/evidence only. They do not prove legal identity,
ownership, license validity, enforcement or independent review. Preservation and
collector use classes remain explicit source acts, rather than inferred from one
another. The exporter does not execute or enforce a rights statement.

## Offline derivative and commands

`recorded_preservation_resources_package`, version 1, preserves the original
recorded v2 package literally under `source/`, including its manifest. That source
package must already retain the pinned PREMIS dependency closure; its prior
file-only projection may be unsupported. The new object facts are not inferred
from that earlier file profile.

The new package adds typed schemas/profile, exact plan, full source authority,
correspondence and report, and supported PREMIS XML. Optional Metadata inputs are
retained separately under `metadata-rights/` with their original anchor,
transcript, deployment evidence and reconstructed selected source. Both sources
must share chain, Core and block. No derivative chains or restricted exports are
accepted. The complete inventory and all regenerated bytes must match on verify.

```json
{"mode":"recorded_account_preservation_resources_projection","version":"1","sourceStateHash":"0x...","accountProfileHash":"0x...","resourceProfileHash":"0x...","rightsSourceHash":null,"objects":[],"rights":[]}
```

Use complete whole-record selectors in objects/rights. The empty object list
produces precise unsupported evidence. Rights may remain unselected; this does
not claim rights completeness. If rights are selected, supply the separate
Metadata input directory and canonical pins document with exactly `anchorHash`,
`transcriptHash` and `sourceHash`. The input directory contains `anchor.json`,
`transcript.json` and `deployment-evidence.json`; external commitments must refer
to the actual intended source, not be invented to bless untrusted responses.

```text
python -m tools.museum.resource_package build SOURCE_PACKAGE PLAN.json OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public
python -m tools.museum.resource_package build SOURCE_PACKAGE PLAN.json OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public --rights-inputs METADATA_INPUTS --rights-pins METADATA_PINS.json
python -m tools.museum.package_v2 verify OUTPUT --manifest-hash PRINTED_HASH
python -m unittest tools.museum.test_preservation_resources -v
```

Output directories must not exist. Public classification covers both source
families and all retained input bytes. Missing selected format/object evidence
produces an unsupported report; malformed, contradictory or unauthenticated
present evidence rejects. Neither path silently substitutes an independent
quotation for an actual Metadata receipt.

## Validation boundary

Positive canonical-object and native-ABI response controls are synthetic, with
all original authority boundaries named. Tests exercise the original registered
schema bytes, all twelve roles, six rights bases/four statuses, licensor variants,
dates, receipts and hostile response/link controls against the pinned PREMIS XSD.
The existing actual account capture supports missing-object diagnostics and
literal package/CLI replay only. It is not relabelled as an actual positive RIGHTS
or preservation-object capture. No new Solidity build, network capture, schema
registration, complete current-rights selection or institutional acceptance is
claimed by this source batch.