# Recorded account IIIF presentation

`STREAM_MUSEUM_RECORDED_ACCOUNT_IIIF_V1` adds a versioned Presentation 3 export for the [verified recorded-account source](museum-recorded-account.md). It consumes the same selected resources and [recorded PREMIS file evidence](museum-recorded-premis.md). The registered account profile and existing synthetic profiles stay unchanged.

## Selected evidence and layout

The version-1 plan uses mode `recorded_account_iiif_presentation_projection`. It pins the actual source state, registered account profile, Linked Art plan, recorded PREMIS plan and this IIIF export profile. It chooses an abstract work, Manifest identifier and one to 128 ordered Canvas entries with distinct Canvas, AnnotationPage and Annotation identifiers. These HTTP target identifiers cannot alias source entities. The distinct file set must equal the PREMIS plan exactly.

The plan supplies layout, not content facts. Every requested file needs the selected PREMIS declarations and the original [IIIF profile's explicit facts](museum-iiif-correspondence.md): media type, MIME, content URI, attribution, rights and file-to-work association. Image and Video require pixel width/height; Video and Sound require exact fractional seconds; Text requires separate declared Canvas dimensions. The work needs summary, attribution and its own Manifest rights statement. Work and file labels require explicit unspecified-language source names. No label, dimensions, rights, creator or URI is inferred from an account, filename, token or payload.

The adapter uses the original field pointers, selected revisions and historical account issuers. Opted-in account SELF reviews retain that classification. Unselected records do not veto the selection, and conflict checks use only the fields consumed for each work/file role. A complete selection passes the original strict renderer, content-address/digest checks, pinned contexts and target schemas. Numeric lexicals and distinct source/display identities remain intact.

Missing selected facts, absent resource types or omitted conflict-policy relations return `unsupported`, precise diagnostics and no Manifest. An unavailable recorded PREMIS projection is named with its report hash and exact missing evidence. This incomplete result is an availability report, not validation of every present value. Complete inputs still reject malformed values, conflicting facts, invalid source associations and unsupported interpretations. No subset is silently omitted to make the remaining files pass.

## Package command

Add `--iiif-plan`, `--iiif-plan-hash` and `--iiif-profile-hash` together, alongside all three recorded PREMIS inputs. The new package mode is `recorded_account_iiif_resource_package`, version 2. The prior base and PREMIS modes remain available and reproducible.

The checked-in example selects the unchanged actual local-EVM capture. Its file and work exist, but required file and presentation facts are absent. The expected output is an unsupported report, **not** a recorded Manifest:

~~~powershell
$pins = Get-Content 'schemas/museum/multiformat/recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$premis = Get-Content 'schemas/museum/premis-recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$iiif = Get-Content 'schemas/museum/iiif-recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$arguments = @(
  '-m', 'tools.museum.package_v2', 'build-recorded',
  'schemas/museum/account-profile/local-fixture', 'tmp/museum-recorded-iiif',
  '--disclosure', 'public', '--source-hash', $pins.source,
  '--publication-hash', $pins.publication, '--interpretation-hash', $pins.interpretation,
  '--profile-hash', $pins.profile, '--selection-hash', $pins.selection, '--plan-hash', $pins.plan,
  '--premis-plan', 'schemas/museum/premis-recorded/missing-file-plan.json',
  '--premis-plan-hash', $premis.premis_plan, '--premis-profile-hash', $premis.premis_profile,
  '--iiif-plan', 'schemas/museum/iiif-recorded/missing-presentation-plan.json',
  '--iiif-plan-hash', $iiif.iiif_plan, '--iiif-profile-hash', $iiif.iiif_profile
)
python @arguments
~~~

A supported projection adds `iiif/manifest.json`, correspondence, coverage and provenance. An unsupported one includes its exact plan, profile and diagnostic report. Both retain the original capture, source evidence and complete pinned validation dependency closure. Public classification covers every capture input; restricted input is rejected before export. Verification rebuilds the result offline from the package and its independently retained hash:

~~~text
python -m tools.museum.package_v2 verify tmp/museum-recorded-iiif --manifest-hash <printed-hash>
python -m unittest tools.museum.test_recorded_iiif tools.museum.test_iiif -v
~~~

## Evidence and remaining work

The retained actual capture exercises recorded admission, missing-fact diagnostics and package replay. Complete four-media rendering controls are explicitly synthetic; they are not a new recorded positive capture. No capture campaign or on-chain change accompanies this adapter.

No media are fetched, no declared digest is verified against bytes, and no format detection, viewer interoperability, consensus finality or institutional conformance is claimed. Recorded LIDO, broader PREMIS object/event/agent/rights support, canonical preservation-source admission and institutional acceptance remain separate work.
