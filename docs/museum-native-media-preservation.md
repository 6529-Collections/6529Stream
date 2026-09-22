# Native media and preservation exports

The additive native multiformat package V2 extends the
[four-format export](museum-native-multiformat.md) with retained VIEW media,
native record-publication events and documentary rights notices. It replays one
canonical V4 source and preserves the previous profiles and original fields.

## What the original source establishes

| Source | Supported export | Boundary |
| --- | --- | --- |
| Retained native VIEW retrieval envelope | IIIF image painting using exact token, capture, output, Archive object and received-byte correspondence | An operator separately designates the image as the WORK's painting resource; receipt of bytes does not prove artist approval or browser execution |
| Native record and receipt | PREMIS publication event linked to that record's retained payload file and receipt account | Publication of an assertion does not prove the asserted underlying activity occurred |
| Retained native RIGHTS history | Documentary PREMIS rights statement, original dates and all six act/status declarations | The export does not adjudicate a permission or grant rights |
| Receipt account and notice's named licensor | Distinct, qualified PREMIS agent occurrences | Owner, attestor and recorder retain their original family-specific roles; a declared name is not authenticated identity |

## IIIF painting correspondence

The source joins an original VIEW reference capture to the exact token and
collection serial, retained metadata JSON and HTML, and the declared PNG
Archive object. Complete retained media bytes must satisfy the object's
Keccak-256, SHA-256 and size commitments. The exporter uses those native joins;
equal titles, coincidental identifiers and collection-level media roles do not
establish token correspondence.

The plan separately records the operator's painting designation and export
context. That designation does not become an artist-authorized statement.
Labels, dimensions or rights supplied as export context keep their operator
attribution. The image body uses a raw-content IPFS CID whose SHA-256 digest
matches the retained file digest. An Arweave transaction identifier alone does
not provide that byte binding. The captured retrieval route remains separate from
that identifier; neither establishes current network availability. A collection
master or a pre-sale prospective render is not silently substituted for the
exact retained token capture. The selected full WORK must identify the exact
target token or its collection; collection-level applicability still requires
the operator's explicit designation. A foreign subject is rejected.

PNG is the original object's declared `IANA:image/png` format. The exporter
does not detect a media type or intrinsic image dimensions. Positive bounded
`width` and `height` in the plan describe the operator's IIIF layout.

Missing or insufficient source evidence remains explicit. The exporter does
not retrieve a URI, execute a renderer, inspect a remote image, perform a safety
scan or publish the supplied media. The original VIEW history remains visible
before painting selection.

## PREMIS publications, agents and rights

Publication events describe the original record publication. Their time,
receipt account and payload-file link come from the exact original record and
receipt. They do not turn a condition statement, preservation plan, fixity
label or drill record into evidence of a performed examination or successful
preservation activity. Owner and attestor accounts retain their own receipt
roles; they are not relabeled as recorders or transaction submitters.

Rights statements preserve the notice's basis, original applicable dates,
named licensor, and each act's status and condition as documentary information.
Denied and unspecified statuses remain visible. This profile emits neither
`rightsGranted` nor `termOfGrant`. The named licensor is a declared party;
the native receipt account retains its separate family-specific authority.

Rights remain scoped to their original native subject and instrument. The
exporter does not attach a notice to an artwork media object merely because
their identifiers or labels appear related.

## Separate field coverage

The original source-field inventory and its denominator are unchanged. Two
additional inventories retain the original RIGHTS and VIEW source domains
before export selection. Every original scalar, null and empty container in
each inventoried domain has its own exact field entry.

The package verifier independently resolves those domains from the retained
V4 bytes and checks the complete field set and canonical values. A rewritten
field inventory cannot conceal a denied right, remove an empty or unknown
value, or introduce an invented field while preserving the original source.

| Path | Evidence |
| --- | --- |
| `conformance/source-field-inventory.json` | Unchanged original native field denominator |
| `premis/supplemental-source-inventory.json` | Original retained rights domains and fields |
| `iiif/supplemental-source-inventory.json` | Original retained VIEW domains and fields |
| `conformance/native-format-field-ledger.json` | Actual target mappings of the original native fields |
| `conformance/supplemental-format-field-ledger.json` | Separately resolved supplemental fields and target evidence |
| `conformance/supplemental-source-family-coverage.json` | Separate source-family occurrence, field and mapped counts |

Operator context, generated values and measurements computed over retained
bytes do not increase original mapped-field counts. Equal values from different
occurrences remain distinct. Same-field comparisons preserve differing target
representations and do not establish full semantic equivalence.

## Assemble and reopen

Use the [Museum Python environment](../tools/museum/README.md). The outer
canonical JSON plan has `version: "2"`, `sourceManifestHash` and `adapters`.
Supply all four complete adapter plans for the same V4 source: unchanged
Linked Art and LIDO plans, and the new PREMIS and IIIF V2 plans. Exact plan
schemas and source-inventory profiles are retained in the package.

The PREMIS V2 plan uses `kind: "native_premis"`, with `selected` for the
original native occurrences and `selectedRights` for exact rights notice
occurrence IDs and selectors from its separate source inventory. A scope row
is retained evidence, not a selectable rights notice.

The IIIF V2 plan uses `kind: "native_iiif_painting"`. Each selected entry names
the exact WORK occurrence and selector, then a `source` object containing
`captureOccurrenceId`, `captureSelector`, `objectHash` and
`materialRecordHash`. These identify the original VIEW capture and operative
received material. Its separate `context` supplies the explicit operator
designation and bounded export metadata. An empty selection creates no
painting and keeps the original source inventory visible.

```powershell
python -m tools.museum.native_multiformat_package_v2 assemble --source <v4-directory> --source-hash <v4-manifest-hash> --plan <export-plan.json> --plan-hash <export-plan-hash> --disclosure public --output <new-directory>
python -m tools.museum.native_multiformat_package_v2 verify <new-directory> --manifest-hash <export-manifest-hash>
python -m tools.museum.package_v2 verify <new-directory> --manifest-hash <export-manifest-hash>
python -m tools.museum.native_multiformat_package_v2 profiles
```

Public disclosure is explicit and checked before input reads. Output must be
new and outside the inputs. Offline reopening replays the original V4, both
new source interpretations, all four formats and the field ledgers using the
retained validation dependencies, then compares every output byte.

## Remaining acceptance

The original nineteen packet groups and forty-nine assessments are unchanged.
Native source correspondence, operator assertions, observed receipt authority
and source authenticity remain separate. Broader preservation activities,
artist-approved artwork depictions, additional source families and complete
cross-format semantics still require their own evidence and mappings.
Institutional ingest, practitioner review and live-source acceptance remain
separate requirements of the [adopted specification](museum-semantic-mapping.md).
