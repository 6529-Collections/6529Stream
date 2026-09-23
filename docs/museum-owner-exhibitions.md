# Owner-published exhibition records

`tools.museum.owner_exhibition_package` builds a usable offline exhibition
package from selected native `EXHIBITION` receipts and a separately verified
recorded Museum package at the same captured block. The result includes
validated Linked Art resources, exact owner statements, field coverage,
provenance and all inputs needed to rebuild it. The existing BagIt and
[repository exchange](museum-repository-exchange.md) commands can consume the
new package through their closed semantic verifier.

This closes the owner-source consumer path in `MUSEUM-32`, associated with
[CMC-EXHIBITION-LOAN](collection-metadata-contract.md#exhibition-and-loan-records-cmc-exhibition-loan)
and [MSM-RELATIONS](museum-semantic-mapping.md#8-relationships-evidence-and-authority-boundaries-msm-relations).
The [independent exhibition adapter](museum-recorded-exhibitions.md) remains a
separate source family. Original `STREAM_EXHIBITION_V1` definition bytes and the
original 29 genesis definitions are preserved.

## What the source checks

The additive `OwnerExhibitionSource` uses the existing native OwnerRecords wire
reader under the distinct `STREAM_MUSEUM_OWNER_EXHIBITION_SOURCE_V1` read
profile. It accepts only selected `EXHIBITION` receipts, with exact embedded
Keccak256 payloads, the unchanged exhibition schema and original JCS definition
commitments. Opaque, URI-only and other same-name schema versions are rejected.

The reader preserves the original direct or relayed receipt and signature
bundle, historical owner, recorded timestamp, record index and chain hash.
It checks the pinned host, Core, registry and chunk-store code and dependencies,
the selected receipt's index and immediate predecessor, and accepted relayed
nonce correspondence. Its authority is the historical owner receipt at the
caller-admitted RPC state; it does not substitute a current `ownerOf` result.
The transcript is replayable evidence, not an Ethereum consensus proof or an
independent authentication of the RPC provider.

Each payload must identify a token. At the same pinned block, the reader calls
`tokenCollectionIdentity(tokenId)` and checks `mappingExists`, nonzero collection
ID and serial, the exact receipt token ID and the payload's collection ID.
It retains the returned burn flag. A burned token's historical exhibition
record remains eligible; mapping existence is not a new mint-lifecycle claim.
Matching the native token subject alone would not establish collection
membership, because that subject hash does not include the collection ID.

Immediate predecessor payloads are also checked against the exact public
exhibition schema and token/collection identity before a successful snapshot
can be retained. A failed read may have received bytes in memory, but it cannot
produce a successful package containing an opaque predecessor. The export
retains only this selected source family and its necessary verification inputs.

The projection selects every captured exhibition record exactly once, with a
nonempty maximum of 64 records. This is selected historical evidence.
`fullLaneHistory` remains false; no omitted record, latest-owner selection or
complete token dossier is implied.

## Meaning of the emitted resources

| Original statement | Derived behavior |
| --- | --- |
| Completed exhibition with explicit required names | Reported exhibition `Activity`, institution `Group` and venue `Place` |
| Planned, cancelled or unknown status | Complete retained statement and explicit nonperformed disposition |
| Missing required names or unsupported consumed facts | Explicit diagnostic; no invented performed event |
| Explicit supported Gregorian UTC bounds | Indexed time bounds from those exact source fields |
| Other calendar, timezone, precision or source expressions | Original fields retained without inferred dates |
| Display parameters, catalogues, wall labels and Artist-intent reference | Exact references and values retained; no remote retrieval or compliance claim |

The token owner is the source author. A named institution remains that author's
institution claim; an address, DID, record reference or reused name does not
prove institutional identity or reviewer authority. The event is an attributed
report of occurrence, not independently established historical performance.
The package does not infer loan permission, physical custody, display rights,
title transfer or compliance with Artist intent.

Identical shared institution/venue declarations can share a resource while
retaining every contributing record's provenance. Conflicting declarations,
cross-kind identity reuse and collisions with the selected base package's
resource identities are rejected. No name-based identity merge is performed.
Every original selected payload value remains available with source pointers,
including values that the Linked Art projection cannot express.

## Build and verify

Use the [Museum Python environment](../tools/museum/README.md). Inputs are:

1. An already built public recorded Museum package and its external manifest
   hash. Its retained original source supplies the common chain, Core, block,
   state root, timestamp and environment. Shared runtime pins must agree, and
   identical RPC requests across all retained transcripts must have identical
   results; matching block labels cannot hide contradictory source evidence.
2. An owner input directory containing `anchor.json`, `transcript.json` and
   `deployment-evidence.json`, captured under the new owner-exhibition profile.
   The deployment evidence must match the anchor's original commitment.
3. A canonical owner-pin document with exactly `anchorHash`, `transcriptHash`
   and `sourceHash`. The last is the hash of the source reader's complete
   snapshot, including the same-block collection identity reads.
4. A canonical plan with exactly `version: "1"`, `sourceHash` and `records`,
   where `records` lists the selected original record hashes. Retain its
   independently supplied hash and the new projection profile hash.

The projection profile hash is
`0x341cb5203bdc9229918b7841d30fc57c835d288d809c38d643601cb7cdf9cbb6`.
The retained unchanged exhibition schema hash is
`0xef47f6195633773a1533e3bde6e1dfee86ca3d111256353fc40f23f75c4bf8c5`.
These are implementation commitments, not registration evidence.

The Python source API accepts a supplied transport, so capture and local replay
use the same reader. The package CLI itself uses only `ReplayTransport`; it
does not contact an RPC server or fetch a document. A caller must explicitly
classify all inputs as public. Restricted export fails before source files are
opened by the CLI.

```powershell
python -m tools.museum.owner_exhibition_package build <recorded-base> <plan.json> <owner-input-directory> <owner-pins.json> <new-package-directory> --source-manifest-hash <base-hash> --plan-hash <plan-hash> --profile-hash <owner-exhibition-profile-hash> --disclosure public
python -m tools.museum.owner_exhibition_package verify <package-directory> --manifest-hash <returned-package-hash>
python -m tools.museum.package_v2 verify <package-directory> --manifest-hash <returned-package-hash>
```

`build_owner_exhibition_package` and `verify_owner_exhibition_package` expose
the same flow to Python callers. Package verification reconstructs the
original recorded base, owner transcript, collection joins and all derived
resources. Rehashing a modified envelope cannot make altered semantic files
pass reconstruction.

## Hand off through BagIt and OCFL

The package preserves the original recorded package under `source/`, the exact
owner evidence under `owner-records/`, the pinned plan under `inputs/`, and the
unchanged exhibition schema plus additive profile under `definitions/`.
Derived resources and their evidence live under `exhibitions/`.

To include the package in a [standard BagIt bundle](museum-bagit-ocfl.md), retain
every package file, including its manifest, beneath one payload prefix such as
`semantic/`. Declare that prefix and its external manifest hash in the bag
descriptor's `semanticPackages` list. Use the descriptor's explicit bundle,
schema, citation, tool and record-head commitments; these remain separate
operator inputs and do not establish a complete object dossier by themselves.
The existing BagIt verifier dispatches this exact owner-exhibition mode and
replays it before a repository export or import succeeds.

```powershell
python -m tools.museum.bagit build <bag-description.json> <payload-directory> <new-bag-directory> --description-hash <description-hash>
python -m tools.museum.repository_exchange export <bag-directory> <new-object-directory> --bag-manifest-hash <bag-hash> --created <UTC-version-time> --message "Owner exhibition evidence"
python -m tools.museum.repository_exchange import <object-directory> <new-restored-bag> --inventory-hash <inventory-hash> --version v1 --bag-manifest-hash <bag-hash>
```

The restored bag retains the exact exhibition source and derivative bytes.
Storage recovery is separate from current authority, institutional ingest and
full Museum conformance.

## Validation scope

```powershell
python -m unittest tools.museum.test_owner_exhibitions tools.museum.test_owner_exhibition_package -v
```

Synthetic native-wire controls exercise direct, EIP-712 and ERC-1271 receipt
forms without claiming genuine publication. Package tests combine a retained
recorded base with explicitly synthetic owner evidence, exercise offline replay
and tampering, and carry the package through BagIt and an OCFL round trip.
Genuine current-graph owner exhibition capture, institutional identity and
practitioner acceptance remain separate evidence.
