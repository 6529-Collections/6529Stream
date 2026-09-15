# Recorded exhibition export

The exhibition adapter implements a finite part of
[CMC-EXHIBITION-LOAN](collection-metadata-contract.md#exhibition-and-loan-records-cmc-exhibition-loan)
and [MSM-MAPPING](museum-semantic-mapping.md#4-required-crosswalk-coverage-msm-mapping).
It consumes exact public `INDEPENDENT_EXHIBITION` records from the existing
recorded account capture. The original class-5 receipt, subject, registered
schema bytes and JCS definition remain the admission evidence. A named
institution in the payload is an attributed identity claim, separate from the
authenticated account that published it.

The generated `schemas/museum/exhibition/STREAM_EXHIBITION_V1.json` is an
explicit closed candidate serialization of the required exhibition fields.
It is not a claim of genesis registration. The adapter accepts only that exact
definition when it is actually registered in a selected capture; it does not
reinterpret another schema carrying the same name. The separate versioned
export profile pins the mapping and existing offline Linked Art validator.

The payload retains the exhibition IRI, collection or token subject, status,
institution identity/name/reference, named venue and location reference, title
and its reference, opening/closing dates, display parameters, optional actual
Artist intent record reference, catalogues and wall labels. All document
references retain their complete original URI and HashRef. Referencing an
Artist intent record does not prove compliance with it or permit a display.
No referenced document is fetched or described as byte-verified.

Only explicitly completed source statements produce an Activity. Its original
named institution becomes a Group participant (CRM P11), and its named venue a
Place related through `took_place_at`. Participant does not imply organizer,
rights holder, owner or custodian. Planned, cancelled and unknown statements
remain full nonperformed sidecars. Missing names yield precise unsupported
dispositions rather than labels invented from URIs or account addresses.

Gregorian UTC bounds use only the explicit source values. The four original
outer/inner bounds remain distinct; range and approximate precision stay in
the complete source sidecar. Unknown dates acquire no bounds. Other calendars
or timezones retain their expressions and values without a guessed conversion.
Publication and export timestamps never become exhibition dates. Language
declarations are retained without inventing authority-language identifiers.

Every original scalar, null and empty collection has a source-pointer coverage
row; the full original record remains in the sidecar and nested source package.
Every emitted target value has its source selector, mapping rule and original
field paths. Selected declaration collisions reject, including a new exhibition
entity that would reuse a selected entity from the original graph. Unselected
hostile declarations never choose or veto the new projection.

## Offline commands

Use the existing Museum Python environment; no new dependency is required.

```text
python -m tools.museum.exhibitions --check
python -m unittest tools.museum.test_exhibitions -v
python -m tools.museum.exhibition_package build RECORDED_PACKAGE PLAN.json OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public
python -m tools.museum.exhibition_package verify OUTPUT --manifest-hash HASH
```

The canonical plan has exactly `version: "1"`, `sourceStateHash` (Keccak-256
of the original recorded source identity bytes) and `records` (complete original
selectors with empty pointers). The plan and profile both require external
hash pins. At most 64 records may be selected; each original native payload is
at most 8,192 bytes and the plan is at most 524,288 bytes.

The derivative literally retains the verified original recorded package,
stores its plan/definitions and rebuilds all graph, coverage and source evidence
offline. The generic v2 verifier dispatches only its distinct package mode.
Tampered outputs remain invalid even with a newly computed outer file manifest.
Restricted exports reject before construction; output uses the original
no-overwrite package writer. Earlier package modes and profile bytes are unchanged.

## Evidence boundary and next actual example

Positive focused cases are explicit synthetic typed controls. The retained
actual recorded fixture has no selected exhibition record, so its package test
replays the original source and produces `no_selected_exhibition_records`.
That test is an honest absence case, not a positive exhibition capture.

The smallest later positive capture can reuse the current foundation/attestor
fixture without compiling Solidity: register this exact candidate schema with
the already registered JCS definition, publish a public test-fixture exhibition
through actual `INDEPENDENT_EXHIBITION` and a Safe, then select the returned
record/receipt at the same anchored block. Capture its normal schema, chunk,
signature and publication-order closure; build the existing recorded package,
then this derivative using the exact returned selector. Retain loopback-fixture
provenance and do not represent the test statement as a real exhibition.

Loan/custody interpretation, other record-authority lanes, external document
retrieval, institutional review and complete LIDO/IIIF exhibition correspondence
remain separate requirements. This batch makes no institutional, historical
performance, rights, custody, display-authorization or live API conformance claim.
