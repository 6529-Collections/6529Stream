# Reference environment inventory preparation

The inventory serializer preserves the original canonical JSON, row ordering,
path validation and errors. It writes each row into one final output buffer;
relative paths use the original printable-ASCII restrictions, while absolute
paths retain the original UTF-8 and JSON quoting routine. Decimal quantities
remain strings and SHA-256 digests remain lowercase, fixed-width hex strings.

The isolated 26-source Solidity 0.8.19 capture passes eight tests, including
three sets of 256 differential fuzz cases against the frozen prior serializer,
every possible relative-path byte, zero/max quantities, duplicate and unordered
rows, and original size/error boundaries. The final closing bracket convention
is preserved, including the original maximum-length edge case.

The retained actual corpus contains 1,048 package members and 102 explicit
platform prerequisites. Their exact JSON lengths remain 162,109 and 15,583 bytes.
Measured direct-call package gas falls from 33,479,092 to 18,145,166; platform gas
falls from 4,084,702 to 3,102,427. These measurements include the test caller's
call overhead, not transaction calldata intrinsic gas. The package call alone
still exceeds the 16,777,216 transaction envelope, before host preparation and
retention. This optimization does not establish a usable complete preparation
transaction. A separate authenticated staged preparation flow is required.

No inventory identity, schema, hash domain, storage layout, writer authority,
gas cap or current-source check changes in this serializer batch. These tests
do not demonstrate a completed mode publication or a full current-stack flow.

## Authenticated staged preparation

`IStreamReferenceInventoryPreparation` is an additive companion implemented by
both reference publication hosts. The original publication interface IDs,
monolithic preparation methods and whole-inventory identities remain unchanged.
The new fixed worker receives the host's compiler-declared inventory mapping;
neither host adds storage.

1. Split the full original rows into consecutive groups of 64, with a final
   remainder of 1 through 64 rows. Preserve every original path, quantity and
   digest. Each group is encoded as its own canonical JSON array.
2. Preupload the exact part-array and complete-array bytes to the existing
   `StreamSchemaDocumentStore`, in ordered chunks of at most 8,192 bytes.
   Each upload is a separate zero-value call if required by transaction capacity.
3. Call `prepareFileInventoryPart(rows,relative)` for each group. It validates
   original row rules, authenticates preuploaded bytes and retains immutable
   pointers. Its part identity is `keccak256(abi.encode(domain,chainId,host,
   relative,rows))`, where `domain` is the Keccak of
   `6529STREAM_REFERENCE_FILE_INVENTORY_PART_V1`.
4. Call `prepareFileInventoryFromParts(fullOriginalRows,relative)`. The caller
   does not supply part IDs or totals. The producer derives every exact part
   identity from those full rows, checks boundary ordering and size limits,
   reconstructs the complete original JSON array, and authenticates its Store
   chunks. The resulting identity retains the original
   `6529STREAM_REFERENCE_FILE_INVENTORY_V1` domain and full-row preimage.
5. Use the original `preparedFileInventory(id)` readback and publication flow.

An empty full inventory uses zero parts and the exact preuploaded `[]` bytes.
Empty parts and parts larger than 64 rows are rejected. Part identities bind the
current host, chain and relative-path flag. Permissionless preparation creates
no writer, archive or source authority and does not establish that a caller's
declared environment lists every external package member.

Existing intact identities are idempotent and return without a new preparation
event. First successful writes emit schema-1 `ReferenceInventoryPartPrepared`
or `ReferenceInventoryAssembled`; a late missing chunk reverts every write and
event. The part and original domains share the existing mapping without letting
a part substitute for an original full-inventory identity.

The focused 30-source worker/Store capture passes six cases, including the full
1,048-row corpus, swapped/omitted/duplicate/truncated/substituted inputs, host,
chain and relative-flag mismatches, existing identities and late missing-chunk
rollback followed by retry. Its guarded test host passes an actual
compiler-declared mapping to the real worker and Store; it is not a complete
reference publication host. The test explicitly cools its host, linked workers,
Store and recorded chunk pointers before the bounded calls.

For that corpus, measured transaction envelopes including ordinary calldata
intrinsic gas are 1,877,011 maximum for complete-array chunk uploads, 1,770,416
maximum for part preparation, and 12,768,072 for final assembly. Every tested
chunk upload and part call also enforces the 16,777,216 bound individually.
These results cover the recorded corpus, not every permitted maximum-length
path, all future gas schedules or a fully cold current protocol graph.

The affected production hosts and worker pass a separate 125-source ABI check
and selected size measurement: original host runtime 20,833 bytes, mode host
22,810, and worker 4,052. Actual publication-host runtime integration remains
pending. The independent reference publication decoder/copy capacity failure
recorded in the metric supplement guide also remains unresolved; this staged
preparation result does not waive it.
