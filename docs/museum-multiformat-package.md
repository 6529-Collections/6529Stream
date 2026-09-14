# Offline multi-format museum package

The synthetic mode of resource-package version 2 exports one selected public fixture as Linked Art v2 resources, PREMIS file/fixity XML, an IIIF Presentation 3 Manifest and LIDO work/creation/media XML. It includes exact source records and schemas, selection policy, four projection plans, original interpretation dependencies, per-format coverage and attribution, and a shared-identity correspondence report.

It uses the existing [LIDO pipeline](museum-lido-correspondence.md), which composes [IIIF](museum-iiif-correspondence.md), [PREMIS](museum-premis-file-projection.md) and [Linked Art v2](museum-abstract-nonvisual-projection.md). These mappings and original v1 resource packages remain unchanged.

## Build and verify a synthetic fixture

Use the existing environment in [the tooling guide](../tools/museum/README.md), with no additional dependency. Run from the repository root. This PowerShell example passes the retained input pins explicitly:

~~~powershell
$fixture = 'schemas/museum/multiformat/fixture'
$pins = Get-Content "$fixture/pins.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$arguments = @(
  '-m', 'tools.museum.package_v2', 'build-fixture',
  "$fixture/source-state.json", "$fixture/selection.json", "$fixture/plan.json",
  "$fixture/premis-plan.json", "$fixture/iiif-plan.json", "$fixture/lido-plan.json",
  'tmp/museum-multiformat',
  '--profile-hash', $pins.profile_hash, '--selection-hash', $pins.selection_hash,
  '--plan-hash', $pins.plan_hash, '--premis-plan-hash', $pins.premis_plan_hash,
  '--iiif-plan-hash', $pins.iiif_plan_hash, '--lido-plan-hash', $pins.lido_plan_hash,
  '--validation-hash', $pins.validation_hash, '--vocabulary-hash', $pins.vocabulary_hash
)
python @arguments
~~~

The output directory must not already exist. Keep the printed manifest hash outside the package, then verify:

~~~text
python -m tools.museum.package_v2 verify tmp/museum-multiformat --manifest-hash <printed-hash>
python -m unittest tools.museum.test_package_v2 -v
~~~

Verification uses only archived inputs and dependencies. It checks the external manifest hash, every child file's length, SHA-256 and Keccak-256, then regenerates all four representations and compares the complete file set and bytes. Missing, additional, altered, duplicate, case-colliding and escaping paths reject. Updating a child digest alone cannot admit inconsistent XML, correspondence or coverage.

## Synthetic contents and identity

- inputs/ retains the source-state wire, exact selection policy and all four plans.
- dependencies/ retains every selected local Linked Art, vocabulary, PREMIS, IIIF and LIDO chunk and index, plus interpretation policies and licenses.
- definitions/ retains the versioned crosswalk and format profile definitions.
- linked-art/ contains canonical resources, offline expansions, entity index, original-source sidecar and reports.
- premis/, iiif/ and lido/ contain the format document and correspondence, coverage, provenance and validation report.
- reports/shared-identity.json assembles the existing correspondence tables without collapsing entity roles.

Work, content, file, presentation Canvas, source issuer and creator retain distinct identifiers. Uncertain dates, original text, exact integers/decimals, qualifiers and unsupported facts remain in source bytes and sidecars. Each format retains the same source-derived field denominator; projection dispositions may differ.

The source state, selection policy and all plans must agree. The exporter does not invent absent facts, repair mismatched plans, infer creator authority from an issuer or omit a required format. Limits remain 8,192 child files, 96 MiB aggregate child bytes and a 2 MiB offline manifest, separate from onchain payload limits.

## Scope

`build-fixture` accepts wholly public synthetic fixtures and rejects recorded state. `build-recorded` uses the separate verified account capture described below. Both require public inputs; restricted export is unsupported.

It retains declared fixity without retrieving media or claiming a fixity check. It is not a registered semantic export, complete dossier, BagIt bag, OCFL object or institutional conformance result. Broader PREMIS events/agents/rights, additional source-family mappings, authorized disclosure and institutional reconstruction evidence remain required.

## Package an existing recorded-account capture

`build-recorded` produces the distinct `recorded_account_resource_package` v2 mode. It reuses the [recorded-account source, publication and registered interpretation verification](museum-recorded-account.md). It never converts a fixture state or changes a synthetic plan's mode. The base mode supports Linked Art v2 through the account profile and retains its original unsupported-format results. An explicit [recorded PREMIS plan and profile](museum-recorded-premis.md) now opt into the separate `recorded_account_premis_resource_package` mode. That adapter produces PREMIS when all selected file facts are available, otherwise exact unsupported diagnostics. Recorded IIIF and LIDO remain unsupported. No placeholder XML, IIIF manifest, media URI, dimensions or fixity claim is generated for those formats.

The input directory must retain these eleven original files:

- anchor.json, deployment-evidence.json and transcript.json;
- publication-hints.json and publication-transcript.json;
- interpretation-transcript.json;
- source-capture.json, publications.json and interpretation.json;
- selection.json and plan.json.

The three captured result files must match exact replay bytes. Deployment evidence must match the anchor's original hash; the package does not independently approve the deployment's runtime semantics. Source, publication and interpretation CLI pins are the **transcript** hashes, not the captured result hashes. Profile, selection and plan pins retain their existing meanings. Admit those pins and the anchor through an independent trusted channel before using this command.

This example replays the existing actual local-EVM capture. It does not run a chain, compile contracts or relabel the public synthetic fixture:

~~~powershell
$recorded = 'schemas/museum/account-profile/local-fixture'
$pins = Get-Content 'schemas/museum/multiformat/recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$arguments = @(
  '-m', 'tools.museum.package_v2', 'build-recorded', $recorded,
  'tmp/museum-recorded-package', '--disclosure', 'public',
  '--source-hash', $pins.source, '--publication-hash', $pins.publication,
  '--interpretation-hash', $pins.interpretation, '--profile-hash', $pins.profile,
  '--selection-hash', $pins.selection, '--plan-hash', $pins.plan
)
python @arguments
~~~

The new output directory receives the eleven exact inputs, verified registered definitions, complete model/vocabulary dependency chunks, original Linked Art resources and source sidecars, and reports for source evidence, per-record disclosure and format support. `--disclosure public` explicitly classifies **all retained input bytes**, including deployment evidence and transcripts. Every admitted source record must also be public. `--disclosure restricted` rejects before reading input files or creating output; this is not a redaction or restricted-access package implementation.

~~~text
python -m tools.museum.package_v2 verify tmp/museum-recorded-package --manifest-hash <printed-hash>
python -m unittest tools.museum.test_package_recorded -v
~~~

Verification checks the manifest and complete file inventory, then replays only archived inputs and dependencies and compares all resulting bytes. It preserves `local_evm_fixture` versus `public_chain`, exact historical account attribution and explicit SELF-review rules. Captured registry verification is distinct from registering the generated export. Trusted-RPC replay is not a cryptographic state proof, consensus-finality verification, public-deployment acceptance, human-identity proof or institutional conformance.
