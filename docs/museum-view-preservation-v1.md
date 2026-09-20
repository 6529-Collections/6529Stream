# Original VIEW preservation evidence

This separate Museum capture joins original VIEW preservation adoption,
producer admission, complete membership and entropy policies, checkpoint rows,
covered output parts, a root-free snapshot and the Router's typed CONTENT_ROOT.
It reconstructs the exact package offline from its original source transcript.

The native source pin is
`e8a569b36927ed7f711a14a30ce5b09690694dd0`. The
[original live VIEW output capture](museum-view-policy-output-v2.md) keeps its
earlier source pin and interpretation. Neither profile completes acquisition or
establishes full native finality.

## Original evidence and distinct roots

The preservation producer has its own configuration, linked worker and encoder,
and non-sanction attribution companion. Original tagged adoption history still
identifies the live renderer, immutable VIEW policy source set and full scope.
The separate Registry preservation record and read set retain the producer's
admission commitments. Original signatures, analysis execution and golden-vector
rendering are separate obligations.

Native definition files come from the pinned contracts and are checked against
the Schema Registry. The local adoption-evidence profile is packaged separately
as `definitions/adoption-evidence-profile.json`; it is not a native document.

The checkpoint exposes a current source getter but no immutable getter for its
original source preimage. This consumer obtains that preimage from the selected
snapshot's stored canonical payload. It then joins the full adoption record,
policy binding, preservation binding, admission and source-context hash to the
independent historical getters and original checkpoint configuration. A current
source or a newly rendered output cannot replace the stored source.

Each checkpoint row retains all 31 native words. Terminal DISABLED and
NOT_REQUIRED entropy remain distinct from finalized entropy. Permanent token
identity and collection serial join every row. Later burns remain separate from
outputs originally captured using the retained-burned serving path.

Two roots retain separate meanings:

| Commitment | Meaning |
| --- | --- |
| `outputRoot` | The complete ordered row chain and preservation checkpoint state. |
| `contentRoot` | Ordered Merkle leaves containing each full output, chain, Core, full scope and original adoption record under the preservation domains. |

Merkle pairs preserve left and right positions. An odd last node is promoted
unchanged. The target proof includes its exact leaf index and total leaf count;
it does not reuse the old STATIC leaf format.

Parts contain 64 complete rows except the final remainder. The thirteen-word
header carries both roots. Part bytes are `672 + 992 * rowCount`; index bytes
are `672 + 288 * partCount`. Every descriptor, original coverage record and
carrier joins the complete ordered index.

## Snapshot and Router publication

The root-free snapshot retains ten dependency address/runtime pairs, locked
Artist presentation, membership, full checkpoint source, complete manifest and
original policy roster. The consumer reconstructs its source hash, canonical
payload, record hash and history chain from the retained bytes. Writer grants
and a class-2 lock remain distinct commitments; no current grant is substituted
for the original publisher's recorded grant.

The Router root keeps the original scoped outer record and shared collection
aggregate. Its distinct 28-word preservation binding joins the original
snapshot, checkpoint, manifest, producer, renderer, attribution and definition
hashes. The separate CONTENT_ROOT consent hash is retained. Prior VIEW adoption
does not establish that content-publication authority.

Publication logs, successful receipts and source headers must agree. Original
adoption remains selected through each observed consuming snapshot or root
publication. The selected adoption precedes producer registration. Each root
references the snapshot that was current when that root was published. Broad
publication and lock logs must match the complete retained snapshot history.
Later heads are observations alongside the selected historical
records. Foreign non-VIEW entries in the shared root aggregate retain their
original outer commitments without being cast to this preservation profile.

## Limits

Output hashes and lengths do not recover the full original JSON, HTML, media or
browser behavior. Runtime provenance, signatures and historical authority,
archive liveness, chain consensus and institutional acquisition acceptance
remain separate. The selected provider, reference/inventory and complete
finality integration were unfinished at this native source pin. A supplied
root does not establish that those native paths are deployable or complete.

Format limits remain 16,384 rows, 256 parts and 524,288 bytes per carrier. The
snapshot's policy roster is bounded to 630 entries. Consumer transcript and
snapshot bounds are 64 MiB, and package bounds are 96 MiB. Other bounded history
limits include 64 saved snapshots and 16 MiB of combined original snapshot
payloads. These are not universal native gas or
whole-scope capture guarantees.

## Commands

Use the isolated environment in the [Museum tooling guide](../tools/museum/README.md).
Inspect the two consumer profile hashes before preparing an external anchor:

```bash
python -m tools.museum.public_view_preservation_capture_v1 profiles
```

The closed anchor pins the chain/block, target token, full VIEW scope, selected
checkpoint, manifest, snapshot and Router root identifiers, 31 graph roles and
runtime hashes, and external admission for the exact native source revision.
All state reads use the same EIP-1898 canonical block.

```bash
python -m tools.museum.public_view_preservation_capture_v1 capture \
  --anchor view-preservation-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --rpc-env STREAM_READONLY_RPC \
  --disclosure public --output view-preservation-capture

python -m tools.museum.public_view_preservation_capture_v1 replay \
  --anchor view-preservation-anchor.json --anchor-hash <hash> \
  --source-profile-hash <hash> --transcript view-preservation-transcript.json \
  --transcript-hash <hash> --provenance trusted_rpc \
  --disclosure public --output replayed-view-preservation-capture

python -m tools.museum.public_view_preservation_capture_v1 verify \
  view-preservation-capture --manifest-hash <hash>
```

Verification reconstructs every file, including
`view-preservation/evidence.json` and `view-preservation/target-proof.json`.
Changing derived bytes and recomputing the outer file hashes does not make a
valid capture.
