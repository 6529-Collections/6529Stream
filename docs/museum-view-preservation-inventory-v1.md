# Retained full VIEW preservation inventory

This offline consumer follows native source
`fd861f3fd79dccc87646412603b6907d020c2917`. It checks a complete ordered
render-critical inventory and, when supplied, its original bundle coverage.
It has a separate consumer profile from the
[reference environment file inventory](museum-view-preservation-reference-v1.md).

## Complete source evidence

The input retains the exact scoped Context, Plan and Evidence, dependency
bindings, runtime bytes, recorded getter returns, complete segment events and
all original source preimages. The recorded calls include the native profile,
dependencies, complete source context, completed plan, every segment, full
definition check and two matching `requireCurrent(scope)` observations.
Calls are ordered records at one supplied block hash. Their RPC origin and
successful native execution are external trust inputs; the transcript cannot
authenticate itself.

The consumer reconstructs these stages in native order:

| Stage | Required occurrences |
| --- | --- |
| 0 | Original snapshot, root, adoption, policies, dependencies, every part and index |
| 1 | Original reference payload, environment, every package/OS declaration and capture |
| 2–6 | WORK, RIGHTS, intent or waiver, interview or waiver, original Artist root authorization |
| 7 | All 36 fixed registered definitions in native order |
| 8 | Adopted declaration, manifest, complete payload, script and media obligation |
| 9 | Selected renderer registration, read set, all targets, sources, encoder and five documents |
| 10 | Governed preservation registration, complete read set, workers, encoder and three documents |
| 11 | Every permanent member identity, token data, full output row, JSON, HTML and Coordinator runtime |

The earlier complete preservation and reference validators remain required.
Their member rows, output Merkle tree, part partition, complete index, original
snapshot and Router root are joined to the new Context. Every member then
supplies actual JSON, HTML and token-data bytes matching its saved output.
First/last reference samples do not replace this denominator. Burned identities
and terminal/finalized entropy retain their original policy interpretation.

Typed WORK, RIGHTS and conservation witnesses must serialize to the exact
original payload bytes. Inactive fields must remain empty, and the reference
walk retains all catalog entries, participants and captures in order. Catalog
bytes must match the global registered-document evidence. These pure byte
checks do not establish the truth of an artist, rights or format declaration.
The complete WORK selection hash is recomputed under its native chain, WORK
host, Core, Metadata, Schemas, Store, collection and subject domain. Its payload
and revision join the description evidence; its original receipt joins the
recorder, record index and chain, definitions and Artist publication identity.
Conservation language tags also pass the existing validator's pinned
2026-08-08 IANA registry checks. This consumer condition is stricter than the
native serializer's language-syntax check.

Segments preserve each occurrence, including repeated documents and runtimes.
The verifier checks stage cursors and witnesses, reverse item links, ordered
segment chains, full scoped plan/evidence preimages, event positions and
shared block/transaction coordinates. Environment package declarations still
do not establish ZIP membership or executable availability.

## Media and original coverage

The frozen native media profile supports an absent image or canonical lowercase
`ipfs://b` CIDv1 with raw codec and SHA-256. It retains the exact URI and its
digest separately. The URI does not supply file size or availability. HTTPS,
Arweave, DAG-PB, inline data, paths and query suffixes are unsupported; the
consumer does not infer a file digest from them.

Optional bundle evidence must cover every occurrence of the already validated
inventory. State-byte admissions retain payload, STOP-prefixed runtime and
metadata. External/onchain admissions retain their typed original objects,
complete chunks, signed-record preimages and checkpoint records. The verifier
recomputes original admission and bundle commitments. Applicability markers
retain their distinct native kinds.

Bundle `sourceBindings` retain ordered getter observations at the same anchor
and with the same provenance as the inventory. They bind each original archive
host and checkpoint verifier to its recorded dependency getter, including
repeated occurrences. The consumer checks concatenated onchain object bytes
against the whole content hash and preserves schema/canonicalization joins.
Original artifact coverage completion and archive envelope keys remain admitted
native commitments where their full plan or pointer preimages are unavailable.

Coverage trust is explicit: these are retained native admission observations.
The consumer does not verify historical signer authority, current receipt
pairs, a later refresh, external possession or archive consensus. Inventory
validation alone does not assert bundle coverage. Neither result establishes
browser execution, governance execution, full acquisition or finality.

## Commands and bounds

Use the isolated environment in the [Museum tooling guide](../tools/museum/README.md):

```bash
python -m tools.museum.view_preservation_inventory_v1 profiles
python -m tools.museum.view_preservation_inventory_v1 verify retained-inventory.json
```

The canonical JSON envelope contains `profileHash`, `context`, `graph`,
`inventory` and `bundle`. Use `bundle: null` to verify inventory alone. The
command always validates the inventory before checking any bundle. It never
accepts a caller-supplied validation report in place of source evidence.

Consumer bounds include 16,384 members, 32,768 segments, 131,072 inventory
occurrences, 1,024 items per segment, 64 rows per native/reference chunk,
524,288 bytes per carrier,
262,144 bytes per JSON/HTML output and 64 document chunks of at most 8,192
bytes. The inventory input is bounded to 192 MiB and the outer envelope to
256 MiB. Bundle admission evidence is bounded to 16,384 occurrences and
64 MiB of original byte preimages.
Source gas facts can reach 64 million; these are recorded read budgets, not
measured transaction capacity or a guarantee that the native producer fits.

The command performs no network, compiler or EVM work. Its tests use synthetic
retained evidence and must not be described as a positive native inventory,
current provider or Registry/finality integration demonstration.
