# Production Release Evidence Templates

These files are checked, public-safe templates for the production-release
requirement rows in the shared release evidence status manifest at
`release-artifacts/latest/public-beta-evidence.json`. The path name is retained
for compatibility; the manifest currently tracks both public-beta and
production-release rows.

They are not completion evidence. Each JSON file uses
`record_type: "template"` and `review_status: "template"`, points at the
shared retained-artifact placeholder, and keeps production release blocked
until a future operator replaces the placeholder with reviewed no-secret
evidence.

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
