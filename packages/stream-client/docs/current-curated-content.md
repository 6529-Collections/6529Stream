# Curated selected-work manifests

`current-curated-content.ts` builds the exact publication accepted by the native
selected-work gate at carrier commit `187a55af`. The compiler fixture is pinned
to joined source `5605d019`, with all 128 input sources recorded. These helpers
prepare data and perform read-only checks; they do not deploy a gate or transact.

## Build the complete publication

Call `buildCuratedManifest` with the verified chain, Manager, carrier, original
sale ID, collection, phase, content counter and every published row. Each row
contains a `contentId`, the hash of its exact token bytes and a preview URI.
Rows must already be strictly increasing by content ID. The helper rejects
duplicates and out-of-order rows. A zero content ID and empty token bytes are
valid; empty bytes must use their actual nonzero `keccak256` hash.

The result contains the exact `abi.encode(Row[])` manifest bytes, its hash,
publication and ordered selections with Merkle proofs. Leaves use the original
double-hashed content domain. Tree nodes use sorted-pair hashing, and an odd
last node moves unchanged to the next level. An odd node is not duplicated.
The selected content ID never chooses a token ID or serial; Core allocates those
in mint order. A new sale has a new content identity and does not establish
collection-wide lifetime uniqueness.

Each returned `manifest.selections[index]` is directly usable as the `content`
field of `CuratedSelection`. Supply the exact token bytes, nonzero mint
commitment, recipient and purchase nonce, then call `normalizeCuratedSelection`.
The normalizer checks the bytes against the selected hash. Proof membership can
be checked separately with `verifyCuratedContentProof`; membership alone does
not prove that the manifest is complete or that a purchase is admitted.

The client bounds manifests to 4,096 rows, preview references to 8,192 UTF-8
bytes each and proofs to 256 sibling hashes. These are client resource limits.
The 8,192-byte raw token-data limit comes from the carrier itself. The helper
copies and freezes inputs rather than retaining mutable caller arrays.

## Keep the identities distinct

| Helper | Identity |
| --- | --- |
| `curatedSaleId` | Original creation nonce, collection and phase; fixed kind `0`, private kind `5` |
| `curatedPurchaseId` | Original sale, buyer and per-buyer purchase nonce |
| `curatedContentLeaf` | Original sale, content ID and exact token-data hash |
| `curatedContentContextHash` | Original sale and content ID; used by its cap-one counter |
| `curatedSelectionCommitment` | Original sale, buyer, selected leaf and salt |

The purchase ID is not the receipt's prepared-native execution ID. A private
TICKET authorization is another identity, wrapping the original Sales digest.
Commitment salt may be zero as an encoding matter; callers should generate and
retain a private unpredictable salt for a commit/reveal purchase. Do not publish
the selected preimage before revealing it.

## Read back the admitted publication

After gate deployment, use `inspectCuratedManifest(provider, gate, manifest,
{ blockTag })` with a concrete block number. It compares all stored manifest
bytes and rows, publication fields, count, purchase capability and the gate
configuration hash. It also compares the observed Manager and carrier runtimes
with the hashes saved in the gate. Responses are bounded before ABI decoding.

This establishes consistency with the reviewed manifest and those observed
runtime hashes. It does not compare the deployment to a canonical release,
verify external preview availability, establish current sale admission or
check for a reorganization during the numeric-block reads. Deployment evidence,
block-hash confirmation and the carrier's exact payable simulation remain
separate steps.

Use the [fixed and commit/reveal guide](current-curated-fixed.md) or the
[private selected-work guide](current-curated-private.md) for the carrier flow.
