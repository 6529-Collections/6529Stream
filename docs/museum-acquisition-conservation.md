# Native conservation in a partial acquisition assembly

`tools.museum.acquisition_conservation` composes three independently verified
capture packages: [tier/default](museum-conservation-tier-source.md),
[selected intent/interview](museum-conservation-source.md), and
[native sale-floor receipts](museum-conservation-floor-source.md).
It replays their original evidence offline, reconciles their shared observations,
and projects the supported fields into the additive V4 conservation shape.

**The result is a partial acquisition assembly.** Item 13 is representable under
the new schema but remains partial. Documentary truth, complete conservation
prerequisites and a complete 19-item packet are not established.

## What V4 adds

`STREAM_ACQUISITION_PACKET_V4` has numeric packet version `4`. Its conservation
field supports the new closed `kind: native_conservation`, string `version: "1"`
variant. The standalone definition is `STREAM_ACQUISITION_CONSERVATION_V4`.
Legacy conservation retains its existing meaning. V1–V3 schemas, validators,
authority profiles and the three original capture formats remain unchanged.

The native variant retains these separate facts:

| Field | Meaning |
| --- | --- |
| `sourceRefs` | Exact capture profile, source profile, manifest, anchor, transcript and snapshot hashes for each input. |
| `tier` | Durable declaration/default evidence, first completed mint and the prospective sale tier. |
| `scopes.collection` and `scopes.token` | Separate Artist and estate selection lanes, their current eligibility and scope lock. |
| `historicalFloor` | Original universal primary first-sale, semantic-release and settlement receipts, including their source-admission history. |

An absent lane means `absent_on_bound_selector`. It does not mean that no
conservation record exists elsewhere. The four lanes are not collapsed into one
preferred statement. Original Metadata receipt authority and Artist op24
authority remain distinct; the projection invents no generic tier record or
signer authority.

Current selection does not replace a saved floor fact. If a later waiver becomes
the current head, an earlier floor receipt can still commit to the original
selected intent. Documentary joins search the retained historical selection,
including its original identity and interview commitment.

Tier meaning is also temporal. An undeclared first sale can use the prospective
LITE rule before mint completion. A later valid FULL declaration before the first
completed mint changes the current declared tier; it does not rewrite that
earlier LITE receipt. Original block, transaction and log order remain available.

The supplied-data validator rejects conflicting publication coordinates and
Metadata record indices across the four selection lanes. In a full V4 packet,
native conservation records must also agree with the supplied Metadata lane
heads. The standalone fragment has no head input and does not establish that
additional join.

## What is joined, and what remains unresolved

`packet/documentary-joins.json` reports exact commitment matches separately from
the V4 representation. Where the supplied history permits it, the composer joins
the saved Artist intent or waiver to its original selection and registration
identity. The selected record kind must match the saved slot: an intent cannot
stand in for an intent waiver, or vice versa. It recomputes the original
present/waived interview evidence commitment
from the full selection and dependency tuple. A current head alone is not a
substitute for that historical preimage.

Missing original RIGHTS, personhood, preservation-master, archive or reference
evidence stays unresolved. A matching commitment does not prove documentary
truth, archive delivery or the execution of a payment. The synthetic paid test
fixture uses an explicitly admitted generic test provider; it is not evidence
that the held documentary-personhood path of the native provider has succeeded.

Only `universal_primary_v1` floor receipts are supported by this assembly
profile. An observed DIRECT receipt for the target collection on the bound floor
in any retained query or full receipt is rejected. A well-formed known receipt
for another collection remains retained without blocking this collection;
malformed known DIRECT events at the bound ledger fail closed. The frozen
universal-history filters do not
prove the absence of unobserved DIRECT receipts or cover all paid routes.
Unknown or mixed receipt families cannot be relabeled as supported evidence.
Candidate commitments remain commitments; unavailable candidate payload bytes
are not reconstructed.

The report keeps all 19 requirement IDs and names:

| Requirements | Assembly status |
| --- | --- |
| Items 2 and 19 | Derived within the admitted source profile from exact token identity and completed-mint evidence. |
| Item 13 | Partial, with a compatible V4 native conservation representation. |
| All other items | Unresolved. |

`canonicalPacketReady`, `completeCanonicalPacket`, `completeCmcPrerequisites`,
`personhoodProven`, `allPaidRoutesCovered` and `actualChainAcceptance` remain
false. `complete_packet` and the `complete-packet` command verify the supplied
assembly and then refuse export with the unresolved item list.

## Offline reconciliation and trust

Each input must have an external manifest hash and pass its original capture
verifier. All three must carry the same explicit provenance label. A
`trusted_rpc` label is externally admitted provenance, not a proof supplied by
the bytes themselves.

The reconciler requires identical chain, Core, collection, source block hash and
number, timestamp, state root, environment and deployment-evidence hash. It joins
the tier Core runtime commitment to the other captures' Core pins, and checks
overlapping dependency pins and exact repeated RPC outcomes, including sanitized
range/size limits.

Retained headers must agree by hash and height, timestamps cannot regress, and
adjacent touched headers must link. Complete successful receipts must agree with
their header transaction positions and global log coordinates. Each completed
log-query page must include every matching log from all retained receipts in
its range. Saturated responses require unique disclosed logs and their exact
completed split children in the same input. An overlapping filter from another
capture cannot repair an omitted child.

These are checks on retained observations. Provider log completeness and
canonical mappings remain trusted; no missing ancestry, receipt trie, consensus,
silently omitted transaction or source-provenance proof is inferred. Aggregate
byte, row, header, receipt, log, transaction and comparison bounds fail without
truncation. No network or reference fetch occurs during composition or replay.

## Retained package

| Path | Contents |
| --- | --- |
| `captures/tier/`, `captures/selection/`, `captures/floor/` | Every original input file, byte for byte, including each original manifest. |
| `definitions/assembly-profile.json` | The exact composition rules and profile pins. |
| `definitions/reconciliation-profile.json` | The bounded offline join rules. |
| `definitions/packet-schema.json`, `definitions/conservation-schema.json` | Exact V4 definitions. |
| `packet/assembly.json` | Source identity, projected fields, all 19 requirements and unresolved items. |
| `packet/conservation.json` | The compatible native conservation fragment. |
| `packet/documentary-joins.json` | Exact historical commitment joins and unresolved producer evidence. |
| `packet/source-reconciliation.json` | Shared-context commitments, union counts and qualified checks. |
| `packet/examination.md` | A readable partial-assembly report. |
| `manifest.json` | Closed inventory, input manifest pins, schema pins, claims and byte commitments. |

Verification replays the original captures and rebuilds every derivative.
Changing a native field, promoting a report claim or altering a definition and
recomputing the file hashes does not pass reconstruction.

## Commands

Read the current profile and V4 schema hashes:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_conservation profiles
```

Compose three existing public capture directories:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_conservation assemble `
  --tier tier-capture --tier-hash $tierManifestHash `
  --selection selection-capture --selection-hash $selectionManifestHash `
  --floor floor-capture --floor-hash $floorManifestHash `
  --packet-schema-hash $packetSchemaHash `
  --conservation-schema-hash $conservationSchemaHash `
  --disclosure public --output new-conservation-assembly

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_conservation verify `
  new-conservation-assembly --manifest-hash $assemblyManifestHash
```

Disclosure, schema pins and input-pin syntax are checked before reading input
directories. Assembly is published atomically to a new directory only after
replay and reconstruction pass. Existing destinations are refused; the input
capture directories are unchanged. Common package verification also recognizes
`acquisition_native_conservation_assembly`.

The Python API is `compose(tier_files, tier_hash, selection_files, selection_hash,
floor_files, floor_hash, *, disclosure, packet_schema_hash,
conservation_schema_hash)`, `verify(files, manifest_hash)`, and the deliberately
unavailable `complete_packet(files, manifest_hash)` export. The utility
`conservation_capture_join.reconcile` accepts only the exact tier/selection/floor
anchor and transcript byte pairs **after** the caller has independently verified
their capture packages.
