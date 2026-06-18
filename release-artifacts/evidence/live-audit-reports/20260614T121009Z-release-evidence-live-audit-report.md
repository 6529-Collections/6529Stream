# Release Evidence Live Audit Report

- Schema: `6529stream.release-evidence-live-audit-report.v1`
- Repository: `6529-Collections/6529Stream`
- Generated at: `20260614T121009Z`
- Readiness claim: `blocked`
- Snapshot freshness: `live_export_at_generation`
- Generated from live export: `true`
- Currentness claim: `current_at_generation_only`
- Stale snapshot policy: Retained reports are historical snapshots; reviewers must regenerate from live GitHub issue exports during the release ceremony before treating issue labels, bodies, or closure status as current.
- Notice: This report records no-secret live issue audit evidence only. It must not include private keys, RPC credentials, access tokens, unreleased signer material, or secret operational metadata.
- Warning: The report does not mark public-beta or production-release retained evidence complete and does not change the blocked readiness posture.

| Profile | Snapshot | Snapshot generated at | SHA-256 | Export status | Checker status |
| --- | --- | --- | --- | --- | --- |
| labels | release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json | 20260614T121009Z | 02aa4c986119766177a502c08573e2eb8db17506e4134d383d3f9069a28510b8 | passed | passed |
| bodies | release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json | 20260614T121009Z | fe13935da9e1c04aea6e5fa1f385c16a1c7050baa41e6713a024e92fe49ea859 | passed | passed |
| closure | release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json | 20260614T121009Z | 82697bd30f9f221062618f5b10a3aaf3ba46345ddc7b45c498959b57b702e263 | passed | passed |

## Command Provenance

### labels

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile labels --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json --gh gh
python scripts/check_release_evidence_issue_labels.py --live-json release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json
```

### bodies

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile bodies --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json --gh gh
python scripts/check_release_evidence_issue_bodies.py --live-json release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json
```

### closure

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile closure --repo 6529-Collections/6529Stream --limit 100 --output release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json --gh gh
python scripts/check_release_evidence_issue_closure.py --live-json release-artifacts/evidence/live-audit-reports/20260614T121009Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json
```
