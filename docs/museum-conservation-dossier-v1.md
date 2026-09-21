# Retained conservation and interview dossier

This offline supplement projects the exact original intent, intent-waiver and
interview records retained by the
[public conservation capture](museum-conservation-source.md). Every
build and verification replays that complete capture before deriving the
supplement. Existing capture profiles and bytes remain unchanged.

The source reader is pinned to native review source
`dffb8daa315114a7b26b4cff67df5747834f7ff9`. Its original op24 publication,
payload, catalog, receipt, signature-byte and selection checks retain their
existing trust boundaries. This supplement adds no new chain authority.

## What the supplement preserves

- All original intent display references, variability tolerances, dependency
  aging and significant-property references.
- Explicit intent waivers and interview waivers as distinct declarations.
- VMQ or named-derivative instruments, every participant role and identity
  reference, the original interview date and every language entry.
- Required transcript content and format, ordered audio/video captures and
  complete original format-catalog witnesses.
- Exact parent-to-interview record links, Artist and estate selection histories,
  original locks, and separately recorded current-use eligibility.
- Every payload leaf, including null and empty containers, with its original
  record selector and JSON Pointer. Repeated values and array order survive.

Participant identity references describe documents or other cited resources;
they do not establish named people, interview performance or consent. The
projection retains typed declarations and relationships in JSON. It does not
emit a Linked Art Person, performed interview event, ownership or rights grant.

## Package contents

| Path | Meaning |
| --- | --- |
| `input/` | Entire original capture, including its manifest, source snapshot and RPC transcript |
| `conservation/dossier.json` | Record and selection projection with original authority qualifications |
| `conservation/reference-occurrences.json` | Every exact reference occurrence with its source record and field location |
| `conservation/semantic-leaves.json` | Complete original payload field accounting |
| `conservation/projection-profile.json` | Exact projection interpretation |
| `definitions/` | Exact dossier and projection profiles |
| `report.json` | Counts, source identity, provenance and limits |
| `manifest.json` | Complete deterministic file commitments and input hash |

The verifier requires an independently supplied package manifest hash, checks
the entire file set, replays the embedded capture and rebuilds every derived
byte. Updating outer hashes cannot make a changed projection pass. No database,
node, URL fetch or execution of retained code is needed.

All files share the existing package byte, file-count and manifest bounds,
shown by `profiles`. Oversized packages fail as a whole. CLI input and output
use the existing link-refusing package filesystem helpers; output must be a
new directory.

## Commands

Use the isolated Python environment in the
[Museum tooling guide](../tools/museum/README.md).

```text
python -m tools.museum.conservation_dossier_v1 profiles
python -m tools.museum.conservation_dossier_v1 build CAPTURE OUTPUT --manifest-hash CAPTURE_HASH --disclosure public
python -m tools.museum.conservation_dossier_v1 verify OUTPUT --manifest-hash DOSSIER_HASH
python -m unittest tools.museum.test_conservation_dossier_v1 -v
```

Explicit public disclosure is required before build input reads. That is the
caller’s classification, not proof of permission to publish participant or
interview materials. Restricted inputs are refused by this profile.

## Acceptance limits

The report remains a supplementary partial dossier. Original source provenance
is either `synthetic_fixture` or externally admitted `trusted_rpc`; offline
replay does not authenticate it. Historical signatures, named participant
identity, consent, actual interview performance, referenced media delivery,
current archival availability and legal truth remain unverified.

An empty selected lane is only absence on that bound selector. It cannot
become an interview waiver, default tier or assertion that no record exists
elsewhere. Historical statements remain present when current-use eligibility
fails. Estate statements do not replace living-Artist intent retroactively.

This bounded projection advances MUSEUM-10 source interpretation. Complete
canonical dossier/packet composition, all admissible source and archival
variants, Linked Art mappings and institutional conformance remain separate.
