# Production Release Evidence Templates

These files are checked, public-safe templates for the production-release
requirement rows in the shared release evidence status manifest at
`release-artifacts/latest/public-beta-evidence.json`. The path name is retained
for compatibility; the manifest currently tracks both public-beta and
production-release rows.

They are not completion evidence. Each JSON file uses
`record_type: "template"` and `review_status: "template"`, points at the
shared retained-artifact placeholder or a requirement-specific retained
artifact template, and keeps production release blocked until a future operator
replaces the placeholder with reviewed no-secret evidence.

Before using a template for real evidence:

1. Copy the matching JSON shape for the production requirement ID.
2. Replace the template-only environment, chain, command, reference, retained
   path, digest, owner, reviewer, and notes with reviewed public data.
3. Keep raw operator logs, credentials, private URLs, signing material, and
   unreleased drop payloads outside this repository.
4. Run `python scripts/check_non_local_release_evidence.py` on the evidence
   JSON and `python scripts/check_public_beta_evidence.py` after linking it
   from the shared release evidence status manifest.

For live marketplace/indexer evidence, fill
`release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-retained-artifact-template.md`
and run `python scripts/check_marketplace_indexer_evidence.py` before
generating the non-local evidence envelope for
`live_marketplace_indexer_evidence`.

For production broadcast retention evidence, fill
`release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md`
and run `python scripts/test_production_broadcast_retention.py` plus
`python scripts/check_production_broadcast_retention.py` before generating the
non-local evidence envelope for `production_broadcast_retention`.

For live deployment manifest evidence, fill
`release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-retained-artifact-template.md`
and run `python scripts/test_live_deployment_manifest_evidence.py` plus
`python scripts/check_live_deployment_manifest_evidence.py` before generating
the non-local evidence envelope for `live_deployment_manifest`.

For production address-book and live explorer verification evidence, fill
`release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md`
and run `python scripts/test_production_verified_addresses.py` plus
`python scripts/check_production_verified_addresses.py` before generating
separate non-local evidence envelopes for `production_address_books` and
`live_explorer_verification`.

For production checksum signatures and signed Git tag evidence, fill
`release-artifacts/evidence/production-release-signing/production-release-signing-retained-artifact-template.md`
and run `python scripts/test_production_release_signing_evidence.py` plus
`python scripts/check_production_release_signing_evidence.py` before generating
separate non-local evidence envelopes for `production_signatures` and
`signed_git_tag`. The dedicated retained artifact checker validates reviewed
no-secret file references and hands off detached signature schema validation to
`scripts/check_release_signatures.py` and strict release tag trust to
`scripts/check_signed_release_tag.py --mode release`.

For live metadata browser evidence, fill
`release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md`
and run `python scripts/test_live_metadata_browser_evidence.py` plus
`python scripts/check_live_metadata_browser_evidence.py` before generating the
non-local evidence envelope for `live_metadata_browser_evidence`.
