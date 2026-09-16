# Recorded account PREMIS file projection

`STREAM_MUSEUM_RECORDED_ACCOUNT_PREMIS_V1` projects explicitly selected file assertions from the [verified recorded-account source](museum-recorded-account.md) into the original PREMIS 3 XSD. This is a separate, prospective export profile; it does not change the registered account interpretation or synthetic PREMIS profile.

The caller supplies an exact version-1 plan with mode `recorded_account_premis_file_projection`, source-state hash, registered account profile hash, Linked Art plan hash, this PREMIS profile hash and an explicit list of object IRIs. Each IRI must join a selected Linked Art DigitalObject. This remains a supplemental declared file identity, not an inference that the file, artwork token and work are identical.

## Required selected evidence

Each selected object needs four unqualified original assertions. All four relations must be in the selected account policy's single-valued conflict set.

| Relation suffix under urn:6529stream:museum:premis-file:v1: | Exact source value |
| --- | --- |
| category | xsd:string `file` |
| byte-size | Canonical xsd:nonNegativeInteger decimal, no greater than 2^63-1 for PREMIS xs:long |
| sha256 | xsd:string with exactly 64 lowercase hexadecimal digits |
| pronom-puid | xsd:string `fmt/N` or `x-fmt/N`, with positive canonical N |

The adapter uses the original registered payload, complete record selector, historical account and selected revision. It does not derive file size from record payload length or turn a record hash into file fixity. Direct statements and opted-in account SELF reviews retain the existing authority rules; unselected records cannot veto the chosen source set. XML provenance retains the original issuer and exact source field pointer. Full source inventories and original bytes remain available in the Linked Art sidecar.

Missing selected files, absent facts and omitted conflict-policy relations produce an `unsupported` report with precise entity/relation diagnostics and no XML. A malformed, qualified, conflicting or out-of-range present fact rejects even when another required fact is absent. The adapter neither repairs source values nor omits a requested file to make the remaining subset pass.

## Build and verify

Use the existing Python environment from [the Museum tools README](../tools/museum/README.md). Supply `--premis-plan`, `--premis-plan-hash` and `--premis-profile-hash` together to the recorded package command. The resulting mode is `recorded_account_premis_resource_package`, version 2; original recorded and synthetic package modes remain reproducible.

This example uses the unchanged actual local-EVM capture. That capture has a selected DigitalObject but **does not contain the four file facts**, so the expected result is an unsupported PREMIS report, not XML:

~~~powershell
$pins = Get-Content 'schemas/museum/multiformat/recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$premis = Get-Content 'schemas/museum/premis-recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$arguments = @(
  '-m', 'tools.museum.package_v2', 'build-recorded',
  'schemas/museum/account-profile/local-fixture', 'tmp/museum-recorded-premis',
  '--disclosure', 'public', '--source-hash', $pins.source,
  '--publication-hash', $pins.publication, '--interpretation-hash', $pins.interpretation,
  '--profile-hash', $pins.profile, '--selection-hash', $pins.selection, '--plan-hash', $pins.plan,
  '--premis-plan', 'schemas/museum/premis-recorded/missing-file-plan.json',
  '--premis-plan-hash', $premis.premis_plan, '--premis-profile-hash', $premis.premis_profile
)
python @arguments
~~~

For a source with all admitted facts, the package includes PREMIS XML, correspondence, coverage and provenance, plus the original pinned XSD closure. For an incomplete source it retains the same source evidence, exact requested plan, versioned profile, XSD and diagnostic report. The shared format-support report distinguishes those outcomes. Restricted input remains unsupported before export. Keep the printed package hash independently and verify without RPC:

~~~text
python -m tools.museum.package_v2 verify tmp/museum-recorded-premis --manifest-hash <printed-hash>
python -m unittest tools.museum.test_recorded_premis tools.museum.test_premis -v
~~~

## Evidence and remaining scope

The retained actual capture exercises source admission and missing-fact reporting. Positive XML and complete-file controls use explicit synthetic selected facts and the shared exact renderer; they are not an actual recorded positive-file capture. No new capture campaign is performed by this increment.

The output preserves declared fixity and format identifiers. It does not retrieve media, verify bytes, detect file format, create a preservation event or establish finality. Canonical preservation objects, recorded PREMIS events/agents/rights and institutional acceptance remain separate work. A separately pinned [recorded LIDO adapter](museum-recorded-lido.md) also consumes explicit work and publisher facts. The additive [recorded IIIF adapter](museum-recorded-iiif.md) now consumes this file projection plus explicit selected presentation facts.
