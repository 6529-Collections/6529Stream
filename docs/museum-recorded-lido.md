# Recorded account LIDO work export

`STREAM_MUSEUM_RECORDED_ACCOUNT_LIDO_V1` composes [recorded IIIF](museum-recorded-iiif.md), PREMIS and Linked Art with selected work, creation and publisher statements. It reuses the original LIDO 1.1 XSD and strict XML renderer under a separate export profile. Existing synthetic profiles and earlier recorded package modes remain reproducible.

## Publisher and account are different facts

The historical account remains the issuer of each selected record. It is not converted into a Person, Group or legal body. The LIDO record source instead needs a separately selected `urn:6529stream:museum:lido-work:v1:record-publisher` assertion from the selected work to a locally declared Person/Group with explicit names. Each account contributing any selected assertion or entity record must itself supply that selected publisher assertion. Version 1 requires one common publisher; the relation must be in the single-valued conflict policy.

An unselected publisher claim, a different account's claim, the creator identity and the account IRI cannot fill this requirement. The statement expresses the account's declared record publisher; it does not establish a legal identity or that person's authority. The original account issuer, record selector, payload and authority evidence remain in correspondence. XML provenance separately joins the publisher assertion and the selected publisher declaration/name.

## Required selected work facts

The work requires explicit work type, medium, edition, credit line, creation-event reference and `und` document language. The referenced event must be an explicitly declared creation event, with creator reference and creation-display text. The creator and publisher require local Person/Group declarations and explicit names; their roles remain distinct. Source name languages must be null or `und`. Work credit must match the same selected IIIF attribution. Dates remain display statements, not inferred intervals.

The [original LIDO correspondence rules](museum-lido-correspondence.md) still require the same selected IIIF/PREMIS files and preserve XML field provenance and exact media extents. The record identifier cannot alias work, creator, publisher, account, derived source-record or presentation identifiers. No requested media is silently dropped.

Missing facts, local declarations, compatible names, per-account publisher statements or conflict-policy entries produce precise `unsupported` diagnostics and no XML. Missing IIIF/PREMIS evidence is identified by the corresponding report hash and nested diagnostics. Present malformed or contradictory consumed LIDO statements reject; complete selections pass the original renderer and XSD. No creator, date, publisher, name, rights or language is inferred to make an export succeed.

## Build and verify

Pass `--lido-plan`, `--lido-plan-hash` and `--lido-profile-hash` together, alongside all PREMIS and IIIF inputs. The result is `recorded_account_lido_resource_package`, version 2. The plan pins source state, account profile, all three prior plans and this LIDO profile; its only additional layout field is the LIDO record URI.

The checked-in plan targets the unchanged actual local-EVM capture. That capture lacks the necessary file/presentation/work/publisher facts, so this command is expected to produce diagnostic reports, not a LIDO file:

~~~powershell
$pins = Get-Content 'schemas/museum/multiformat/recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$premis = Get-Content 'schemas/museum/premis-recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$iiif = Get-Content 'schemas/museum/iiif-recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$lido = Get-Content 'schemas/museum/lido-recorded/pins.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$arguments = @(
  '-m', 'tools.museum.package_v2', 'build-recorded',
  'schemas/museum/account-profile/local-fixture', 'tmp/museum-recorded-lido',
  '--disclosure', 'public', '--source-hash', $pins.source,
  '--publication-hash', $pins.publication, '--interpretation-hash', $pins.interpretation,
  '--profile-hash', $pins.profile, '--selection-hash', $pins.selection, '--plan-hash', $pins.plan,
  '--premis-plan', 'schemas/museum/premis-recorded/missing-file-plan.json',
  '--premis-plan-hash', $premis.premis_plan, '--premis-profile-hash', $premis.premis_profile,
  '--iiif-plan', 'schemas/museum/iiif-recorded/missing-presentation-plan.json',
  '--iiif-plan-hash', $iiif.iiif_plan, '--iiif-profile-hash', $iiif.iiif_profile,
  '--lido-plan', 'schemas/museum/lido-recorded/missing-work-plan.json',
  '--lido-plan-hash', $lido.lido_plan, '--lido-profile-hash', $lido.lido_profile
)
python @arguments
~~~

A complete input adds `lido/lido.xml`, correspondence, coverage and provenance. An incomplete input retains the exact requested plan, profile and unsupported report. Both preserve captured bytes and the complete pinned dependency closure. Public input classification is required; restricted export is rejected before writing. Verify using the independently retained package hash:

~~~text
python -m tools.museum.package_v2 verify tmp/museum-recorded-lido --manifest-hash <printed-hash>
python -m unittest tools.museum.test_recorded_lido -v
~~~

## Later positive current-stack capture

The adapter's complete rendering/publisher controls are explicitly synthetic. The existing recorded capture exercises genuine historical account admission and incomplete-source reporting, but uses the documented Core/Executor/signature boundary contracts. Neither proves a complete current-stack museum export.

The smallest later joined rehearsal needs one actual current Core collection, real Executor and governed SchemaRegistry/ChunkStore, a real attestor Safe and the real StreamCollectionAttestations satellite pinned to those dependencies. Reuse reviewed native artifacts; publish the unchanged RAW_BYTES, JCS and account-profile definitions through the class-1 `registrationTransition`/Executor route already exercised by [StreamCurrentSchemaRegistry](../test/current/StreamCurrentSchemaRegistry.t.sol).

Publish an initial independent source statement, then account-authored semantic records of at most 8,192 bytes each. Use one retained public test-image file with its actual SHA-256 and matching content-addressed URI; explicitly mark it as test data. Declare the file, work, creation event, creator and distinct publisher. Include all four PREMIS facts, Image type/MIME/pixel dimensions, file/work attribution and rights, explicit presentation-of link, work summary, all LIDO work/event facts and the publisher statement. Prefer direct account statements for the first positive case; do not silently treat human mappings as reviewed.

Submit `recordIndependentPreservation` through the actual Safe, retain its original payload/signature/receipt/publication bytes, and capture the source, publication and registered interpretation at one final block. Build the full recorded package and verify it from only the archive. A missing-field or missing-publisher selection should remain unsupported; selecting the actual complete statements should produce all four formats. The existing `local_independent_fixture --semantics` payload recipe is reusable, but its boundary deployment must not be presented as the current Core/Executor proof.

This capture remains future validation. No new capture, media retrieval, fixity verification, creator/publisher truth verification, finality or institutional acceptance is claimed by the adapter implementation.
