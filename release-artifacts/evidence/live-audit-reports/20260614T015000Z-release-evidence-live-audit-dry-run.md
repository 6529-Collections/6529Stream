# Release Evidence Live Audit Report

- Schema: `6529stream.release-evidence-live-audit-report.v1`
- Repository: `6529-Collections/6529Stream`
- Generated at: `20260614T015000Z-release-evidence-live-audit-dry-run`
- Readiness claim: `blocked`
- Notice: This report records no-secret live issue audit evidence only. It must not include private keys, RPC credentials, access tokens, unreleased signer material, or secret operational metadata.
- Warning: The report does not mark public-beta or production-release retained evidence complete and does not change the blocked readiness posture.

| Profile | Snapshot | SHA-256 | Export status | Checker status |
| --- | --- | --- | --- | --- |
| labels | release-artifacts/evidence/live-audit-report-template/release-evidence-issue-labels.json | d6fa3d89bc7ef4d0543cc8cf280c97363529099dc22ad98b7a15b049c1b251a8 | passed | passed |
| bodies | release-artifacts/evidence/live-audit-report-template/release-evidence-issue-bodies.json | 5073582267fa5478883188d8c12dfee803b1799869df0c7d8e96053a755ee9a4 | passed | passed |
| closure | release-artifacts/evidence/live-audit-report-template/release-evidence-issue-closure.json | e63187faddb39cb21b398d6016988c4c018438b84d84927b535763f38c824539 | passed | passed |

## Command Provenance

### labels

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile labels --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-report-template/release-evidence-issue-labels.json --gh gh
python scripts/check_release_evidence_issue_labels.py --live-json release-artifacts/evidence/live-audit-report-template/release-evidence-issue-labels.json
```

### bodies

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile bodies --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-report-template/release-evidence-issue-bodies.json --gh gh
python scripts/check_release_evidence_issue_bodies.py --live-json release-artifacts/evidence/live-audit-report-template/release-evidence-issue-bodies.json
```

### closure

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile closure --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-report-template/release-evidence-issue-closure.json --gh gh
python scripts/check_release_evidence_issue_closure.py --live-json release-artifacts/evidence/live-audit-report-template/release-evidence-issue-closure.json
```
