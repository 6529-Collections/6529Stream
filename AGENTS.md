# Agent Operating Guide

This file is for automated coding agents working in this repository. It is an
instruction surface, not a project overview. The README explains what
6529Stream is; this guide explains how an agent should make changes without
damaging release evidence, security posture, or reviewer trust.

## Mission And Boundaries

- Treat 6529Stream as a serious pre-audit smart-contract protocol that is not
  production-ready.
- Do not claim production readiness, public-beta readiness, audit completion,
  protocol correctness, or live deployment readiness unless the corresponding
  evidence is already merged.
- Prefer small PRs tied to one roadmap item, one tracker issue, or one tightly
  related bug.
- Make conservative changes that preserve protocol safety, release
  reproducibility, and integrator compatibility.
- Do not introduce Docker, Node, frontend tooling, generated scripts, or new
  dependencies unless the issue explicitly requires them.
- Never commit private keys, seed phrases, signer material, RPC credentials,
  WalletConnect secrets, API tokens, production deployment secrets, unredacted
  broadcasts, or private operational transcripts.

## Start Every Task

1. Read the user request and identify whether it is roadmap work, review
   feedback, a release-evidence task, a contract/test change, or documentation.
2. Check repository state before editing:

```bash
git status -sb
git branch --show-current
```

3. If the active checkout contains unrelated changes, use a clean branch or a
   separate worktree from `origin/main` rather than staging mixed local state.
4. Read the canonical planning files that match the task:
   - [ops/ROADMAP.md](ops/ROADMAP.md) for gates, maturity status, and
     long-form issue context.
   - [ops/EXECUTION_BACKLOG.md](ops/EXECUTION_BACKLOG.md) for PR-sized
     sequencing and readiness lanes.
   - [ops/AUTONOMOUS_RUN.md](ops/AUTONOMOUS_RUN.md) only when continuing the
     autonomous run or a maintainer asks for durable run-state updates.
   - [docs/status.md](docs/status.md), [docs/known-blockers.md](docs/known-blockers.md),
     and [docs/release-readiness.md](docs/release-readiness.md) before changing
     readiness language.
   - [docs/tooling.md](docs/tooling.md) before changing commands, CI, release
     artifacts, or checker behavior.
5. If a task touches security-sensitive behavior, read the relevant ADR under
   [docs/adr/](docs/adr/) before changing contracts or tests.

## Scope Discipline

- Keep the diff shaped like the request. Do not bundle opportunistic cleanup,
  formatting churn, release-artifact refreshes, or roadmap reconciliation unless
  they are required for the same change.
- Do not rewrite vendored OpenZeppelin-style files or legacy interfaces for
  style-only reasons. Follow [docs/vendored-libraries.md](docs/vendored-libraries.md)
  and the Solidity formatting policy in [docs/tooling.md](docs/tooling.md).
- Do not edit generated release artifacts by hand. Use the generator scripts and
  commit the deterministic outputs only when the changed inputs require it.
- Do not mark scaffold, template, or placeholder evidence as reviewed or
  complete.
- Do not close, resolve, or mark tracker issues complete unless the merged
  evidence satisfies the issue acceptance criteria.

## Solidity And Protocol Changes

- Preserve Solidity `0.8.19` and the existing Foundry project layout.
- Prefer explicit custom errors, events for externally important transitions,
  storage-backed replay protection, and `abi.encode` for structured hashing.
- Avoid `tx.origin`, ad hoc signatures, unchecked external calls, push-payment
  refunds, and ambiguous custody semantics.
- Check payment, auction, randomizer, admin, metadata, dependency, and release
  artifact effects before treating a contract change as local.
- Watch `StreamCore` bytecode size. New product or read surfaces should prefer
  satellite contracts, adapters, libraries, or release artifacts unless an
  accepted issue approves Core bytecode spend.
- Add focused Foundry tests for behavior changes. P0 or security-sensitive
  changes need happy-path, regression, negative, and event/assertion coverage
  where applicable.

## Documentation Changes

- Keep maturity language honest and consistent with [docs/status.md](docs/status.md),
  [docs/release-readiness.md](docs/release-readiness.md), public-beta blocker
  reports, and production blocker reports.
- Documentation for agents, contributors, auditors, integrators, and operators
  should be written for its specific audience. Do not replace one surface with
  pointers to another when the audiences need different instructions.
- When moving or renaming docs, update local links and any checker coverage in
  the same PR.
- Public docs that change setup, validation, integration behavior, release
  process, or maturity claims may need [CHANGELOG.md](CHANGELOG.md) and
  regenerated release notes, manifest, and checksum artifacts.

## Validation Ladder

Use the smallest honest validation set first, then broaden when risk increases.

For docs-only changes:

```bash
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
python scripts/check_changelog.py
```

If the root README or first-contributor path changes, also run:

```bash
python scripts/test_readme.py
python scripts/check_readme.py
python scripts/test_first_30_minutes.py
python scripts/check_first_30_minutes.py
```

For Solidity or Foundry tests, run the focused test first, then:

```bash
forge build
forge test -vvv
make check
```

On Windows, use the checked wrapper instead of reconstructing the Makefile by
hand:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

For release artifacts or evidence changes, follow the generator order in
[docs/tooling.md](docs/tooling.md). Regenerate upstream artifacts before
release notes, release manifest, bytecode proof, and checksum bundles.

## PR Workflow

- Branch from `origin/main` unless the user or active run state explicitly says
  to continue another branch.
- Use `codex/<short-description>` branch names.
- Stage only intended files. Do not use broad staging in a mixed worktree.
- Write a concise commit message describing the actual change.
- Fill the PR template with roadmap or non-roadmap rationale, validation
  commands, release impact, generated-artifact impact, security notes, and
  known limitations.
- Open a draft PR unless the user explicitly asks for a ready PR.
- Request CodeRabbit review with `@coderabbitai review` after opening. Do not
  request Claude review unless a user or maintainer explicitly asks for it.
- Treat bot comments as findings to verify. Apply actionable feedback, explain
  intentional non-changes, rerun relevant checks, and keep follow-up commits
  visible.
- Merge only after CI passes, actionable bot and human comments are resolved or
  explicitly accepted with rationale, and the final PR state matches the
  requested scope.

## Security Reports And Secrets

- Do not discuss exploitable vulnerabilities in public issues, PR bodies, or
  comments. Follow [SECURITY.md](SECURITY.md).
- Redact secrets before committing evidence. Redaction must remove values, not
  merely hide them in screenshots or logs.
- Treat local Anvil, fork, template, and example artifacts as no-secret
  material only after checking their contents for credential-shaped strings.

## When Unsure

- Prefer reading the local checker, generator, or ADR over guessing.
- Prefer a smaller PR with clear validation over a larger PR with mixed
  evidence.
- Prefer preserving existing release semantics unless an accepted issue or ADR
  authorizes a change.
- If instructions conflict, follow this order: explicit user request,
  repository security policy, accepted ADRs, release evidence gates, then local
  style conventions.
