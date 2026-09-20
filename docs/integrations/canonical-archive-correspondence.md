# Canonical ABI inventory and archive correspondence

Native Snapshot, Reference and preservation publishers retain compiler-ABI
payloads with explicit schema and canonicalization identifiers. Their inventory
rows must keep those identifiers when archived. Relabelling a row as RAW_BYTES,
JCS or an onchain object would change the original inventory commitment.

`StreamBundleArchiveReads` admits the closed tuples below through
`StreamInventoryAbiCorrespondence`. The existing RAW_BYTES, RFC8785_JCS,
EXTERNAL_OBJECT and ONCHAIN_OBJECT paths keep their original behavior. No
canonicalization identifier is a general permission to archive arbitrary native
or external-reference rows.

## Authority and byte evidence

The fixed inventory producer authenticates the original publication and exact
schema, profile and canonicalization document hashes before constructing rows.
The archive consumer authenticates the complete row against the producer's
ordered segment before calling the shared reader. `Item` has no independent
profile field: accepting a tuple here does not validate a caller's publication
or create a new source authority.

The new correspondence branch only recognizes the byte interpretation. Admission
still requires an exact 32-byte digest, matching canonicalization, positive
covered size, matching declared size when present, exact schema, original object
and coverage identifiers, and the original artist. Onchain admission still reads
every immutable STOP chunk, verifies its bytes, and retains original dual-family
receipt, fixity, checkpoint and envelope bundles. External admission still
checks the original object, current receipt pair and all original bundles.
Backend restrictions, environment checks and later liveness remain unchanged.

## Closed native tuples

Identifiers below mean `keccak256` of the literal string. `ABI` abbreviates
`STREAM_SOLIDITY_ABI_V1`. Every row uses algorithm 1 (Keccak-256) and a positive
known byte size. Kind is ORIGINAL_PAYLOAD except the last two NATIVE_BYTES rows.

| Role | Schema | Canonicalization |
| --- | --- | --- |
| `REFERENCE_MANIFEST` | `STREAM_REFERENCE_MODE_ABI_V1` | ABI |
| `CURATED_CONDITION_ORIGINAL_PAYLOAD` | `STREAM_REFERENCE_CURATED_CONDITION_ABI_V1` | ABI |
| `SCOPED_SNAPSHOT_MANIFEST` | `STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1` | ABI |
| `SCOPED_REFERENCE_MANIFEST` | `STREAM_SCOPED_REFERENCE_RENDER_ABI_V1` | ABI |
| `POLICY_SNAPSHOT_MANIFEST_V2` | `STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2` | `STREAM_ABI_POLICY_COLLECTION_SNAPSHOT_V2` |
| `REFERENCE_MANIFEST` | `STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2` | `STREAM_ABI_POLICY_COLLECTION_REFERENCE_V2` |
| `SCOPED_POLICY_SNAPSHOT_MANIFEST_V2` | `STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2` | `STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2` |
| `SCOPED_POLICY_REFERENCE_MANIFEST` | `STREAM_SCOPED_POLICY_REFERENCE_ABI_V2` | `STREAM_ABI_SCOPED_POLICY_REFERENCE_V2` |
| `POLICY_SNAPSHOT_MANIFEST_V2` | `STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V1` | `STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V1` |
| `REFERENCE_MANIFEST` | `STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V1` | `STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V1` |
| `SCOPED_POLICY_SNAPSHOT_MANIFEST_V2` | `STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V1` | `STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1` |
| `SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST` | `STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V1` | `STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V1` |
| `COMPLETE_SIGNIFICANT_PROPERTIES` | `STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1` | ABI |
| `METRIC_SUPPLEMENT_PAYLOAD` | `STREAM_REFERENCE_METRIC_SUPPLEMENT_ABI_V1` | ABI |

Each Snapshot/Reference schema has its corresponding `..._PROFILE_V1` or
`..._PROFILE_V2` identifier in the original Definitions library. The reference
mode manifest, CURATED condition and significant-properties native row share
`STREAM_REFERENCE_MODE_PROFILE_V1`. The metric supplement uses
`STREAM_REFERENCE_METRIC_SUPPLEMENT_PROFILE_V1` and the PERCEPTUAL branch.
The preservation collection and scoped profiles remain distinct from their
original policy V2 counterparts, including where a role string is shared.

The source constructors are the collection/scoped NativeReads and
ReferenceInventoryReads libraries, plus `StreamReferenceModeInventory` and
`StreamReferenceMetricInventory`. Original COLLECTION snapshot/reference JSON
continues to use JCS. ABI source facts, policy lists, root records, output records
and declarations intentionally retain RAW_BYTES where their producer says so.

## Original significant-properties reference

Artist intent also retains a separate EXTERNAL_REFERENCE occurrence with role
`SIGNIFICANT_PROPERTIES`, source index 8, zero schema and unknown byte size 0.
Only that exact occurrence with `STREAM_SOLIDITY_ABI_V1` and algorithm 1 or 2
(Keccak-256 or SHA-256) gains ABI correspondence. The archive must supply a
positive covered size and match the original selected digest. The native
complete-properties row cannot substitute for this independent obligation.

This reference can occur outside CURATED. Archive admission establishes byte
correspondence to the original authenticated Artist intent; CURATED's separate
assessment establishes its correspondence to `abi.encode(properties)`. Other
intent, institution or credentials references do not inherit this exception.

## Scope and validation boundary

The existing scoped inventory producers cover TOKEN, RELEASE and SEASON.
VIEW output manifests currently consume typed onchain artifact carriers
directly; they have no preservation `Item` producer here. Their existing
ONCHAIN_OBJECT/whole-byte coverage path needs no invented native tuple.

The matcher tests cover all 14 native tuples, cross-profile substitutions,
kind/algorithm/size restrictions, unknown identifiers and the separate original
reference. Focused actual-producer tests preserve genuine scoped Snapshot and
Reference rows through real dual-family archive contracts and check mutation,
proof and liveness failures. Those fixtures retain named Core, Artist,
governance and external screenshot boundaries. They do not establish a complete
current-stack bundle, VIEW inventory support or shipping transaction gas.

The combined source ABI check and small matcher runtime suite are separate from
the full actual-producer native run and integrated publication ceremony. The
latter remain integration acceptance work; this change does not refresh release
artifacts or change readiness claims.
