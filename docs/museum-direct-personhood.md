# Native DIRECT personhood source join

This additive workflow compares the personhood commitment saved in a native
DIRECT conservation first-sale receipt with one bounded current Artist
personhood capture. It preserves the original DIRECT, provider-binding and
personhood packages byte for byte. It does not reinterpret the DIRECT sale as
a universal settlement or change any earlier profile.

The workflow is prospective. Synthetic fixtures exercise the same ABI, hash
and offline replay checks but are not deployed-chain evidence.

## Evidence boundary

The DIRECT capture retains two different evidence layers:

- the shared conservation-floor `FirstSale` receipt, whose collection facts
  commit the Artist ID, registration identity and personhood evidence hash;
- the DIRECT sale receipt, its domain-separated key and hash, the original
  adapter event, the saved adapter/manager bindings and the manager's used
  authorization and operation-root observations.

The second layer establishes the retained DIRECT adapter correspondence. It
does not replace the first layer as the source of the saved personhood
commitment. The join therefore takes `artistId`, `identityRecordHash`,
`personhoodEvidenceHash` and `platformWorks` from the exact shared first-sale
receipt. It never reads those values from current Artist state or from an
unrelated later DIRECT sale.

The retained DIRECT evidence keeps its three native hash domains distinct:

- `6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1` binds the deployment chain, Core,
  adapter, product and authorization;
- `6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1` binds the complete original
  adapter sale receipt; and
- `6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1` binds the conservation-floor
  DIRECT receipt and its exact original-receipt hash.

The validated DIRECT representation is `STREAM_ACQUISITION_DIRECT_FLOOR_V1`.
Its adapter and manager observations are the authority retained by the original
DIRECT source; they are not a signature, legal-title or present authorization
claim.

The provider-binding package supplies the exact saved provider configuration.
Configuration targets 0, 1 and 8 must match the personhood capture's Core,
Metadata host and Artist facade, including the corresponding runtime hashes.
This proves dependency identity within the supplied evidence. It does not
prove that the provider executed the historical DIRECT sale, that its admitted
runtime matches a published artifact, or that the chain observations have
consensus finality.

The current personhood evidence receives one of four qualified results:

- `not_required_platform_floor` when the saved first-sale facts identify a
  platform work;
- `current_waiver_matches_saved` only when the saved and current Artist IDs
  match and the current native waiver's operation-24 record hash equals the
  saved commitment;
- `current_resolved_summary_matches_saved` only when the saved and current
  Artist IDs match and the current proof-summary hash equals the saved
  commitment;
- `saved_commitment_not_currently_identifiable` for a stale, unresolved,
  absent or otherwise nonmatching current head.

The waiver and resolved cases use different hash domains. A waiver commits the
original native operation-24 record hash. Resolved evidence commits:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"),
  Summary
))
```

An identity rotation, imported original Registry or later head cannot rewrite
the saved first-sale commitment. The source keeps the registration identity,
the original operation-24 identity and the current operative identity
separate. The saved conservation registration and the source-current
registration also remain distinct. This workflow does not supply the historical
selection source needed to resolve the saved registration record; it reports
that join as `selection_source_not_supplied`. When a supported General
attestation backs the selected summary, its complete original payload, receipt
and authority evidence remain supplied data; they are not promoted to legal
truth or institutional standing.

## Four-source replay

The assembly has two top-level inputs, but those packages retain and replay
four native source families:

1. the original DIRECT conservation floor capture;
2. the historical RIGHTS capture already joined beneath the provider-binding
   input;
3. the original provider-configuration capture; and
4. the current personhood capture.

Every top-level package must first pass its own verifier and external manifest
pin. The assembler then checks the exact shared chain, Core, collection, block,
timestamp, state root, environment and deployment-evidence commitments. It
also reconciles repeated RPC answers, runtime pins, headers, receipts and log
pages across the retained transcripts. No anchor is projected or silently
rebased.

The output contains two closed supplied-data representations:

- `STREAM_ACQUISITION_DIRECT_FLOOR_V1` retains the DIRECT first-sale identity,
  adapter authority and exact DIRECT source references;
- `STREAM_ACQUISITION_PERSONHOOD_V1` retains the current/native Artist and
  General evidence with exact personhood source references.

`documentary/personhood.json` records the bounded correspondence between the
saved first-sale commitment and the current evidence. These files remain
separate from the unchanged acquisition packet formats.

## Assembly API and CLI

`tools.museum.acquisition_direct_personhood` assembles and verifies the two
externally pinned inputs. The disclosure must be `public`, and the output
directory must be new.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_direct_personhood assemble `
  --provider-binding direct-provider-binding `
  --provider-binding-hash $providerBindingHash `
  --personhood personhood-capture `
  --personhood-hash $personhoodHash `
  --disclosure public `
  --output direct-personhood-assembly

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_direct_personhood verify `
  direct-personhood-assembly --manifest-hash $manifestHash
```

Verification reconstructs the assembly from the retained original inputs and
compares every output byte. Replay is offline and performs no RPC or network
lookup.

`complete-packet` verifies the assembly and then refuses completion:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_direct_personhood complete-packet `
  direct-personhood-assembly --manifest-hash $manifestHash
```

## Qualification

This workflow does not add a tier/default capture, conservation selection
capture, universal settlement, owner/title proof, payment reexecution,
historical personhood-currentness proof or complete acquisition packet. It does
not claim that a current identity or notarization was current at the sale.
DIRECT adapter authority, provider configuration, Artist authority and General
documentary authority remain distinct in the retained evidence.

The output is an additive supplied-data fragment and a bounded correspondence
report. Complete-packet export remains unavailable until the missing packet
requirements are supplied and validated under an adopted profile.
