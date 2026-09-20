# Scoped STATIC finality and acquisition V7

The Museum consumer can retain original TOKEN, RELEASE and SEASON finality
with the corresponding scoped STATIC snapshot, complete membership and ordered
output manifest. A new V7 acquisition export preserves all nineteen field
groups, the complete title V5 package and a separate scoped capture. Earlier
V6 collection-finality and generic packet branches remain supported.

This is prospective, unregistered tooling. Offline consistency checks do not
establish native execution, historical authority, complete preservation,
institutional acceptance or deployment readiness.

## Supported native evidence

The source profile pins native commit
`896899f7ca4130f86e066587f780a3b1f755a25d`. It supports original artist-bound
scoped STATIC in **ONCHAIN metadata mode**. TOKEN contains exactly its named
token. RELEASE and SEASON retain their complete sealed membership, including
members burned after publication. Current lifecycle observations do not
rewrite historical membership or the original Core-facts commitment.

The new fragment, `STREAM_ACQUISITION_SCOPED_STATIC_FINALITY_V1`, checks:

- Original Registry receipt, ten component expectations, exact scoped input
  manifest and identical retained Store bytes.
- All observed collection scoped root publications and aggregate transitions,
  including roots for other scopes. The selected root must be the last root
  for its scope before finalization. A later source-block head stays separate.
  The original finalized route cannot publish another root for that same
  scope; such an event history rejects. An opaque different historical route
  does not inherit the original route's authority.
- Original scoped snapshot payloads, revision chain and lock, complete native
  membership publication, selection checkpoint and coordinator inventory.
- Every ordered output row, exact multi-chunk manifest, artifact and coverage
  commitments, and the target token's ordered Merkle proof. Odd nodes are
  promoted without sorting or duplication.
- Exact original event payloads and chronology, successful receipts, canonical
  provider headers, saved Executor calldata and original scheduling/execution
  transaction observations.

The manifest contains nine-word output rows. Its finite reader bound is
`480 + 288 * tokenCount <= 64 * 8192`, allowing at most 1,818 outputs. These are
complete output **hashes**, not retained full JSON, HTML, image or token-data
bytes. Original renderer source facts and historical Core fields remain
hash-only. Per-chunk archival proof, historical roles, signatures, runtime
admission, execution and consensus remain separate evidence obligations.
The input manifest also retains scoped reference-render, render-critical
inventory and bundle-coverage commitments; this batch does not reconstruct
their complete native record and archival preimages.

Original direct Executor inputs use the same reconstruction rules as the
[governance transaction evidence](museum-governance-transaction-evidence.md).
Missing transaction results and unsupported wrappers remain explicitly partial;
RPC errors abort. Complete call and action-ID preimages do not establish
historical authorization. Acquisition item 3 remains partial.

Policy V2, VIEW and new factory profiles require distinct following consumer
batches. They must not be cast into these original scoped records. Those are
remaining full-v1 tasks, not exclusions from the intended complete system.

## Capture, replay and assembly

Use the isolated environment in the [Museum tooling guide](../tools/museum/README.md).
Print the current profile hashes before preparing an externally pinned anchor:

```bash
python -m tools.museum.public_scoped_finality_capture profiles
python -m tools.museum.acquisition_finality_v7 profiles
```

The closed source anchor contains the exact scope, target token, common source
block commitments, graph addresses/runtime pins and externally admitted source
revision. All state reads use the same EIP-1898 canonical block. A new RPC
profile composes the frozen read-only history transport with original
transaction lookup; it does not change the older transport profiles.

```bash
python -m tools.museum.public_scoped_finality_capture capture \
  --anchor scoped-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --rpc-env STREAM_READONLY_RPC \
  --disclosure public --output scoped-capture

python -m tools.museum.public_scoped_finality_capture replay \
  --anchor scoped-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --transcript scoped-transcript.json \
  --transcript-hash <hash> --provenance trusted_rpc \
  --disclosure public --output replayed-scoped-capture

python -m tools.museum.acquisition_finality_v7 assemble \
  --packet title-v5 --packet-hash <hash> \
  --finality scoped-capture --finality-hash <hash> \
  --disclosure public --output acquisition-v7

python -m tools.museum.acquisition_finality_v7 verify \
  acquisition-v7 --manifest-hash <hash>
```

Assembly starts with the unchanged full title V5 export. Its original manifest
is retained at `inputs/title-v5-manifest.json`; the entire scoped capture is
retained under `acquisition-scoped-finality/`. The new packet is
`finality/acquisition-packet-v7.json`. Only schema/version, the paired finality
and proof branches, and the finality citation change.

All twelve source captures must reconcile common identity/block commitments,
runtime observations, repeated RPC results, complete receipts and log query
unions. The original target-token mint must precede selection checkpoint
creation. Original input bytes survive unchanged. Exporting the validated
supplied packet is supported; requesting a complete source-covered packet
still refuses with the remaining evidence gaps.
