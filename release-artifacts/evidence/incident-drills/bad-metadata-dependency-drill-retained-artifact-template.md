# Bad Metadata Or Dependency Drill Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `bad_metadata_dependency_drill_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `template`
- Chain ID: `TBD`

## Drill Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Release commit: `TBD`
- Deployment version: `TBD`
- Drill bundle reference: `TBD`
- Incident class: `bad_metadata_dependency`
- Core contract: `TBD`
- Dependency registry: `TBD`
- Token ID: `TBD`
- Collection ID: `TBD`
- Metadata schema version: `TBD`
- Metadata surface: `TBD`
- Failure mode: `TBD`
- Collection frozen: `TBD`
- Starting metadata state: `TBD`
- Ending metadata state: `TBD`
- Dependency key: `TBD`
- Starting dependency version: `TBD`
- Ending dependency version: `TBD`
- Dependency content hash: `TBD`
- Freeze manifest hash: `TBD`

## Detection And Containment

- Metadata state snapshot evidence: `TBD`
- Token URI snapshot evidence: `TBD`
- URI policy evidence: `TBD`
- UTF-8 or raw-attributes evidence: `TBD`
- Dependency version/provenance evidence: `TBD`
- Freeze status evidence: `TBD`
- Metadata mutation pause evidence: `TBD`
- ERC-4906/cache invalidation evidence: `TBD`
- Browser sandbox evidence: `TBD`
- Marketplace/indexer communication evidence: `TBD`

## Recovery Sequence

- Recovery decision: `TBD`
- Corrected metadata evidence: `TBD`
- Corrected dependency/version evidence: `TBD`
- Dependency deprecation evidence: `TBD`
- Frozen collection decision evidence: `TBD`
- Post-recovery tokenURI evidence: `TBD`
- Post-recovery metadata state evidence: `TBD`
- Release artifact refresh evidence: `TBD`

## Monitoring And Handoff

- Operator dashboard confirmation: `TBD`
- Monitoring alert reference: `TBD`
- Incident response decision log: `TBD`
- Public communication status: `TBD`
- Follow-up issue links: `TBD`

## Required Retained Artifacts

- Command transcript bundle: `TBD`
- Event or state snapshot bundle: `TBD`
- Dependency operations evidence: `TBD`
- Metadata rendering evidence: `TBD`
- Browser/marketplace evidence: `TBD`
- Admin ceremony evidence: `TBD`
- Release manifest/checksum digests: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- Provider/API secrets removed: `TBD`
- Unreleased artist assets removed: `TBD`
- Unreleased token metadata removed: `TBD`
- Private dependency sources removed: `TBD`
- Private collector data removed: `TBD`

## Validation Commands

```sh
python scripts/test_bad_metadata_dependency_drill_evidence.py
python scripts/check_bad_metadata_dependency_drill_evidence.py
python scripts/test_incident_drill_evidence.py
python scripts/check_incident_drill_evidence.py
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- `Metadata surface` must be one of `token_uri`, `token_image`, `attributes`,
  `animation_html`, `collection_base_uri`, `collection_library`, `contract_uri`,
  `dependency_source`, `dependency_provenance`, `dependency_version`,
  `dependency_pin`, or `frozen_output`.
- `Failure mode` must match the selected metadata or dependency surface.
- `Collection frozen` must be `yes` or `no`. Frozen collections must not be
  repinned or mutated as recovery; reviewed evidence should document immutable
  proof, marketplace/indexer communication, or a reviewed redeploy/new
  collection decision.
- Dependency-related failures must retain dependency key, starting and ending
  version, content hash, provenance/source evidence, deprecation or fix-forward
  decision, and release manifest/checksum refresh evidence.
- Metadata-related failures must retain token URI and metadata-state snapshots,
  URI/UTF-8/raw-attribute or browser-sandbox evidence, ERC-4906 or equivalent
  cache-invalidation evidence, marketplace/indexer communication, and final
  post-recovery tokenURI evidence.
- This artifact is for public-safe retained evidence only. It must never include
  private keys, mnemonics, provider/API secrets, private RPC URLs, private
  dependency source bundles, unreleased artist assets, unreleased token
  metadata, unreleased drop authorization payloads, or private collector data.
