# Contributing

Thanks for helping make 6529Stream safer and easier to review. This repository
is pre-audit, so the contribution process favors small PRs, explicit evidence,
and honest maturity labels over speed.

## Ground Rules

- Work from [ops/ROADMAP.md](ops/ROADMAP.md) unless a maintainer directs
  otherwise.
- Keep PRs focused on one roadmap item or one tightly related bug.
- Do not claim production readiness, audit completion, or protocol correctness
  unless the relevant launch gate evidence is merged.
- Do not report exploitable security issues in public issues or PRs. Follow
  [SECURITY.md](SECURITY.md).
- Never commit private keys, seed phrases, RPC credentials, signer material, or
  production deployment secrets.

## Local Setup

For a fresh checkout, start with the checked
[first-30-minutes guide](docs/first-30-minutes.md). It covers prerequisites,
`forge` not being on `PATH`, Windows wrapper usage, known warning noise,
generated artifact drift, docs-only paths, Solidity/test paths, no-secret
boundaries, and the commands below.

Install or bootstrap the pinned toolchain:

```bash
bash scripts/bootstrap-ec2.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1
```

Run the canonical smoke check before opening a PR:

```bash
make check
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

The canonical check proves compilation, executes the protocol test suite, and
validates the fast Slither baseline metadata gate plus repository evidence and
policy gates. For Solidity changes, also run the complete live comparison when
the pinned Slither toolchain is available:

```bash
make fmt-check
make slither-baseline-check
```

The raw analyzer command remains useful for investigation:

```bash
make slither
```

The live baseline currently contains 3 High and 30 Medium first-party findings,
so raw Slither can exit non-zero. The baseline gates detect unreviewed drift;
they do not establish audit completion or public-beta/production readiness.
The Governance Executor's proposal-selected native-value authority is also
tracked separately as High open blocker `RISK-GOV-003`: bounded assembly made
that behavior invisible to Slither without removing the underlying authority.

## Pull Request Expectations

Every PR should include:

- Roadmap gate or issue ID.
- Problem statement and intended behavior.
- Files changed and why the scope is intentionally limited.
- Local commands run, including command output summary.
- CI status once available.
- Security impact notes, especially for authorization, payments, custody,
  randomness, admin controls, deployment, and metadata.
- Docs updates when external behavior, setup, or maturity status changes.
- Known limitations and follow-up issues.

For contract behavior changes, include tests or explain why the PR is a
characterization, documentation, or scaffolding-only step. P0 behavior changes
should include at least a happy path, direct regression test, negative test,
event assertion where relevant, and documentation update.

## Review And Bot Workflow

- Resolve all actionable CodeRabbit, Claude, CI, and human review comments
  before merge.
- If a bot does not run automatically, maintainers may request review by
  commenting on the PR.
- Treat bot comments as findings to verify, not commands to apply blindly.
- Prefer a follow-up commit with validation notes over force-pushing away review
  history.

## Issue Quality

Roadmap issues should be implementation-ready. Use the issue forms and include:

- Problem.
- Current behavior.
- Intended behavior.
- Required code changes.
- Required tests.
- Required docs.
- Acceptance criteria.
- Dependencies and blocking ADRs.

If the issue touches a protocol decision, create or reference the corresponding
ADR before implementation begins.

Use the specialized checked issue forms when they fit:

- [integration report](.github/ISSUE_TEMPLATE/integration_report.yml) for
  frontend, mobile, Electron, indexer, wallet, operator UI, marketplace, or
  signing-service integration work.
- [audit finding](.github/ISSUE_TEMPLATE/audit_finding.yml) for public-safe
  external audit finding, remediation, retest, or accepted-risk tracking.
- [release evidence](.github/ISSUE_TEMPLATE/release_evidence.yml) for
  public-beta, production-release, retained-artifact, blocker, or evidence
  review work.

Do not use public issue forms for exploitable vulnerability reports; follow
[SECURITY.md](SECURITY.md).

Pull requests should use the checked
[PR template](.github/PULL_REQUEST_TEMPLATE.md). Keep the roadmap/gate linkage,
validation evidence, release-impact classification, generated-artifact impact,
and breaking-change approval fields complete. The template is validated by
`python scripts/check_pr_template.py`, so changes to release-impact intake must
update the checker and tests in the same PR.

Local Markdown links and heading anchors in the contributor, docs, ops, GitHub
template, and release-artifact surfaces are validated by
`python scripts/check_markdown_links.py`. Update links, anchors, checker
coverage, and release artifacts together when moving or renaming docs.

## Style

- Solidity compiler target is `0.8.19` until the roadmap changes it.
- Keep changes conservative and local to the roadmap item.
- Prefer explicit custom errors, events for external state transitions, and
  storage-backed replay protection for authorization work.
- Use `abi.encode` for structured hash leaves and signed payloads unless an ADR
  explicitly approves a different encoding.
- Keep generated artifacts out of git unless a release process explicitly
  requires checksummed artifacts.

## Documentation

Update docs in the same PR when behavior changes. At minimum, check whether the
change affects:

- [README.md](README.md)
- [docs/first-30-minutes.md](docs/first-30-minutes.md)
- [docs/status.md](docs/status.md)
- [docs/tooling.md](docs/tooling.md)
- [docs/known-blockers.md](docs/known-blockers.md)
- [.github/ISSUE_TEMPLATE/integration_report.yml](.github/ISSUE_TEMPLATE/integration_report.yml)
- [.github/ISSUE_TEMPLATE/audit_finding.yml](.github/ISSUE_TEMPLATE/audit_finding.yml)
- [.github/ISSUE_TEMPLATE/release_evidence.yml](.github/ISSUE_TEMPLATE/release_evidence.yml)
- [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md)
- [ops/ROADMAP.md](ops/ROADMAP.md)
- [ops/AUTONOMOUS_RUN.md](ops/AUTONOMOUS_RUN.md)
