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

The smoke check currently proves compilation and test-command execution only.
Meaningful protocol tests are still roadmap work.

Non-gating diagnostics are useful for local review but are not merge gates until
their roadmap baselines are accepted:

```bash
make fmt-check
make slither
```

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
- [docs/status.md](docs/status.md)
- [docs/tooling.md](docs/tooling.md)
- [docs/known-blockers.md](docs/known-blockers.md)
- [ops/ROADMAP.md](ops/ROADMAP.md)
- [ops/AUTONOMOUS_RUN.md](ops/AUTONOMOUS_RUN.md)
