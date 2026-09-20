# COLLECTION policy V2 finality and acquisition V8

The Museum consumer retains original COLLECTION policy V2 finality with its
complete inventory prefix, policy/readiness rows, output manifest and original
snapshot/reference records. A new V8 acquisition export preserves all nineteen
field groups, the complete title V5 package and a separate policy V2 capture.
Earlier packet branches and definition bytes remain unchanged.

This is prospective, unregistered tooling. Supplied consistency and exact
offline replay do not establish historical authority, native execution,
complete preservation, acquisition acceptance or deployment readiness.

## Supported native evidence

The source profile pins native commit
`896899f7ca4130f86e066587f780a3b1f755a25d`. It supports the original COLLECTION
policy V2 profile with STATIC rendering and ONCHAIN metadata. Scoped policy V2,
factory extensions and VIEW require separate consumer profiles; their codecs
must not be cast into this fragment.

The new fragment, `STREAM_ACQUISITION_POLICY_COLLECTION_FINALITY_V2`, checks:

- The original Registry receipt, ten component expectations, exact policy V2
  input manifest, identical Store bytes and original finalization endpoint.
- The fixed provider configuration and three profile entries. Original V1
  leaf/checkpoint roles remain separate from the V2 output bindings.
- Full observed COLLECTION root lineage, including V1 and V2 bindings. The
  selected V2 root must be the latest before finalization. The finalized route
  cannot publish another root afterward. Later heads from other opaque routes
  remain observations without inheriting the original route's authority.
- Complete original token inventory membership in token and actual serial
  order. Serial gaps are allowed. Later burns and inventory extensions remain
  separate current observations and do not rewrite the original prefix.
- Every selection/output row, exact manifest bytes and target token's ordered
  Merkle proof. Odd tree nodes are promoted without sorting or duplication.
- Original source-set policy rows, deployment dependencies, snapshot/reference
  payloads, revisions and locks. Saved heads are observed without requiring
  current eligibility or substituting current factory selections.
- Six STATIC component preimages from immutable metadata configuration and
  source records: Router, Renderer, RenderContext, Media, Script and Dependency.
  The serving adapters and their pinned identities remain explicit.
- Seventeen exact native definition documents, original event payloads and
  chronology, successful receipts, provider headers, saved Executor calldata
  and scheduling/execution transaction observations.

An output row is 640 bytes, including readiness and terminal-admission fields.
The complete manifest bound is `576 + 640 * tokenCount <= 64 * 8192`, allowing
818 outputs. The snapshot profile also bounds distinct original policy rows at
630. These are consumer format bounds, not evidence that a native large-scale
deployment meets gas, code-size or release acceptance criteria. Unique STATIC
source preimages have an aggregate 8 MiB reader bound; the complete V8 packet
retains the existing packet byte limit and rejects oversized inputs.

DISABLED and NOT_REQUIRED terminal readiness remain distinct from finalized
entropy. A terminal-admission hash is retained as a commitment; the consumer
does not invent its missing historical preimage or a finalized seed. Packet
entropy fields join the original target coordinator, status and seed where
the packet represents those fields.

First/last reference samples retain original HTML bytes and their native
commitments. Image/ZIP identities and coverage commitments are retained, but
the consumer does not fetch those external objects or reconstruct every token's
served JSON, image or browser execution. Core facts, the Metadata component and
terminal admission still have unresolved historical preimages. Current archive
liveness, historical roles, transaction signatures, runtime provenance,
execution and consensus remain separate evidence obligations.

Original direct Executor inputs use the
[governance transaction reconstruction rules](museum-governance-transaction-evidence.md).
Missing transaction results or unsupported wrappers remain explicitly partial;
RPC errors abort. Acquisition item 3 and complete source coverage remain partial.

## Capture, replay and assembly

Use the isolated environment in the [Museum tooling guide](../tools/museum/README.md).
Print the current hashes before preparing an externally pinned source anchor:

```bash
python -m tools.museum.public_policy_finality_capture_v2 profiles
python -m tools.museum.acquisition_policy_finality_v8 profiles
```

The closed anchor contains the target collection/token, common source block,
32 graph roles, runtime pins and external runtime admission for the pinned
revision. All state reads use one EIP-1898 canonical block. The existing
read-only history/transaction transport is reused without changing its profile.

```bash
python -m tools.museum.public_policy_finality_capture_v2 capture \
  --anchor policy-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --rpc-env STREAM_READONLY_RPC \
  --disclosure public --output policy-capture

python -m tools.museum.public_policy_finality_capture_v2 replay \
  --anchor policy-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --transcript policy-transcript.json \
  --transcript-hash <hash> --provenance trusted_rpc \
  --disclosure public --output replayed-policy-capture

python -m tools.museum.acquisition_policy_finality_v8 assemble \
  --packet title-v5 --packet-hash <hash> \
  --finality policy-capture --finality-hash <hash> \
  --disclosure public --output acquisition-v8

python -m tools.museum.acquisition_policy_finality_v8 verify \
  acquisition-v8 --manifest-hash <hash>
```

Assembly retains the original title manifest at `inputs/title-v5-manifest.json`
and the full policy capture under `acquisition-policy-finality/`. The new packet
is `finality/acquisition-packet-v8.json`. Only schema/version, the paired native
finality/proof branches and the finality citation change.

All twelve source captures must reconcile identity/block commitments, runtime
observations, repeated RPC outcomes, complete receipts and log query unions.
The target mint must precede original selection. Original package bytes survive
unchanged. `export-packet` returns validated supplied packet bytes;
`complete-packet` refuses while source evidence remains incomplete.
