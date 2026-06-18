# Release Evidence Live Audit Report

- Schema: `6529stream.release-evidence-live-audit-report.v1`
- Repository: `6529-Collections/6529Stream`
- Generated at: `20260618T200458Z`
- Readiness claim: `blocked`
- Snapshot freshness: `live_export_at_generation`
- Generated from live export: `true`
- Currentness claim: `current_at_generation_only`
- Stale snapshot policy: Retained reports are historical snapshots; reviewers must regenerate from live GitHub issue exports during the release ceremony before treating issue labels, bodies, or closure status as current.
- Notice: This report records no-secret live issue audit evidence only. It must not include private keys, RPC credentials, access tokens, unreleased signer material, or secret operational metadata.
- Warning: The report does not mark public-beta or production-release retained evidence complete and does not change the blocked readiness posture.

| Profile | Snapshot | Snapshot generated at | SHA-256 | Export status | Checker status |
| --- | --- | --- | --- | --- | --- |
| labels | release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json | 20260618T200458Z | a6e179b1685013ea86bfe76d3ed9fb6239d6e417c932b80910434b3ec7848959 | passed | passed |
| bodies | release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json | 20260618T200458Z | d1a15f9b65566b801cac41a8dad8082cfef93a1d8d41c858eed60390f4c6ff8e | passed | passed |
| closure | release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json | 20260618T200458Z | 774696d4197aa99b741bdd486a96d1f0ff761f1f529a57b2bdb357a05bf39099 | passed | passed |

## Command Provenance

### labels

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile labels --repo 6529-Collections/6529Stream --output release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json --gh gh --exact-linked-issues --issue-links release-artifacts/latest/release-evidence-issue-links.json
python scripts/check_release_evidence_issue_labels.py --live-json release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-labels.json
```

### bodies

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile bodies --repo 6529-Collections/6529Stream --output release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json --gh gh --exact-linked-issues --issue-links release-artifacts/latest/release-evidence-issue-links.json
python scripts/check_release_evidence_issue_bodies.py --live-json release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-bodies.json
```

### closure

```bash
python scripts/export_release_evidence_issue_snapshot.py --profile closure --repo 6529-Collections/6529Stream --output release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json --gh gh --exact-linked-issues --issue-links release-artifacts/latest/release-evidence-issue-links.json
python scripts/check_release_evidence_issue_closure.py --live-json release-artifacts/evidence/live-audit-reports/20260618T200458Z-release-evidence-live-audit-report-snapshots/release-evidence-issue-closure.json
```
