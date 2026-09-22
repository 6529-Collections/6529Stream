# Recorded exhibition location and TGN join

The [recorded exhibition geography consumer](../tools/museum/recorded_exhibition_geography_v1.py)
joins one original OwnerRecords EXHIBITION venue to a separately recorded,
reviewed Getty TGN alignment. It replays a complete canonical V3 dossier and
an Authority V2 package before using either source. This is a bounded
`recorded_exhibition_location_join`, not completion of MUSEUM-23 or a new
registered geography schema. The nineteen packet groups, forty-nine dossier
assessments and earlier profiles remain unchanged.

## The original owner commitment supplies the connection

An external binding chooses an exact owner occurrence and an exact original
Place declaration. That selection alone grants no authority. The original
owner-authored `venue.location.hash` must contain:

- algorithm `1` (Keccak-256);
- the digest of the **whole original declaration record payload**, not merely
  its selected entity or an exported representation;
- the canonicalization ID for `RFC8785_JCS`.

The original venue entity ID must also equal the selected Place declaration
ID. A matching label, IRI or URI by itself is insufficient. The location URI
remains opaque documentary text; the consumer does not fetch or interpret it.

The two sources must declare the same chain, Core and environment. The
declaration's original publication position must precede the owner statement.
Each source retains its own block, original receipts and source qualifications.
Comparing those positions does not independently prove a shared canonical
history, RPC origin or consensus.

This establishes `ownerReferencedDeclarationBytes`. It does **not** establish
`ownerApprovedTgnIdentity`: an account's later alignment and its authenticated
review belong to their own authority history. Self-review is not evidence of
an independent human reviewer.

## Binding and selection

The canonical JSON binding is externally pinned and has this closed field set:

| Field | Meaning |
| --- | --- |
| `version`, `profileHash` | Version `1` and this consumer's exact profile hash. |
| `ownerSourceProfileHash`, `ownerManifestHash` | Exact Source V2 interpretation and original V3 dossier. |
| `ownerOccurrenceId`, `ownerSelector` | Exact retained EXHIBITION occurrence and native owner selector. |
| `venuePointer`, `locationPointer` | Exactly `/venue` and `/venue/location`. |
| `authorityProfileHash`, `authorityManifestHash` | Exact Authority V2 profile and retained package. |
| `declarationSelector`, `declarationHash` | Exact recorded entity selector and hash of its canonical entity declaration. |
| `role` | Exactly `exhibition_location`. |
| `rationale` | A nonempty explanation, bounded to 2,048 UTF-8 bytes; it grants no authority. |

The selected original must have supported EXHIBITION semantics, and the
selected account entity must be a Place. Missing or mismatched binding evidence
rejects the join. Unsupported original owner records remain in the retained
complete dossier and inventory.

Only a resolved `GETTY_TGN` result with an eligible, unsuperseded
`equivalent_entity` assertion for that **exact declaration** emits Linked Art
`equivalent`. A later declaration continuation is retained but does not silently
replace the declaration the owner referenced. Weak matches, unreviewed,
disputed, superseded or competing identities retain their original sidecars,
selection diagnostics and snapshot evidence without becoming an identity edge.
The canonical TGN vocabulary IRI remains separate from its optional focus IRI.

## Graph and complete retained evidence

The bound venue produces a Place with its original owner label. Only completed
statements with explicit title, institution and venue names produce an Activity
with `took_place_at` and a named Group participant. Planned, cancelled and unknown
statements retain the Place and source evidence without a performed Activity.
Only supported original Gregorian UTC bounds become TimeSpan bounds.

The package retains:

- both complete original packages under `sources/owner/` and
  `sources/authority/`, including every competing assertion and original snapshot;
- the complete owner occurrence inventory, binding and exact selected original
  declaration payload, hash, selector and publication authority;
- the fixed owner definition plan and offline model dependency bytes;
- validated graph resources and expansions, source field coverage and graph
  provenance linking the owner statement, binding and authority evidence.

Verification rebuilds both source packages and every derived byte using the
retained definition plan and model closure. Changing derived graph or report
claims and rehashing their manifest is insufficient to pass replay.

The package proves no historical performance, institution identity, geographic
truth, publisher identity, custody, legal permission, current ownership,
institutional acceptance or production readiness. It adds no geometry,
sovereignty or other place-role inference. Public export requires an explicit
`public` disclosure decision before source reads.

## Commands and focused verification

```powershell
python -m tools.museum.recorded_exhibition_geography_v1 profiles
python -m tools.museum.recorded_exhibition_geography_v1 build owner-v3 authority-v2 binding.json export --owner-hash <v3-manifest-hash> --authority-hash <authority-manifest-hash> --binding-hash <binding-hash> --disclosure public
python -m tools.museum.recorded_exhibition_geography_v1 verify export --manifest-hash <package-hash>
python -m unittest tools.museum.test_recorded_exhibition_geography_v1 -v
```

Use a new output directory. The join inherits the package aggregate limits
(96 MiB and 8,192 files); the binding is bounded to 16 KiB. Fixtures construct
synthetic original ABI responses and exact transcript commitments offline.
They exercise real source/publication/registered-interpretation replay, without
claiming deployment, native execution, RPC truth or an actual Getty review.

See also the separate [draft geography projector](museum-geography.md),
[museum semantic specification](museum-semantic-mapping.md) and
[native owner-family interpretation](../tools/museum/CANONICAL-SEMANTIC-EXPORT-V2.md).
