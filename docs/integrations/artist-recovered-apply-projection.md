# Recovered owner apply decoder projection

The joined Solidity 0.8.19 build failed while generating
`StreamArtistRecoveredOwnerHydration`. Selecting that library alone reproduced
the same `dst_9` / `src_9` Yul stack exception, independently of the Payout tests
and Forge's source AST selection. The original failed captures remain retained.

`StreamArtistRecoveredHydrationOwnerPayload.decodeForApply` invokes the existing
complete `decode` implementation, including canonical envelope, owner/profile,
provenance, header, nonce, semantic-state and publication-catalog checks. It then
returns only provenance and publication rows, the two fields the apply worker
consumes. The original full decoder remains available with its unchanged ABI.

The apply worker keeps its original calldata tuple, caller and operation guards,
source/destination relationship checks, and ordered calls to `installOwnerPrefix`,
`applyGuards`, and `applyCatalog`. Its final state hash remains after those calls.
No replay or storage mutation moved into a new helper. This is distinct from the
unapplied replay-write relocation proposal.

The exact repaired pair compiles with via IR, optimizer 200, Paris and no CBOR.
The payload library measures 13,757 runtime / 13,789 creation bytes; the recovered
apply worker measures 8,398 / 8,432. These selected results do not establish full
hydration execution or whole-system deployment capacity.

Four focused pure tests compare original full decoding with the projected result,
including populated and empty publication rows and fuzzed bytes. They also require
identical refusal bytes for invalid omitted semantic/nonce fields, wrong owner,
trailing envelope data, duplicate catalog entries and altered provenance. Their
synthetic inputs do not establish source-owner or stored-carrier authority.
Native execution status is recorded separately from the source/codegen evidence.
