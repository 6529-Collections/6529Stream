# Collection preservation reader capacity

Three collection-preservation libraries exceeded the unchanged 24,576-byte
runtime limit at source `ea4cf6b0a2cfa7bba529284a3cfe46bb19b6604b`:
`StreamPreservationPolicyReferenceRecordsV1` (28,338 bytes),
`StreamPreservationPolicyReferenceSourceReadsV1` (32,643 bytes), and
`StreamPreservationPolicyRenderCriticalTokenReadsV1` (27,228 bytes).
The retained shared native capture measured these exact products together.

## Fixed extraction boundaries

The record library retains its exported definition checks.
`StreamPreservationPolicyReferencePreparationV1` owns the exact original
preparation body and a private copy of its definition checks. On successful
return, the original facade reapplies the seven original publication/receipt
memory assignments, including the computed source hash. The private definition
copy avoids a runtime link back to the facade.
`StreamPreservationPolicyReferenceRecordReadsV1` owns the historical payload
decoder, record-byte getter and current source/payload checks that follow
facade definition admission. Its storage arguments refer to the same host slots.

`StreamPreservationPolicyReferenceDependencyReadsV1` owns the exact dependency
binding and archive object-identity checks. Their facade forwarding calls remain
at the original positions in the source-read sequence.
`StreamPreservationPolicyReferenceSnapshotPayloadReadsV1` owns the current
snapshot evidence, canonical record and payload reads. The payload decoder keeps
the original receipt deep copy and publication normalization. Its returned
receipt retains the original record fields, and the facade continues with the
same root-head check, count guard, archive validation and ordered samples.

`StreamPreservationPolicyTokenOriginalReadsV1` owns the original selection,
output, preservation admission, token identity, entropy, configuration and raw
source reads. The original host still declares `Original`, including its dynamic
entropy bytes, so both the ABI's nominal tuple and the literal source commitment
remain unchanged. The helper's import of this type creates no runtime link back
to the host. The three original facades retain their propagated error ABI
declarations.

All calls use fixed linked-library delegation. Dependencies observe the same
host, hashes retain `address(this)`, and caller identity is preserved. There is
no configurable dispatch, new storage, new profile, changed hash preimage,
changed read order or increased read budget. Additional linked frames consume
execution gas and EIP-150 headroom; this extraction does not claim gas parity.

## Validation boundary

All three original ABIs, storage layouts and method-identifier maps exactly
match the frozen baseline in the final native outputs.
Source inverse checks reconstruct the original functions and hosts and reject
changes to the receipt copy, caller-memory normalization, dynamic entropy
encoding, read bounds, read order, tuple declarations and unaccounted helper code.
Focused record regressions compare original byte/read bodies with the repaired
host using genuine manifest chunks, including canonical refusal and storage
canaries. Existing collection publication and token inventory tests retain their
full source-hash, producer, terminal/finalized entropy and late-retry cases.

The bounded native capture selects only the three original libraries and their
five new workers. It retains actual native ASTs, metadata, ABI, storage layout,
complete creation/runtime outputs, link references and method identifiers under
the original Solidity 0.8.19, via-IR, optimizer-200, Paris, no-CBOR configuration.
The complete initcode limit remains 49,152 bytes; these libraries have no
constructor arguments. The first retained six-product capture correctly refused
Records at 26,464 bytes and SourceReads at 28,955 bytes. That refused capture was
preserved before the further typed extraction.

The final eight-product capture uses source
`7ba7f36da71d142919d0caa16af59c392dd20d67`, with 196 exact Git sources and one
sequential compiler worker. Analysis and native code generation completed in
104.125 seconds total. All selected products fit the original limits:

| Product | Runtime bytes | Complete initcode bytes |
| --- | ---: | ---: |
| `StreamPreservationPolicyReferenceDependencyReadsV1` | 4,157 | 4,189 |
| `StreamPreservationPolicyReferencePreparationV1` | 17,209 | 17,241 |
| `StreamPreservationPolicyReferenceRecordReadsV1` | 15,094 | 15,126 |
| `StreamPreservationPolicyReferenceRecordsV1` | 12,915 | 12,947 |
| `StreamPreservationPolicyReferenceSnapshotPayloadReadsV1` | 11,574 | 11,606 |
| `StreamPreservationPolicyReferenceSourceReadsV1` | 22,170 | 22,203 |
| `StreamPreservationPolicyRenderCriticalTokenReadsV1` | 20,658 | 20,690 |
| `StreamPreservationPolicyTokenOriginalReadsV1` | 20,768 | 20,800 |

The actual native input SHA256 is
`a8811979552b140ff7645a7668ce233d784dbef124a1f8c4c5130f2b89c8a1be`;
the actual native output SHA256 is
`2f9a1f4a94327ff29324439a9c6e5ad98dc6f7d4a405cc957e79e8e4598ce869`.
The immutable local capture is under `out/preservation-reference-native-v2`.
Its `HANDOFF.json` SHA256 is
`5db6d834519c0a250afb381fc4ec9b2ac5963eee84ac6a2a548a19326e77dc92`.
The earlier refused capture remains under `out/preservation-reference-native-v1`.

Both source-inverse checks and all 49 Python regression tests pass. The final
1,016-source ABI pass reports zero compiler errors and typechecks all eight new
Solidity test cases. Those eight cases are authored and typechecked, not executed.
Run the bounded source checks from the repository root with:

```text
python -B -m tools.development.check_preservation_record_capacity
python -B -m tools.development.check_preservation_reference_capacity_inverse
python -B -m unittest tools.development.test_preservation_record_capacity tools.development.test_preservation_reference_capacity_inverse
```

The pinned Forge serializer produced one authenticated physical owner context for
all eight products, without another compiler invocation. Canonical owner loading
and rechecking passed with the original native outputs unchanged. The owner
evidence SHA256 is
`7f59b58b766e08ea20ed7eb1eb8cf1a2c019ae479220f3d0105abe0085ee58cd`;
`OWNER_ADDENDUM.json` retains the exact owner paths and hashes. Cross-context
library-link admission and EVM execution remain separate acceptance.

Selected library capacity and source checks do not establish linked deployment,
complete collection publication, finality, cold transaction cost or full-graph
runtime acceptance. Scoped V1/V2 libraries and the isolated Collector experiment
are outside this change.
