# ADR 0040: Current metadata record host and authority boundary

Status: Accepted implementation decision under the owner's autonomous delivery
authority, 12 September 2026. Full-v1 conformance remains separately tracked.

Issue: [#743](https://github.com/6529-Collections/6529Stream/issues/743).

## Decision

R1. Introduce `StreamCollectionMetadataV1` with a distinct
`IStreamCollectionMetadataV1` discovery interface. Core's current metadata
pointer validation and the finality adapter require that interface. Preserve
the earlier `StreamCollectionMetadata` implementation and its interface for
existing callers and historical evidence. The new host does not advertise the
earlier interface or pretend to implement its rendering and locking methods.
The frozen RC1 source and deployment are unchanged.

R2. An accepted record retains its complete tuple, immutable interpretation
identities, original recorder, bytes, index and chain commitment. Permissionless
chunk publication alone grants no record authority. Historical reads do not
depend on the current host selection, current artist authority or active schema
status. New generic publication requires admitted types, active interpretation
documents and the selected host. Dedicated independent and owner records, and
typed intersection-checked snapshots, remain separate mechanisms.

R3. Catalog admission and family grants require exact delayed class-1 Executor
transitions proposed by the live governance root. The target verifies the stored
action proposer as well as the active per-call context. Every transition scope
commits the root address, pinned code hash and monotonic root revision. A root
rotation, including an address changing away and back, invalidates queued
configuration scopes. This is a stricter family-role configuration boundary;
it does not extend root-only proposer requirements to unrelated governance
targets or rewrite the shared governed-gas-parameter policy.

R4. Preserve the existing generic record tuple and fourteen-word hash preimage.
The canonical `CollectionRecordRecorded` event uses the specified `bytes32`
authorization class, encoded by zero-extending the existing numeric classes
1 through 8. This does not replace the earlier event's ABI. Family masks remain
`uint16(1) << class`, and all consumers must use the event ABI for the emitting
host version. The [record guide](../integrations/metadata-records.md) lists the
class meanings and exact history behavior.

R5. Detached artist publication uses the additive typed publication capability
and a separate consumed authorization backlink. The record preimage never
includes its own authorization or publication hash. The artist registry owns
signature, association, generation and capability validation; the metadata host
owns the actual candidate bytes, subject, schema, selected host and atomic
append. Late failures revert authorization consumption and new chunk storage.

R6. Generic byte retention is a foundation for typed evidence. It does not
validate arbitrary JSON-schema meaning, freeze renderer inputs or establish
artwork finality. The host advertises no finality-component-facts interface
until it derives those facts from actual typed records. Source maps and
integration documentation must expose this boundary explicitly.

## Validation and remaining composition

The corrected focused cohort contains fifteen host and eight adapter cases,
with 256 fuzz inputs, in both compiler modes. It includes the actual schema
registry/store, the current Core pointer-validator library and Safe 1.4.1;
Core, Executor, artist-authority and module-registry substitutes remain explicit.
The governance-root regression replaces an earlier passing cohort whose
target-side proposer check was missing. Three independent cases exercise the
exact guard with the actual sealed Executor and RoleRegistry, including an
ordinary proposer and a second batch element with a long reason URI. That
harness uses a minimal guarded target; full-host governance composition,
actual artist publication, complete typed finality and the full Safe selector
matrix are tracked in the [delivery ledger](../../ops/V1_DELIVERY.md).
