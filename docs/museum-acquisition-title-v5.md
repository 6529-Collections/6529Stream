# Native accession, title bindings and ownership in V5

`tools.museum.acquisition_title_v5` exports a new validated V5 packet whose
legal instrument, token transfer history and supported title bindings derive
from the existing public OwnerRecords and Core ownership readers. It accepts
an externally pinned [preservation V5 assembly](museum-historical-preservation-capture.md)
and an externally pinned [accession history](museum-acquisition-accession.md).
The producer audit uses source `6fb3291e0991f556ef642e206c7732d8882a336f`.
All frozen input profiles and the V5 schema retain their existing definitions.

## What the export derives

| V5 field | Native derivation |
| --- | --- |
| `legalInstrument` | The explicitly selected original ACCESSION, original instrument commitment, owner receipt and publication. |
| `ownershipProvenance.transfers` | Every captured Core transfer for the target token, in exact block, transaction and log order. |
| `ownershipProvenance.currentOwner` | Core identity and the last captured transfer agree, including the burn state. |
| `ownershipProvenance.titleBindings` | Supported original ACCESSION/DEACCESSION statements from the captured host whose declared transfer matches native history before publication; other-host supplied bindings are retained separately. |
| `recordChainHeads` | Count and final chain hash for each captured owner lane; unrelated supplied lanes retain their separate qualification. |

Every original native owner reference uses the existing
[`native_owner_receipt` authority](museum-acquisition-packet-v2.md). The original
13-field receipt, signature-byte commitments and publication remain bound to
the holder immediately before that publication. This owner-state transfer can
be different from the earlier transfer described by the title-binding payload.
No numeric authority class is assigned to an OwnerRecords publication.

The native source has no global canonical current-accession selector. The
accession input must name the original ACCESSION chosen for this acquisition.
A later accession, deaccession or ownership transfer does not replace that
selection or its original receipt owner. Other supported title statements can
appear in the derived history without becoming the selected legal instrument.

Unsupported historical schemas and unmatched title statements remain explicit
in the derivation report and retained accession history. They are not converted
to absence or a new interpretation. Original referenced instrument bytes remain
optional: when supplied, their original commitment is checked; unavailable
bytes are reported separately. No network retrieval occurs.

## Shared source evidence

The assembly replays both original packages and reconciles all eleven source
transcripts. Exact chain, Core, collection, token, block, time, environment and
deployment evidence must agree. The frozen owner anchor lacks a collection ID;
the join obtains it from the paired, replayed Core ownership identity. The
original anchor bytes remain unchanged.

Shared runtime pins, RPC outcomes, touched block headers, full successful
receipts and overlapping log queries must agree. A matching retained receipt
log cannot be omitted from a completed query response. This checks consistency
of the supplied provider observations. It does not establish receipt-trie
proofs, missing chain ancestry, provider completeness or chain consensus.

## Retention and coverage

The original preservation files retain their paths and bytes. Its root manifest
is retained at `inputs/preservation-v5-manifest.json`. The accession package is
retained in full under `acquisition-title/`, including its own manifest,
selection, source triplets, original records, payloads and signature bytes.

The new active packet is `title/acquisition-packet.json`. The original packet
remains at `packet/acquisition-packet.json`, and every earlier report continues
to describe those original bytes. `title/assembly.json` names both packet hashes
and their paths. `title/native-derivation.json` describes the new native fields
and remaining gaps. Verification reconstructs the complete output, so changing
the export and merely recomputing the outer manifest cannot authenticate a new
native field.

All nineteen field groups are validated under the unchanged V5 schema. Item 9
is derived within the admitted owner source profile. Items 5 and 10 remain
partial: other owner hosts and a complete protocol event archive are not
enumerated by these readers. The original `eventHistorySnapshot` reference
and any retained other-host title bindings remain supplied statements. The
remaining packet groups and their earlier source qualifications are retained.

An owner's publication proves the original recorded statement within the
admitted source profile. It does not prove legal title, institutional identity
or standing, the signer's institutional capacity, custody transfer or legal
validity of the instrument. Synthetic fixture replay proves consumer
consistency, not native EVM execution or actual-chain acceptance.

## Offline commands

```powershell
python -m tools.museum.acquisition_title_v5 profiles
python -m tools.museum.acquisition_title_v5 assemble --packet preservation-v5 --packet-hash <hash> --accession accession-history --accession-hash <hash> --disclosure public --output title-v5
python -m tools.museum.acquisition_title_v5 verify title-v5 --manifest-hash <hash>
python -m tools.museum.acquisition_title_v5 export-packet title-v5 --manifest-hash <hash>
```

The output directory must be new. `export-packet` returns the exact canonical
bytes of the derived packet, with no appended newline. This export has native
title fields and other supplied field groups; it is not source-complete.
`complete-packet` verifies the assembly and then refuses a source-complete claim,
listing the unresolved requirements. The common Museum package verifier also
dispatches this distinct assembly mode.
