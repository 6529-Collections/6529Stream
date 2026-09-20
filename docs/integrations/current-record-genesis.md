# Current record-product composition

[`StreamFullV1RecordProducts`](../../script/current/StreamFullV1RecordProducts.sol)
constructs the original full-byte `StreamPreservationRecordsV1` and additive
`StreamGeneralAttestations`. They supply role27 and the general/notarized part
of role28 in the full-v1 candidate. The existing independent-class5
`StreamCollectionAttestations` remains a separate required product. The
[legacy preservation adapter](current-preservation-governance.md) remains
optional compatibility support.

## Construction and admission

Supply the actual current Core, Governance Executor, selected MetadataV1,
SchemaRegistry and original Artist Registry. `artistAttribution` is the original
Artist suite's `owners[4]`, obtained from its actual Coordinator. Deploy after
those products exist and their reciprocal bindings are established.

The helper checks the common Core, Executor, metadata and schema bindings,
including the same chunk store and the Artist Registry/Coordinator/attribution
relationships. It retains the configuration hash, chain ID and all seven
dependency runtime hashes, plus both product runtime hashes. Later validation
rechecks these observations. They do not authenticate compiler output or prove
deployment provenance; final acceptance must join the exact native artifacts.

Construction grants no writer privileges and selects no Core pointer. Use the
actual catalog stage planner to append the two returned class1 gas-raise
policies with its required SystemManifest publication. Register both returned
module rows through the current registry, also with the required manifest tail.
Use the products' actual ERC165 interfaces and manifests. Neither row replaces
MetadataV1 or the existing independent attestation host.

Record interpretation documents must already be retained and active in the
original SchemaRegistry. Admit preservation record types and grant family
writers through MetadataV1's original governed transitions. Preservation writes
also check that MetadataV1 remains selected and both it and the preservation
host remain eligible in the actual ModuleRegistry. See the
[full-byte preservation guide](preservation-records.md) and
[general attestation guide](general-attestations.md) for the producer contracts.

## Authority and evidence

- Preservation uses the original admitted family/class mask and an explicit
  collection or global family grant. A Safe grant belongs to that Safe address,
  not to an individual signer or another Safe with the same owners.
- Curatorial assertions require the exact collection's class3 `CURATOR` grant.
  The general host does not use the global grant as a fallback.
- Institution and estate signatures retain `GENERAL_SIGNER_CLAIM`
  classification. An ERC1271 signature proves account authorization, not legal
  identity, factual truth or native Artist authority.
- An Artist statement additionally joins its exact original op24 receipt,
  attribution owner, record, terms, statement bytes and authority class. The
  new general signature does not replace that historical proof.
- Typed identity notarization retains the exact checked-in notarization schema,
  JSON profile and RFC8785 JCS definition. It binds the actual selected Artist
  Registry and operative identity record without elevating the general signer.

## Current-stack acceptance scope

[`StreamCurrentRecordGenesisTest`](../../test/current/StreamCurrentRecordGenesis.t.sol)
authors eight cases using the actual Core, Executor, ModuleRegistry,
MetadataV1, SchemaRegistry/store, original modular Artist suite and official
2-of-2 Safes. The inherited upstream entropy service is an explicit double.
Cases cover constructors/admission, signed institution and estate claims,
different-Safe/replay rejection, exact curator grants and revocation, a full
24,576-byte three-chunk preservation record with event/history readback, actual
op24 joining, typed notarization and changed dependency/product refusal.

The generic and native op24 schema definitions in these tests are explicitly
synthetic fixture documents. Only the notarization/schema/profile/JCS files are
the original checked-in definition bytes. No institutional review or legal
identity verification is asserted.

At the composition base `8d1672ac`, preservation supports 24,576 bytes and
general attestations support 8,192 bytes. The separately owned general and
MetadataV1 capacity successors must be integrated and revalidated before a
uniform 24,576-byte candidate claim. These tests do not imply full37 construction,
complete publication capacity, final gas calibration, executed native acceptance,
deployment-size acceptance, full CI, audit completion or testnet readiness.
