# Public Beta Evidence Templates

These files are checked, public-safe templates for the public-beta requirement
rows in `release-artifacts/latest/public-beta-evidence.json`.

They are not completion evidence. Each JSON file uses
`record_type: "template"` and `review_status: "template"`. Most rows point at
the shared retained-artifact placeholder; rows with dedicated retained
artifact formats, such as `external_audit_report` and
`fork_deployment_rehearsal`, point at their requirement-specific Markdown
templates. Public beta remains blocked until a future operator replaces the
placeholder/template with reviewed no-secret evidence.

Before using a template for real evidence:

1. Copy the matching JSON shape for the requirement ID.
2. Replace the template-only environment, chain, command, reference, retained
   path, digest, owner, reviewer, and notes with reviewed public data.
3. Keep raw operator logs, credentials, private URLs, signing material, and
   unreleased drop payloads outside this repository.
4. Run `python scripts/check_non_local_release_evidence.py` on the evidence
   JSON and `python scripts/check_public_beta_evidence.py` after linking it
   from the public-beta evidence manifest.

For external audit report evidence, fill
`release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md`
and run `python scripts/check_external_audit_report_evidence.py` before
generating the non-local evidence envelope.

For testnet deployment rehearsal evidence, fill
`release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md`
and run `python scripts/check_testnet_deployment_rehearsal_evidence.py` before
generating the non-local evidence envelope.
