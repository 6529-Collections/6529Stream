# Native acquisition and object dossier composition

The V10 acquisition consumer combines exact V5–V9 packets with current native
preservation, WORK/C2PA/condition, recovery and state-export evidence. Object
dossier V3 accepts that native packet and an optional conservation V2 family.
Both reconstruct every output from the retained inputs without network access.
These prospective profiles retain all 19 packet groups and all 49 adopted
dossier requirements. They do not establish complete canonical acceptance.

## Source inputs

The prior packet must have an independently pinned original manifest. The exact
consumer for its version replays it first; native finality and authority branches
are never converted to earlier formats. Every original path and byte survives
beneath `prior/` in the V10 package.

`canonical_native_inputs_v1.create` builds a transport manifest from:

- `preservation/input.json`: a canonical `{context, graph, evidence}` envelope
  for `acquisition_preservation_current_v1.consume`;
- `work/evidence.json` and the five original Metadata capture files:
  `anchor.json`, `transcript.json`, `snapshot.json`, `pins.json`, `profile.json`;
- an optional complete original condition-capture package;
- `recovery/evidence.json`, replayed by
  `acquisition_recovery_sustainability_v1.validate`.

The input manifest commits every supplied file and must be pinned externally.
Creating that manifest does not verify a source. Composition runs all three
concrete consumers and checks shared source identity, runtime bytes, getters,
headers, event coordinates, receipt contents and overlapping log queries.
Synthetic evidence cannot be mixed with observed-source labels. An undeclared
anchor field remains undeclared; the join does not manufacture provenance.

The common context contains chain, Core, collection, token, block hash/number,
block timestamp, state root, environment and deployment-evidence commitment.
Capture all source families at the same final block. Rebuilding or changing a
fixture's source state requires rebuilding its original commitments and events;
editing an anchor label after capture is not a valid join.

## Native field interpretation

| Packet groups | Concrete interpretation and limits |
| --- | --- |
| 8, 11 | Exact supplied preservation-host event history and native records; optional full VIEW retrieval replay. A fixity or reference render does not become a typed completed cycle or drill. Empty supplied-host history does not enumerate all hosts. |
| 12 | Original collection and token WORK selections, revisions, payload/catalogue fields and tombstones. Raw selected heads do not prove current eligibility or historical Artist authorization. |
| 14 | Complete bound Metadata catalogue and C2PA reconciliation/credential occurrences, including unselected records. Selected absence is not global absence or cryptographic credential validation. |
| 15 | Original owner and independent condition records and interpretations. Recorded examinations remain distinct from actual examination/render execution. |
| 17 | Complete listed Executor schedule nonce ranges, original calldata, status, recovery scope and executed lineage. Unsupported wrappers and unknown historical host inventories remain explicit. |
| 18 | Complete listed state-export histories, challenge/supersession and export age from the exported block. Funding/drill artifacts are a separate qualified release input; no financial commitment or genuine drill is invented. |

Each changed V10 group has `priorEvidence` and `current` branches. All other
groups retain their exact previous values. The new native projection does not
silently authenticate the earlier supplied statement. Verification rebuilds
the entire package, so rehashing a changed report or derived packet is refused.

## Commands

```powershell
python -m tools.museum.acquisition_canonical_v10 profiles
python -m tools.museum.acquisition_canonical_v10 assemble --packet PRIOR --packet-hash PRIOR_HASH --sources INPUTS --sources-hash INPUT_HASH --disclosure public --output PACKET
python -m tools.museum.acquisition_canonical_v10 verify PACKET --manifest-hash PACKET_HASH
python -m tools.museum.acquisition_canonical_v10 export-packet PACKET --manifest-hash PACKET_HASH

python -m tools.museum.canonical_object_dossier_v3 assemble --packet PACKET --packet-hash PACKET_HASH --disclosure public --output DOSSIER
python -m tools.museum.canonical_object_dossier_v3 verify DOSSIER --manifest-hash DOSSIER_HASH
```

To include the documentary/semantic conservation family, add `--conservation`
and `--conservation-hash` to the dossier assembly command. It must replay as an
exact conservation V2 package and agree with the packet's state and observations.
Its original model dependency closure, Archive correspondence, reference
occurrences and qualifications remain intact.

The `complete-packet` and dossier `complete` commands deliberately refuse while
the adopted requirements remain unresolved. Global host and lane inventories,
covering protocol history, remaining finality preimages, preserved release tool
archives, zero-operator regeneration and named institutional evidence require
their own sources. Source-local passes do not remove those requirements.

## Validation boundaries

Focused tests use deterministic synthetic source responses and original byte
replay. They do not execute Solidity, contact RPC providers, run a renderer,
authenticate historical signatures or perform institutional ingestion. Testing
and capture tasks own genuine current RPC evidence. The optional conservation
family verifies its own typed mapping and materials, not the complete dossier's
render inventory or packaging obligations. Package inputs and the reconstruction
must fit the existing 96 MiB / 8,192-file museum transport bounds.
