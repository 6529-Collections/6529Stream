# Offline multi-format museum package

Resource-package version 2 exports one selected public fixture as Linked Art v2 resources, PREMIS file/fixity XML, an IIIF Presentation 3 Manifest and LIDO work/creation/media XML. It includes exact source records and schemas, selection policy, four projection plans, original interpretation dependencies, per-format coverage and attribution, and a shared-identity correspondence report.

It uses the existing [LIDO pipeline](museum-lido-correspondence.md), which composes [IIIF](museum-iiif-correspondence.md), [PREMIS](museum-premis-file-projection.md) and [Linked Art v2](museum-abstract-nonvisual-projection.md). These mappings and original v1 resource packages remain unchanged.

## Build and verify

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

## Contents and identity

- inputs/ retains the source-state wire, exact selection policy and all four plans.
- dependencies/ retains every selected local Linked Art, vocabulary, PREMIS, IIIF and LIDO chunk and index, plus interpretation policies and licenses.
- definitions/ retains the versioned crosswalk and format profile definitions.
- linked-art/ contains canonical resources, offline expansions, entity index, original-source sidecar and reports.
- premis/, iiif/ and lido/ contain the format document and correspondence, coverage, provenance and validation report.
- reports/shared-identity.json assembles the existing correspondence tables without collapsing entity roles.

Work, content, file, presentation Canvas, source issuer and creator retain distinct identifiers. Uncertain dates, original text, exact integers/decimals, qualifiers and unsupported facts remain in source bytes and sidecars. Each format retains the same source-derived field denominator; projection dispositions may differ.

The source state, selection policy and all plans must agree. The exporter does not invent absent facts, repair mismatched plans, infer creator authority from an issuer or omit a required format. Limits remain 8,192 child files, 96 MiB aggregate child bytes and a 2 MiB offline manifest, separate from onchain payload limits.

## Scope

This candidate package accepts wholly public synthetic fixtures. It rejects recorded_state and restricted records. The independent-account recorded projection remains separate; this command does not authenticate or promote it.

It retains declared fixity without retrieving media or claiming a fixity check. It is not a registered semantic export, complete dossier, BagIt bag, OCFL object or institutional conformance result. Broader PREMIS events/agents/rights, additional source-family mappings, authorized disclosure and institutional reconstruction evidence remain required.
