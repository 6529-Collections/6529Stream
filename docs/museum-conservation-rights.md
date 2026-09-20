# Original conservation RIGHTS correspondence

This offline tool compares the RIGHTS record saved in a first-sale conservation
receipt with an independently captured original Metadata record and selection
history. It accepts either the
[universal floor capture](museum-conservation-floor-source.md) or the
[typed DIRECT capture](museum-direct-conservation-source.md), together with one
[public RIGHTS capture](museum-public-history-capture.md).

Every input is verified under its original profile and preserved byte for byte.
The result is a partial documentary assembly. It does not complete the
acquisition packet, prove legal rights or reexecute historical contracts.

## Historical meaning

The join checks the original floor source's Metadata address and runtime hash,
the collection subject, saved RIGHTS record hash, original record and receipt,
payload bytes and publication event. Publication and selection must precede the
first-sale event using block, transaction and log positions. The latest
collection selection before that event must match for `original_record_joined`.
An older matching record is retained with `original_record_joined_but_superseded`.

The current collection and token selections are retained separately. Token
RIGHTS precedence controls the current token notice; it does not replace the
collection RIGHTS input saved by the conservation floor. A later reselection
cannot rewrite the first-sale receipt. Original recorder authority classes 7/8,
selector authority, grants, dates, instruments and Artist registration
commitments remain recorded evidence.

| Historical status | Meaning |
| --- | --- |
| `original_record_joined` | Original collection record and latest observed pre-sale selection match the saved hash. |
| `original_record_joined_but_superseded` | Original record matches, but another selection was latest before the sale in the captured selector. |
| `original_metadata_differs` | Supplied RIGHTS Metadata address or runtime differs from the saved floor source. |
| `saved_record_not_in_collection_history` | Saved hash has no matching captured original collection record. |
| `original_publication_not_before_first_sale` | Captured matching original was published after the first-sale boundary. |
| `selection_not_before_first_sale` | Matching original has no captured selection before that boundary. |
| `not_required_by_native_waived_floor` | The native waived first-sale receipt requires no RIGHTS fact; this says nothing about RIGHTS absence. |
| `no_native_receipt` | No first-sale receipt exists within the verified floor capture. |

Platform works still require the original collection RIGHTS fact. Only the
native waived tier bypasses it.

## What remains unresolved

The RIGHTS capture binds its selector through an original-finality provider's
configuration. The historical conservation provider has a separate private
constructor configuration. Its source admission stores the configuration hash,
but does not expose the ten-target preimage. FirstSale stores a RIGHTS record
hash without the selection revision or selection hash.

Consequently, matching original records and the selected head in the supplied
RIGHTS selector does **not** establish that this selector was target 4 of the
historical conservation provider. That binding, historical `requireCurrent`
execution, personhood and other documentary prerequisites remain unresolved.
A superseded match must not be accepted as proof of native provider input.

The frozen public RIGHTS source also requires current active Core pointers,
definitions and `requireCurrent` eligibility. It cannot capture every historical
selection after retirement or dependency replacement. Missing evidence stays
unresolved; this assembly never bypasses those original capture checks.

RPC log completeness and canonical block mappings remain provider trust.
Replay and locally recomputed hashes do not authenticate provenance, consensus,
legal enforceability, date applicability, archive delivery or all paid routes.
Synthetic fixtures remain synthetic.

## Commands

Use the isolated Python environment from the [Museum guide](../tools/museum/README.md).
Both input directories must already contain their original complete captures.
`--disclosure public` is required before input reads. Manifest hashes are
external input pins.

```bash
python -m tools.museum.conservation_rights profiles
python -m tools.museum.conservation_rights assemble \
  --floor out/floor-capture --floor-hash "$FLOOR_MANIFEST_HASH" \
  --rights out/rights-capture --rights-hash "$RIGHTS_MANIFEST_HASH" \
  --disclosure public --output out/conservation-rights
python -m tools.museum.conservation_rights verify \
  out/conservation-rights --manifest-hash "$ASSEMBLY_MANIFEST_HASH"
```

The command publishes atomically to a new directory after offline replay.
The common package verifier also recognizes this distinct assembly mode.
`complete-packet` verifies the package and then refuses export while the
remaining requirements are unresolved.

## Output and verification

`captures/floor/` and `captures/rights/` preserve all original input files,
including their manifests and source triplets. `documentary/` contains the
historical correspondence, observation reconciliation, report and readable
examination. `definitions/` contains the additive assembly and reconciliation
profiles. The closed top-level manifest commits to every file.

Both captures must share chain, Core, collection, block, timestamp, state root,
environment, deployment-evidence commitment and provenance. Reconciliation
checks runtime pins, repeated RPC outcomes, reciprocal header mappings, complete
returned receipts and matching query logs. A log omitted from one capture's
completed query cannot be rescued by its presence in the other capture.

All 19 acquisition requirements remain visible: current RIGHTS item 7 is
derived within its original source profile and conservation item 13 remains
partial. This assembly does not add a DIRECT variant to the frozen
[V4 native conservation packet](museum-acquisition-conservation.md).

```bash
python -m unittest tools.museum.test_conservation_rights \
  tools.museum.test_conservation_rights_join \
  tools.museum.test_conservation_capture_join
```
