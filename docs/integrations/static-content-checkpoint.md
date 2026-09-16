# Actual STATIC full-output checkpoints

`StreamStaticContentCheckpoint` computes content and output commitments from the current full
Router output for every token in a completed `StreamStaticSelectionCheckpoint`. It is a
permissionless computation producer. It does not publish an authoritative content root or
satisfy an artwork-finality acceptance mode by itself.

The fixed constructor pins the selection producer, Core and Router. `begin(selectionId, salt)`
requires the original completed, currently valid selection. The salt distinguishes attempts;
it cannot supply membership, rows, readiness or output hashes. Each append obtains the next
token from the original ordered selection, checks its full frozen configuration and literal
source snapshot, and reads its actual original `coordinatorAtMint`. Entropy must be finalized.
No caller-owned list is accepted as a complete scope.

For each token the producer reads actual Router `tokenJSON` and `tokenHTML`, plus original Core
`tokenData`. These are the full methods, including full immutable script/dependency-bundle
reconstruction by the selected renderer. The fixed STATIC-v1 field matcher verifies that the
JSON contains exactly that HTML and token data. A nonempty image must be the exact decoded
bytes of the selected inline base64 image URI; an absent image has a zero hash. Remote images
are unsupported by this onchain-byte profile. It does not call a network or hash an unresolved
URI as if it were image bytes.

The original six-field `StreamTokenContentLeaf`, leaf domain, node domain, ordered Merkle
pairing and odd-node promotion remain unchanged. The separate `OUTPUT_CHAIN` commits each
complete output row, including the original selection-row hash, exact source/entropy facts,
metadata hash and HTML hash. It is an explicit ordered hash chain, not a replacement Merkle
algorithm or a native finality mode root. New events all carry schema version 1. Existing
inline and chunked checkpoint profiles, permanent preimages and consumers are untouched.

Current validation re-renders **every** prior row before appending or accepting a completed
checkpoint. Code pins and frozen Router configuration cannot prove that live Artist diagnostic
bytes, entropy facts or lifecycle disclosure remain unchanged. A change invalidates current
acceptance, while `checkpoint` and `outputAt` retain historical facts. An actual burned-token
output can be captured under a new salt; an earlier output is never silently normalized to hide
the burn. This profile uses the public full output, not a newly invented historical freeze
snapshot. Preserving stable artwork presentation separately from live status still requires
an explicit finality presentation profile and consumer binding.

The present profile accepts frozen `ONCHAIN` STATIC RendererV1 configurations. Collection,
token and published release/season membership come from the original complete selection host.
`VIEW` rejects because the current token route does not apply the distinct alternative-view
selection; base token output is not view output. `OFFCHAIN` and `HYBRID` need their own retained
snapshot/source-binding profile. These are remaining implementations, not inferred acceptance.

Append batches are bounded to four tokens and the current read visits all completed rows.
Returned bytes are bounded before copying; new governed dependency/render budgets control
this producer's calls. It does not raise Router or renderer budgets. The 16 MiB structural
bound is not a demonstrated gas or transaction-capacity claim. Large scopes may exceed an
available parent budget and fail closed; no partial result is labeled current. Cold nested
calls, worst-case capacity and combined deployment sizes remain to be measured.

The producer stores hashes and commitments, not the complete JSON/HTML/image artifact. A
reconstruction/export must retain those exact bytes with the original source selection and
checkpoint events. Current regeneration can reproduce them while current validation succeeds;
historical hashes alone do not reconstruct changed live Artist output. Typed authoritative
publication, schema/profile registration, preserved-artifact coverage, transitive STATIC
read-set/opcode conformance, and byte/perceptual/curated finality mode evidence remain separate
required joins under ADR 0041 and MRR-FINALITY.

Nine authored recipes compose actual Router, Renderer, Metadata/schema/store, inventory,
membership and a threshold Safe. Core, Artist authorization, version admission and governance
remain the named typed fixture boundaries. The tests cover original ordered three-leaf roots,
token overrides, actual 24,576-byte SSTORE2 reconstruction, exact image/animation rejection,
live Artist and burn changes, entropy/runtime/membership refusal, and full Safe rollback with
identical signed retry. A 221-source ABI check over committed source plus only this new producer
passes. No native runtime, actual-current ceremony, gas, size or conformance pass is claimed.
