# Collection preservation reader capacity

Three collection-preservation libraries exceeded the unchanged 24,576-byte
runtime limit at source `ea4cf6b0a2cfa7bba529284a3cfe46bb19b6604b`:
`StreamPreservationPolicyReferenceRecordsV1` (28,338 bytes),
`StreamPreservationPolicyReferenceSourceReadsV1` (32,643 bytes), and
`StreamPreservationPolicyRenderCriticalTokenReadsV1` (27,228 bytes).
The retained shared native capture measured these exact products together.

## Fixed extraction boundaries

The record library retains preparation, receipt/publication memory normalization,
and definition admission. `StreamPreservationPolicyReferenceRecordReadsV1`
owns the original historical payload decoder, record-byte getter and the current
source/payload checks that follow definition admission. Its storage arguments
refer to the same original host slots.

`StreamPreservationPolicyReferenceSnapshotPayloadReadsV1` owns the complete
snapshot payload read and canonical nested decoder. It retains the original
receipt deep copy before normalization. The original reader restores the
publication's `expectedSourceHash = 0` in its caller's memory after a successful
linked return, preserving the internal call's memory effect. Its saved receipt,
root joins, archive validation and ordered samples retain their original values
and sequence.

`StreamPreservationPolicyTokenOriginalReadsV1` owns the original selection,
output, preservation admission, token identity, entropy, configuration and raw
source reads. The original host still declares `Original`, including its dynamic
entropy bytes, so both the ABI's nominal tuple and the literal source commitment
remain unchanged. The helper's import of this type creates no runtime link back
to the host. The host retains its five propagated error ABI declarations.

All calls use fixed linked-library delegation. Dependencies observe the same
host, hashes retain `address(this)`, and caller identity is preserved. There is
no configurable dispatch, new storage, new profile, changed hash preimage,
changed read order or increased read budget. Additional linked frames consume
execution gas and EIP-150 headroom; this extraction does not claim gas parity.

## Validation boundary

The original ABIs and storage layouts are compared against the frozen source.
Source inverse checks reconstruct the original functions and hosts and reject
changes to the receipt copy, caller-memory normalization, dynamic entropy
encoding, read bounds, read order, tuple declarations and unaccounted helper code.
Focused record regressions compare original byte/read bodies with the repaired
host using genuine manifest chunks, including canonical refusal and storage
canaries. Existing collection publication and token inventory tests retain their
full source-hash, producer, terminal/finalized entropy and late-retry cases.

The bounded native capture selects only the three original libraries and their
three new workers. It retains actual native ASTs, metadata, ABI, storage layout,
complete creation/runtime outputs, link references and method identifiers under
the original Solidity 0.8.19, via-IR, optimizer-200, Paris, no-CBOR configuration.
The complete initcode limit remains 49,152 bytes; these libraries have no
constructor arguments. Native measurement and regression execution remain
pending until the associated evidence is recorded.

Selected library capacity and source checks do not establish linked deployment,
complete collection publication, finality, cold transaction cost or full-graph
runtime acceptance. Scoped V1/V2 libraries and the isolated Collector experiment
are outside this change.
