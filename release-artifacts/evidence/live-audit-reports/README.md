# Live Audit Report Archive

This directory is the canonical retention location for future no-secret live
audit report bundles generated during release evidence reviews.

Each retained bundle must be a paired JSON/Markdown report:

- `release-artifacts/evidence/live-audit-reports/<archive-id>.json`
- `release-artifacts/evidence/live-audit-reports/<archive-id>.md`

Use a stable lowercase archive ID that starts with the UTC run label, for
example `20260614T010000Z-release-evidence-live-audit-report`. Pass the same
label to the report generator with `--generated-at` so reviewers can match the
archive row to the retained run.

Retained reports must contain no secrets, tokens, private issue exports, or
unredacted operator credentials. They are review evidence only: a valid archive
row does not make any public-beta or production-release readiness claim true by
itself.

## Workflow

Generate a retained report pair:

```sh
python scripts/audit_release_evidence_issue_snapshots.py --generated-at YYYYMMDDTHHMMSSZ --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
```

Validate the JSON schema/checker and Markdown parity:

```sh
python scripts/check_release_evidence_live_audit_report.py --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json
python scripts/check_release_evidence_live_audit_markdown.py --report-json release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md release-artifacts/evidence/live-audit-reports/YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md
```

Refresh and check the generated archive index:

```sh
python scripts/generate_release_evidence_live_audit_archive.py --archive-dir release-artifacts/evidence/live-audit-reports
python scripts/generate_release_evidence_live_audit_archive.py --archive-dir release-artifacts/evidence/live-audit-reports --check
```

