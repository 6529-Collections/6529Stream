# External Audit Finding Workflow

This is the public-safe workflow for receiving, triaging, remediating,
retesting, risk-accepting, and closing external audit findings for 6529Stream.
It is a pre-audit local baseline, not a completed audit report, and not a
production-readiness claim.

Use private reporting through [`SECURITY.md`](../SECURITY.md) for exploitable
or embargoed findings. Use the checked
[audit finding issue form](../.github/ISSUE_TEMPLATE/audit_finding.yml) only
after the finding is safe for public tracking or sensitive details have been
withheld.

## Intake Channels

- Private security contact: [`SECURITY.md`](../SECURITY.md).
- Public-safe audit issue form:
  [`.github/ISSUE_TEMPLATE/audit_finding.yml`](../.github/ISSUE_TEMPLATE/audit_finding.yml).
- Audit package entrypoint: [`docs/audit-package.md`](audit-package.md).
- Release readiness dashboard: [`docs/release-readiness.md`](release-readiness.md).
- Non-local evidence runbook:
  [`docs/non-local-release-evidence.md`](non-local-release-evidence.md).

Every finding must have a stable finding ID before remediation work begins.
Preferred IDs use the auditor's ID when available, such as `AUD-2026-001`; if
the auditor has not assigned one yet, use a temporary `TMP-AUD-###` ID and
rename it once the final report lands.

## Finding Record

Each finding record must capture these public-safe fields:

- Finding ID: stable auditor ID or temporary `TMP-AUD-###`.
- Severity: Critical, High, Medium, Low, Informational, or Undetermined.
- Finding status: New finding, Remediation planned, Remediation in progress,
  Ready for retest, Retest passed, Accepted risk proposed, Accepted risk
  approved, or Duplicate or out of scope.
- Affected component: contract, function, script, deployment artifact, release
  evidence, docs path, or operational process.
- Audited commit and audit scope: commit SHA, branch or tag, scoped contracts,
  scripts, docs, deployment artifacts, evidence rows, and excluded surfaces.
- Finding summary: public-safe summary that does not disclose active exploit
  instructions.
- Threat model and exploit preconditions: actor, permissions, chain state,
  timing, signatures, custody, payment, randomness, metadata, governance, or
  deployment assumptions.
- Impact: funds, custody, authorization, replay, randomness, metadata,
  governance, release integrity, or availability impact.
- Owner and reviewer: named remediation owner and independent reviewer.
- Disclosure posture: private, embargoed public placeholder, public-safe, or
  released in final report.

The checked audit finding issue form is the canonical GitHub intake surface.
Its `severity`, `status`, `affected_component`, `finding_summary`,
`threat_model`, `impact`, `remediation`, `required_tests`, `references`, and
closure check fields must remain aligned with this workflow.

## Triage

Triage is complete only when all of these are true:

- The finding ID, severity, affected component, and audited commit are known.
- The finding is either safe for public tracking or routed privately through
  `SECURITY.md`.
- The maintainer has chosen one path: remediation, accepted risk, duplicate, or
  out of scope.
- Critical and high findings have an owner, reviewer, target PR, and release
  blocker impact before any public beta or production-release claim.
- Medium findings have either a remediation PR, accepted-risk issue, or explicit
  release-gate waiver before release.
- Low and informational findings have a disposition that is visible in release
  notes, the risk register, or the post-audit remediation evidence when relevant.

Do not close a finding at triage time unless it is demonstrably duplicate or out
of scope and the reviewer records the reason.

## Remediation Path

Remediation PRs must be traceable from finding to fix:

- Link the finding issue in the PR body.
- Name the roadmap item or audit finding ID in the PR title or body.
- Describe the vulnerable behavior, intended behavior, and external behavior
  impact without publishing embargoed exploit instructions.
- Add or update a direct regression test for the finding.
- Add a negative test for the exploit precondition where feasible.
- Add invariant, fork, deployment rehearsal, or retained evidence coverage when
  the finding concerns value flow, authorization, randomness, metadata,
  deployment, or release artifacts.
- Update docs when external behavior, operator procedure, release evidence, or
  accepted risk changes.
- Update [`CHANGELOG.md`](../CHANGELOG.md) under `## Unreleased`.

Required local validation for a remediation PR:

```sh
make check
python scripts/test_audit_finding_workflow.py
python scripts/check_audit_finding_workflow.py
python scripts/check_audit_package.py
python scripts/check_release_readiness.py
python scripts/check_changelog.py
```

Windows validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Retest And Closure

A fixed finding can move to `Ready for retest` only after the remediation PR is
merged and the validation commands above are recorded. A finding can move to
`Retest passed` only when reviewer or auditor retest evidence is retained or
linked.

Closure requires:

- Finding issue linked to remediation PRs or accepted-risk decision.
- Regression tests or explicit accepted-risk rationale recorded.
- Retest evidence, reviewer signoff, or auditor final-report reference linked.
- Release notes, risk register, and post-audit remediation evidence impact
  considered.
- No private keys, RPC credentials, signer material, auditor portal tokens, or
  unreleased drop payloads retained in public artifacts.
- The post-audit remediation evidence row remains blocked until reviewed
  retained evidence replaces template-only evidence.

Before closing release-evidence tracker issues, run:

```sh
python scripts/check_release_evidence_issue_closure.py
```

## Accepted Risk

Accepted risk is allowed only when remediation is intentionally deferred or
rejected and the decision is explicit.

An accepted-risk record must include:

- Finding ID and severity.
- Reason remediation is not being shipped now.
- Impact and affected users or operators.
- Compensating controls, monitoring, pause options, or release blockers.
- Owner, reviewer, approver, expiry or revisit condition, and linked issue.
- Release impact: public beta blocked, production blocked, waived with expiry,
  or no release impact.

Accepted risk does not close a public-beta or production-release blocker unless
the relevant launch gate explicitly allows that risk and the decision is
referenced from the release evidence manifest.

## Evidence Handoff

External audit findings connect to release evidence in two places:

- External audit report retained artifact:
  [`release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md`](../release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md).
- Post-audit remediation retained artifact:
  [`release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md`](../release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md).

When the audit report is final, the external audit report evidence should
record scope, audited commit, report reference, finding IDs, remediation links,
accepted-risk references, retest status, reviewer approval, and redaction.

When remediation is complete, the post-audit remediation evidence should record
finding-by-finding status, fix PRs or commits, regression tests, retest
evidence, accepted-risk records, release notes mapping, remaining exceptions,
reviewer decision, and no-secret redaction.

Template-only evidence cannot complete either row.

## Required Updates

Each accepted audit finding must be considered against:

- [`docs/audit-package.md`](audit-package.md) for auditor-facing scope and
  review entry points.
- [`docs/release-readiness.md`](release-readiness.md) for public-beta and
  production blocker state.
- [`docs/non-local-release-evidence.md`](non-local-release-evidence.md) for
  retained evidence shape and no-secret rules.
- [`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json)
  for launch risk impact.
- [`release-artifacts/latest/release-notes.md`](../release-artifacts/latest/release-notes.md)
  and [`CHANGELOG.md`](../CHANGELOG.md) for release-facing disclosure.
- [`ops/EXECUTION_BACKLOG.md`](../ops/EXECUTION_BACKLOG.md) when a finding
  becomes roadmap work.

## Validation Commands

Run these commands after editing this workflow:

```sh
python scripts/test_audit_finding_workflow.py
python scripts/check_audit_finding_workflow.py
python scripts/test_issue_templates.py
python scripts/check_issue_templates.py
python scripts/test_audit_package.py
python scripts/check_audit_package.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
```

## Non-Goals

- Do not publish embargoed exploit details in public issues or docs.
- Do not claim an external audit is complete until final reviewed evidence is
  retained.
- Do not close public-beta or production-release blockers from template-only
  evidence.
- Do not commit private keys, mnemonics, RPC URLs, signer material, auditor
  portal credentials, API keys, or unreleased drop payloads.
