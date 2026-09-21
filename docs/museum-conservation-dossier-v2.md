# Conservation documentary evidence and semantic mappings

The V2 conservation dossier combines two concrete consumers of the unchanged
[original conservation dossier](museum-conservation-dossier-v1.md): documentary
byte/Archive correspondence and typed museum semantic mappings. Verification
replays the original conservation capture and reconstructs every derived file.

## Documentary reference accounting

The original source determines the complete reference inventory. It includes
intent and waiver statements, instruments, participant identity references,
transcripts, captures, and specification references from complete retained
format catalogs. Repeated values and array order remain separate occurrences.
A caller cannot shorten that inventory by supplying only convenient files.

Each occurrence keeps its exact original URI, HashRef, role and format/catalog
declaration. Supplied bytes must match the applicable original interpretation.
Original external receipt pairs and onchain chunk archives use their existing
Archive preimage checks. Changing outer hashes cannot repair a contradictory
payload, receipt, object, pair, runtime, source block or original record.

Missing materials and unsupported hash/canonicalization interpretations stay
visible. They prevent the `complete` command from succeeding. A structurally
valid declaration is not permission to reinterpret an opaque identifier as a
content digest. Declared format is not detected format; native retained Archive
correspondence is not proof of current network availability or actual delivery.

The byte verifier supports the following explicit interpretations with the
existing RAW or JCS canonicalization identifiers:

| HashRef algorithm | Interpretation checked |
| --- | --- |
| 1, 2 | Keccak-256 or SHA-256 of the supplied canonical bytes |
| 3 | BLAKE3, using the pinned `blake3==1.0.9` dependency |
| 4 | Canonical binary SHA2-256 multihash |
| 5 | CIDv1 with the raw codec and SHA2-256, in binary or canonical lowercase base32 form |
| 6 | Exact transaction identity from the original external Archive receipt/checkpoint |

Algorithm 6 is an identity join; it does not compute an Arweave transaction ID
from content bytes. Other opaque multihash/CID forms and unknown
canonicalizations remain unresolved. The BLAKE3 dependency uses the
[official Rust implementation's Python bindings](https://github.com/oconnor663/blake3-py).
These offchain interpretations do not expand the algorithms admitted by the
protocol Archive. Its original byte and receipt proofs are checked separately.

The consumer retains every original Artist and estate history and separately
recorded current-use eligibility. Archiving a historical statement does not make
it the currently selected statement or retroactive living-Artist intent.

## Typed museum output

The conservation-specific crosswalk uses the existing pinned Linked Art model
and real offline JSON-LD expansion. It refers directly to original record
selectors and field pointers. It does not manufacture semantic assertion
records or route retained sources through draft authoring.

Explicit documentary resources remain distinct. Supported linguistic content
and digital carriers use their corresponding model classes; source roles and
relationships without a faithful model property remain typed Stream sidecars.
Every original leaf and reference occurrence receives coverage and provenance.
The complete sidecars retain the original format declarations, dates, ordered
languages, participant roles, parent/interview links and selection histories.

An interview record's presence does not prove a performed interview. The mapper
does not create an Activity, Person, Group, consent, completed recording event,
or institutional identity from those declarations. The semantic resources
describe the source statements; the separate material ledger supplies received
byte and Archive correspondence evidence without replacing those statements.

## Package and verification

| Path | Content |
| --- | --- |
| `source/` | Entire unchanged V1 dossier, including its original source capture |
| `materials/input.json`, `materials/data/` | Exact material envelope and supplied bytes |
| `archive/` | Per-occurrence documentary correspondence and completeness report |
| `conservation-semantic/` | Typed resources, expanded JSON-LD, crosswalk, sidecars, field coverage and provenance |
| `dependencies/` | Retained offline model and vocabulary dependency closure |
| `source-locations.json` | Exact component input paths mapped into `source/`, with hashes |
| `report.json`, `manifest.json` | Combined result and complete deterministic file commitments |

Component dossier paths resolve using `source-locations.json`. Original
Reference URIs remain unchanged; the package does not pretend those URIs were
fetched. The verifier reads its retained model dependencies, replays the source,
reruns both consumers and compares every output byte. It never executes retained
code or opens the network.

Public disclosure is required before build/template input reads. Output must be
a new directory. Existing file, byte and manifest bounds apply to the whole
package; exceeding a bound fails rather than truncating the reference inventory.

## Commands

Use the isolated Python environment in the
[Museum tooling guide](../tools/museum/README.md).

```text
python -m tools.museum.conservation_dossier_v2 profiles
python -m tools.museum.conservation_dossier_v2 material-template DOSSIER MATERIALS --manifest-hash DOSSIER_HASH --disclosure public
python -m tools.museum.conservation_dossier_v2 build DOSSIER MATERIALS OUTPUT --manifest-hash DOSSIER_HASH --materials-hash MATERIALS_HASH --disclosure public
python -m tools.museum.conservation_dossier_v2 verify OUTPUT --manifest-hash OUTPUT_HASH
python -m tools.museum.conservation_dossier_v2 complete OUTPUT --manifest-hash OUTPUT_HASH
```

The template command creates `MATERIALS/input.json` with every source occurrence
and returns its hash. Place supplied files beneath `MATERIALS/data/` according
to the envelope. Compute the new
external envelope hash after adding actual evidence. A template with missing
materials is diagnostic input, never completion evidence.

Add `--require-complete` to `build` to refuse incomplete inputs before creating
the output directory. `verify` also supports an incomplete diagnostic package;
it checks that the reported gaps and every retained/derived file reconstruct
exactly. `complete` first verifies the whole package and then refuses any
unresolved documentary correspondence or semantic coverage.

## Completion scope

A successful completeness check applies to the records, catalogs and reference
occurrences in the original bound conservation source. It does not establish a
global historical host inventory, all token dossier families, a complete
canonical acquisition packet, source consensus, historical signature
revalidation, live archival availability or institutional acceptance. Synthetic
vectors remain synthetic; caller-admitted RPC evidence retains its source trust
boundary. Existing V1 profiles and packages keep their original meaning.
