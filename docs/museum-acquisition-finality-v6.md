# Original native finality and token proof

The Museum consumer can capture an original native collection finality receipt,
its typed input manifest, and the preserved token-content leaf manifest. It
exports these as a standalone native fragment and as paired branches in a new
V6 acquisition packet. The original title V5 package, all nineteen required
groups, and every earlier payload remain available with their original bytes.

This is prospective, unregistered consumer tooling. The synthetic tests do not
establish native execution, source authenticity, consensus, full acquisition
coverage, audit completion or deployment readiness.

## Supported evidence

The source profile is pinned to native source commit
`e031ce6f5f7a79f8c098d4ad0242ee02ce1b0116`. Its first supported profile is the
artist-bound collection scope with inline ONCHAIN content. V6 composition
requires an existing ONCHAIN, script-class title V5 packet at the same token,
collection and source block.

The capture checks:

- The original router/finality binding and the native dependency addresses and
  runtime commitments supplied in an externally pinned anchor.
- The stored eight-field collection receipt, all original components, exact
  staged ABI manifest bytes, and matching Schema Store bytes. Six native schema
  and canonicalization definitions remain exact RAW_BYTES documents.
- The manifest's original root-record commitment, the complete captured
  collection root lineage, and the corresponding native publication events.
- The completed inline checkpoint, every ordered leaf, verified leaf-manifest
  record, artifact chunks and original coverage-completion receipt.
- The stored Executor/proposer witness, original archive witness, scheduled
  calldata carrier and exact archived-finalizer bytes. Publication, scheduling
  and execution events must agree with the retained native fields.
- Original event chronology, timestamps, complete successful receipts and
  provider header mappings. All twelve captures are reconciled during assembly.

V6 also requires the target token's completed Core mint to precede checkpoint
creation, using the original transfer and checkpoint event coordinates.

The complete leaf bytes have length `320 + 192 * leafCount`. The 64-chunk bound
permits at most 2,729 leaves. Every leaf retains its token ID and original
metadata, image, animation, content and token-data hashes. The Merkle tree keeps
left/right order and promotes an odd node unchanged. Proof direction comes
from the leaf index and count. Burned tokens remain archival members.

## Original commitments and authority limits

The historical Core-facts field is explicitly
`{"status":"hash_only","hash":"…","preimage":null}`. Current Core facts
cannot supply that missing original preimage.

Root publisher class, grant revision and Artist consent are retained separately
from the Executor and proposer. The stored action's first target and selector
can describe another call in a batch. Scheduled calldata does not recover every
`GovernanceCall` target, value and transition commitment or the complete action
ID preimage. The fragment therefore keeps `completeAuthority`,
`batchCallMetadataVerified` and `executionTransactionInputCaptured` false.

The original coverage receipt and artifact bytes are retained. Per-chunk
archival coverage preimages, current archival availability, original rendered
bytes and historical role/consent execution are not reexecuted. A later source
profile may capture the original transaction input; the existing public RPC
profile remains unchanged.

Other finality scopes, STATIC, VIEW, chunked content and later policy versions
are unsupported. This first V6 composition also requires the original fragment
and existing packet to share Metadata, schema Store/Registry and Artist
Registry/artist ID. Different or recovered graph composition fails closed.
Original finality, signer, generation and binding commitments are preserved.

## Capture, replay and assemble

Use the isolated Python environment described in the
[Museum tooling guide](../tools/museum/README.md). The command below reports
the current exact source and capture profile hashes:

```bash
python -m tools.museum.public_finality_capture profiles
```

Public reads require an explicit anchor hash, source-profile hash and disclosure.
The endpoint comes from a process environment variable and is not retained:

```bash
python -m tools.museum.public_finality_capture capture \
  --anchor finality-anchor.json --anchor-hash <anchor-hash> \
  --source-profile-hash <source-profile-hash> --rpc-env STREAM_PUBLIC_RPC \
  --disclosure public --output finality-capture
```

The `replay` command accepts the same anchor pins plus `--transcript`,
`--transcript-hash` and explicit `--provenance`. Captures retain the complete
anchor, transcript and snapshot; verification reconstructs every output.
Synthetic captures must retain `synthetic_fixture` provenance.

```bash
python -m tools.museum.acquisition_finality_v6 assemble \
  --packet title-v5 --packet-hash <title-manifest-hash> \
  --finality finality-capture --finality-hash <capture-manifest-hash> \
  --disclosure public --output acquisition-v6
python -m tools.museum.acquisition_finality_v6 verify acquisition-v6 \
  --manifest-hash <v6-manifest-hash>
python -m tools.museum.acquisition_finality_v6 export-packet acquisition-v6 \
  --manifest-hash <v6-manifest-hash>
```

The active export is `finality/acquisition-packet-v6.json`. Its native `@fin`
citation names the original collection finality-record hash. The preceding
title packet remains at `title/acquisition-packet.json`, and its manifest is
retained at `inputs/title-v5-manifest.json`. The complete new capture lives
under `acquisition-finality/`.

Item 3 gains a checked native proof and remains partially source-covered.
`complete-packet` continues to refuse a claim of complete source coverage.
Earlier [title V5 qualifications](museum-acquisition-title-v5.md) also remain.

## Focused validation

```bash
python -m unittest tools.museum.test_native_finality_wire \
  tools.metadata.test_acquisition_native_finality_v1 \
  tools.museum.test_public_finality_capture \
  tools.museum.test_acquisition_finality_v6 \
  tools.metadata.test_acquisition_packet_v6 -v
python -m tools.metadata.acquisition_native_finality_v1 --check
python -m tools.metadata.acquisition_packet_v6 --check
```

These checks exercise supplied native commitments, synthetic capture mechanics,
offline replay and packet composition. Runtime, full CI and release validation
belong to the integrator's combined acceptance batch.
