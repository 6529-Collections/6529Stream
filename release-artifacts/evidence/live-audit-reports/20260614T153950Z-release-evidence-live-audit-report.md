# Release Evidence Live Audit Report

- Schema: `6529stream.release-evidence-live-audit-report.v1`
- Repository: `6529-Collections/6529Stream`
- Generated at: `20260614T153950Z`
- Readiness claim: `blocked`
- Snapshot freshness: `live_export_at_generation`
- Generated from live export: `true`
- Currentness claim: `current_at_generation_only`
- Stale snapshot policy: Retained reports are historical snapshots; reviewers must regenerate from live GitHub issue exports during the release ceremony before treating issue labels, bodies, or closure status as current.
- Notice: This report records no-secret live issue audit evidence only. It must not include private keys, RPC credentials, access tokens, unreleased signer material, or secret operational metadata.
- Warning: The report does not mark public-beta or production-release retained evidence complete and does not change the blocked readiness posture.

| Profile | Snapshot | Snapshot generated at | SHA-256 | Export status | Checker status |
| --- | --- | --- | --- | --- | --- |
| labels | release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json | 20260614T153950Z | f54c0a6e641646b3446a4a68157eea4d9afcb4409937a4e476b91282dab0a0bb | passed | passed |
| bodies | release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json | 20260614T153950Z | 86a27ca5c51e22656f313c5e579c7ddcd71d2eecafbdb907c1cda3d31c4ffdb5 | passed | passed |
| closure | release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json | 20260614T153950Z | 1fe388d46175b648d88bc3eaeaae06c9b42335f9b02f01d2c1352db3d3cee6ac | passed | passed |

## Command Provenance

### labels

```bash
'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe' 'D:\repos\6529Stream-pr-ci-hardening\scripts\export_release_evidence_issue_snapshot.py' --profile labels --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json --gh gh
'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe' 'D:\repos\6529Stream-pr-ci-hardening\scripts\check_release_evidence_issue_labels.py' --live-json release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json
```

### bodies

```bash
'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe' 'D:\repos\6529Stream-pr-ci-hardening\scripts\export_release_evidence_issue_snapshot.py' --profile bodies --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json --gh gh
'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe' 'D:\repos\6529Stream-pr-ci-hardening\scripts\check_release_evidence_issue_bodies.py' --live-json release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json
```

### closure

```bash
'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe' 'D:\repos\6529Stream-pr-ci-hardening\scripts\export_release_evidence_issue_snapshot.py' --profile closure --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json --gh gh
'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe' 'D:\repos\6529Stream-pr-ci-hardening\scripts\check_release_evidence_issue_closure.py' --live-json release-artifacts/evidence/live-audit-reports/20260614T153950Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json
```
