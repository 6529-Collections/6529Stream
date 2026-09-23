# Retained VIEW evidence archival packages

This package embeds a complete [VIEW preservation inventory](museum-view-preservation-inventory-v1.md)
and every member's JSON, HTML, token data and original output-return bytes.
Verification reruns the complete inventory consumer and reconstructs the whole
package. Recomputing transport checksums cannot hide altered source evidence,
missing member files or a changed verification report.

The package addresses the retained VIEW source family in MUSEUM-25 and
MUSEUM-35. Its new BagIt profile is prospective and unregistered. It does not
claim full `OBJECT_DOSSIER_V1`, `STATE_EXPORT`, institutional ingest, archive
publication or finality conformance.

## Inputs and contents

Supply the canonical complete inventory envelope, an independently expected
SHA-256 of those exact bytes, explicit `public` disclosure and a bagging date.
The SHA-256 argument is 64 lowercase hex digits without `0x`. The original
consumer remains pinned to native `fd861f3fd79dccc87646412603b6907d020c2917` and
its existing profile. The packet includes all original source evidence required
by that consumer; optional original bundle coverage may remain explicitly null.

No source-export loader, RPC, browser or native compiler is needed. This path
accepts the full packet directly. The separate
[ceremony-export adapter](museum-view-preservation-export-v1.md) checks a local
export against such a packet when that transport is available.

| Payload | Preserved meaning |
| --- | --- |
| `inventory/input.json` | The entire original envelope, unchanged |
| `inventory/verification.json` | The recomputed complete inventory and optional bundle report |
| `interpretation/inventory-consumer-profile.json` | The exact consumer interpretation profile |
| `interpretation/package-manifest-schema.json` | The prospective package manifest schema |
| `evidence/manifest.json` | Source scope, provenance, pins, exact member-file inventory and limits |
| `members/member-N.*` | Four exact files per original member, with a 20-digit zero-padded index |
| `tool/*.txt`, `tool/source-index.json` | Inert packaging-source text, normalized to UTF-8/LF and indexed |

The unchanged envelope retains registered-document bytes, original records,
runtime bytes, ordered observations and events. Extracted member files are
additional exact byte copies. Original inventory ordering, duplicate
occurrences and retained burned identities remain intact.

Every payload is embedded. Existing BagIt SHA-256 and Keccak manifests, tag
fixity and portable path rules apply. There are no network fetch instructions.
The tool text is an inert provenance aid; it is never executed from a package
and is not a complete Python/runtime dependency archive. Offline verification
uses the installed, pinned museum tooling and its dependencies.

## Scope and version identity

A stable package identity includes the original chain, Core, collection and
VIEW scope ID. The BagIt external identifier also includes the retained block
hash. It is a VIEW-scope identifier, not a token citation or a claim that VIEW
ID and scope ID are interchangeable.

OCFL 1.1 versions retain the same scope identity. A successor bag must name the
preceding bag's exact manifest hash. Creating the successor object also requires
the previous OCFL inventory hash and a strictly later explicit version time.
No current timestamp, random identifier or implicit overwrite is introduced.

Verification checks transport and replays the semantic contents of **every**
retained OCFL version. A valid current head cannot conceal an invalid older
packet. Version lineage proves package succession, not blockchain continuity,
current authority or chronology of the underlying artistic events.

## Provenance and limits

The source packet retains `synthetic_fixture` or `externally_admitted_rpc`
exactly. Packaging does not authenticate that provenance. Its checks prove
correspondence to the supplied expected bytes; authenticity of the external
pins is a caller responsibility.

The underlying inventory and bundle limitations remain visible in the report.
Absent original bundle evidence stays absent. Local byte availability does not
establish historical governance execution, current archive authority,
institutional acceptance, browser execution or finality.

This archival transport inherits limits of 8,192 files, 96 MiB aggregate bytes
and 2 MiB per manifest. Its capacity is narrower than the native inventory's
maximum member count. Oversized selections fail as a whole; members are never
sampled or dropped to fit. OCFL also retains its existing 64-version limit and
aggregate bounds.

## Commands

Use the [museum Python environment](../tools/museum/README.md).

```text
python -m tools.museum.view_preservation_package_v1 profiles
python -m tools.museum.view_preservation_package_v1 build INVENTORY_JSON NEW_BAG --inventory-sha256 SHA256 --disclosure public --bagging-date 2026-09-21
python -m tools.museum.view_preservation_package_v1 verify BAG --manifest-hash 0xHASH
python -m tools.museum.view_preservation_package_v1 ocfl BAG NEW_OBJECT --manifest-hash 0xHASH --created 2026-09-21T12:00:00Z --message "Retained VIEW evidence"
python -m tools.museum.view_preservation_package_v1 verify-ocfl OBJECT --inventory-hash 0xHASH
```

For a successor, build its bag with `--predecessor PREVIOUS_BAG_HASH`, then use
`ocfl` with `--previous PREVIOUS_OBJECT --previous-inventory-hash PREVIOUS_HASH`.
Output directories must be new. The tools preserve existing bags, objects and
input packets without overwriting them.

```text
python -m unittest tools.museum.test_view_preservation_package_v1 -v
```
