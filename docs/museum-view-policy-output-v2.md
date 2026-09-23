# Adopted VIEW policy output evidence

The Museum consumer retains an original adopted VIEW V2 declaration, its Router
history, sealed membership, original entropy policies, complete output checkpoint
and covered output parts/index. It is a separate read-only capture with exact
offline replay. It does not create a finality receipt or replace the acquisition
packet's finality branch.

The source profile pins native revision
`e0b4d17bc548f778a379773234caee545658bcdc`. That revision explicitly rejects VIEW
in the scoped snapshot, reference and finality provider routes. Later VIEW
preservation producers require separate profiles with their own source pins;
their existence does not change this profile's interpretation.

## What the capture checks

- The selected checkpoint and verified manifest come from externally pinned
  record identifiers. The checkpoint identifies its original adoption. Later
  Router heads remain separate observations.
- Original V1 and V2 adoption records share one Router history and collection
  aggregate. Complete observed collection history, exact profile tags, record
  carriers, original source preimages and each scope's predecessor chain are
  retained. The selected checkpoint must use an original V2 adoption.
- The declaration's `viewId` and the sealed membership's `scopeId` remain
  distinct. The VIEW scope is `(4, collectionId, 0, scopeId)`. Every original
  member and immutable coordinator joins the original inventory and policy
  chain. A later token burn does not replace the original denominator.
- Checkpoint and manifest configurations include the exact linked-worker
  addresses and runtime hashes. The checkpoint joins the serving configuration
  and its renderer gas allowance. External runtime admission is required for a
  public RPC capture; self-consistent hashes do not authenticate deployment.
- Every output retains all 31 native words, including original lifecycle,
  current-live or retained-burned serving kind, complete entropy policy,
  JSON/HTML hashes and byte lengths. Terminal DISABLED/NOT_REQUIRED and finalized
  entropy remain distinct.
- The complete ordered row chain reconstructs the checkpoint root. Every
  covered part contains exactly 64 rows except the final remainder. Ordered
  descriptors reconstruct the complete index and original manifest record.
- Exact native definition bytes, original Store/carrier bytes, provider event
  history, successful receipts and block headers survive capture and replay.
- Publication events must occur in native dependency order, with consistent
  block and transaction coordinates. The selected adoption remains in force
  through manifest verification; an adoption recorded later is retained as a
  separate observation.

The output root is an ordered commitment to the complete checkpoint. It is not
the STATIC token-content Merkle root. Verification uses every row; the target
row export does not imply a standalone Merkle inclusion proof.

## Preservation and authority limits

Checkpoint rows retain output hashes and lengths. They do not store the full
rendered JSON, HTML, media or browser execution. Historical rendering functions
rerender against dependency state and cannot supply those original bytes after
drift. This capture does not call current rendering or admission functions to
replace historical evidence.

An original authority class, consent hash, archive receipt or runtime hash is a
retained commitment. Supplied consistency does not prove the original signature,
historical authority execution, current archive liveness, runtime provenance,
chain consensus or institutional acquisition acceptance. No complete acquisition
packet or native VIEW finality claim is made.

The native output format permits 16,384 rows, 256 parts and 524,288 bytes per
carrier. The consumer also enforces its existing 64 MiB transcript, 64 MiB
snapshot and 96 MiB package bounds. A format-valid large scope may exceed those
aggregate capture bounds. These limits do not establish native gas capacity or
whole-scope deployment acceptance.

## Commands

Use the isolated environment in the [Museum tooling guide](../tools/museum/README.md).
Inspect the profile hashes before preparing the external anchor:

```bash
python -m tools.museum.public_view_policy_output_capture_v2 profiles
```

The closed anchor contains the common chain/block identity, target token, full
VIEW scope, checkpoint and manifest record identifiers, 28 graph roles and their
runtime pins, and the external runtime admission for the pinned source revision.
State reads use the same EIP-1898 canonical block.

```bash
python -m tools.museum.public_view_policy_output_capture_v2 capture \
  --anchor view-output-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --rpc-env STREAM_READONLY_RPC \
  --disclosure public --output view-output-capture

python -m tools.museum.public_view_policy_output_capture_v2 replay \
  --anchor view-output-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --transcript view-output-transcript.json \
  --transcript-hash <hash> --provenance trusted_rpc \
  --disclosure public --output replayed-view-output-capture

python -m tools.museum.public_view_policy_output_capture_v2 verify \
  view-output-capture --manifest-hash <hash>
```

The package retains its exact source anchor, transcript and snapshot. The derived
`view-output/evidence.json` and `view-output/target-row.json` are reconstructed
from those inputs during verification. Altering a derived file and recomputing
its manifest hashes does not make it a valid capture.
