# Scoped factory policy V2 finality and acquisition V9

The Museum consumer preserves original TOKEN, RELEASE and SEASON policy V2
finality, including the factory-created publication graph, complete membership,
output rows, source policies and original preservation records. The V9 export
keeps the complete title V5 package and adds a separate scoped policy capture.
Earlier packet branches and definition bytes remain unchanged.

This is prospective, unregistered tooling. Supplied consistency and offline
replay do not establish historical authority, native execution, complete
preservation, acquisition acceptance or deployment readiness.

## Native source and interpretation

The source profile pins native commit
`e0b4d17bc548f778a379773234caee545658bcdc` and the original
`StreamScopedPolicyPublicationFactoryV2`. CurrentAuthority and Deferred factory
variants, COLLECTION policy V2 and VIEW require their own explicit profiles.
The original COLLECTION consumer remains pinned to `896899f7`; this profile
does not silently advance it.

The new fragment, `STREAM_ACQUISITION_SCOPED_POLICY_FINALITY_V2`, checks:

- The original scoped Registry receipt, ten component expectations and exact
  original scoped input manifest. The manifest domains and finalization
  endpoint remain unchanged; the content leaf and preservation codecs are V2.
- Three inherited provider configurations with their original role meanings,
  the separate COLLECTION output binding, factory binding and full constructor
  configuration hashes. The selected scoped configuration is reconstructed
  from the immutable factory recipe and its seven prepared children.
- The original factory's stored `graphForPlan` record and preparation events.
  Current graph eligibility does not replace saved history. Source-set,
  factory, dependency and child runtime pins remain distinct commitments.
  Incremental child preparation and monotonic publication gas-budget increases
  are supported; each child must exist before its use and the complete graph
  must precede root adoption.
- Complete observed scoped root history and the shared collection aggregate,
  with exact V1/V2 dispatch and adjacent V2 binding events. The selected root
  must be the last root for its scope before finality. Unsupported VIEW history
  is rejected rather than omitted from the aggregate.
- Original TOKEN membership or sealed RELEASE/SEASON membership, including
  native publication bytes and Metadata authorization receipts. A scoped
  membership does not contain a COLLECTION inventory prefix. Later burns are
  separate observations and do not rewrite the original denominator.
- Every selection and output row, canonical manifest bytes, target token's
  ordered Merkle proof and six STATIC component preimages from immutable source
  records. Odd tree nodes are promoted without sorting or duplication.
- Full policy snapshot and reference payloads, retained source-set policies,
  original samples and class-two locks. The scoped snapshot precedes root
  publication; the reference joins that original snapshot and root.
- Nineteen exact native definitions, original event chronology, successful
  receipts, provider headers, saved Executor calldata and original scheduling
  and execution transaction observations.

The output manifest bound is `576 + 640 * tokenCount <= 64 * 8192`, allowing
818 outputs. Unique STATIC source preimages have an aggregate 8 MiB bound.
These are consumer format limits, not native gas or release acceptance results.

DISABLED and NOT_REQUIRED readiness remain distinct from finalized entropy.
Terminal-admission hashes, Core facts and Metadata component facts retain
unresolved historical preimages. Reference samples do not reconstruct every
token's served JSON, images or browser execution. Current archive liveness,
runtime provenance, historical authorization, signatures and consensus remain
separate evidence obligations.

Original Executor inputs follow the
[transaction reconstruction rules](museum-governance-transaction-evidence.md).
Missing transactions and unsupported wrappers remain explicitly partial; RPC
errors abort. Acquisition item 3 and complete source coverage remain partial.

## Capture, replay and assembly

Use the isolated environment in the [Museum tooling guide](../tools/museum/README.md).
Inspect the current profile hashes before preparing an externally pinned anchor:

```bash
python -m tools.museum.public_scoped_policy_finality_capture_v2 profiles
python -m tools.museum.acquisition_scoped_policy_finality_v9 profiles
```

The closed anchor contains the exact scope, target collection/token, common
source block, 31 graph roles, runtime pins and external runtime admission for
the pinned native revision. State reads use one EIP-1898 canonical block.

```bash
python -m tools.museum.public_scoped_policy_finality_capture_v2 capture \
  --anchor scoped-policy-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --rpc-env STREAM_READONLY_RPC \
  --disclosure public --output scoped-policy-capture

python -m tools.museum.public_scoped_policy_finality_capture_v2 replay \
  --anchor scoped-policy-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --transcript scoped-policy-transcript.json \
  --transcript-hash <hash> --provenance trusted_rpc \
  --disclosure public --output replayed-scoped-policy-capture

python -m tools.museum.acquisition_scoped_policy_finality_v9 assemble \
  --packet title-v5 --packet-hash <hash> \
  --finality scoped-policy-capture --finality-hash <hash> \
  --disclosure public --output acquisition-v9

python -m tools.museum.acquisition_scoped_policy_finality_v9 verify \
  acquisition-v9 --manifest-hash <hash>
```

All twelve source captures reconcile common identity/block commitments,
runtime observations, repeated RPC outcomes, complete receipts and log query
unions. Original package bytes survive unchanged. `export-packet` returns
validated supplied packet bytes; `complete-packet` refuses while source
evidence remains incomplete.
