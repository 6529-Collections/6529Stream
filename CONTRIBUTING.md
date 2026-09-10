# Contributing

Start with [setup and your first run](docs/first-30-minutes.md), then follow the
[current-stack walkthrough](docs/current-stack.md). Stream is pre-audit and not
production-ready. This guide explains development and review, not release approval.

## Find the right implementation

Use the [source map](smart-contracts/README.md) and
[interface map](smart-contracts/interfaces/stream/README.md). Keep implementations
in their domain and depend on the smallest useful caller interface. Shared
structs have explicit type homes; the aggregate interfaces retain compatibility.

The current Core lives in `smart-contracts/core/`. Historical Core behavior is
kept in test helpers for regression coverage. Test the real current stack when
a change affects a boundary between modules. The [test guide](test/README.md)
explains integration, domain, legacy, and gas suites.

## Work on a change

1. Check `git status -sb`. Use a branch or worktree that does not mix unrelated work.
2. Identify the intended behavior, relevant issue, and owning interface/domain.
3. Implement a coherent change and run its focused behavioral tests.
4. Run `python scripts/dev.py check` for the current stack and the affected
   domain suite. For prose changes, use `python scripts/dev.py docs`.
5. Update caller documentation and the changelog when behavior, setup, or
   supported scope changes. Hand off a reviewable diff with exact validation results.

Independent domain changes can proceed in parallel. Agree ownership before
editing shared files, integrate real flows frequently, and run the broad release
pass once the combined implementation stabilizes. Do not rebuild all evidence
for every small intermediate commit.

## Solidity conventions

- Preserve Solidity 0.8.19 and the reviewed compiler profiles.
- Document external behavior, units, authority, failure conditions, and returned
  values with NatSpec. An interface name alone is not documentation.
- Keep authorization and replay checks explicit. Prefer custom errors, events
  for external state changes, `abi.encode` for structured commitments, and
  storage-backed nonce consumption.
- Treat payment, receiver callbacks, entropy callbacks, and cross-contract
  rollback as behavior to test. Small interfaces do not replace runtime access control.
- Keep ownership, supply, and permanent token identity in Core. Put product
  extensions in satellites unless the invariant needs a Core change; see
  [Core size policy](docs/architecture.md#product-extension-and-size-budget-policy).
- Preserve public selectors, tuple layouts, event topics, error signatures, and
  ERC-165 IDs during organizational changes. Review an intentional API change
  separately from a file move.
- Run the scoped formatting check. Retained dependencies under `vendor/` have
  [provenance rules](docs/vendored-libraries.md); do not restyle upstream code.

## Documentation and evidence

Keep executable current guides separate from [legacy reference](docs/reference/legacy-stack/README.md)
and [normative specifications](docs/spec-policy.md). A planned interface or
specification is not an installed feature. Link to source and meaningful tests,
and state when an example uses a development provider or placeholder address.

Read and write text as UTF-8. Fix links when files move. Keep generated outputs
generated: use their documented tools, and let one owner perform the ordered
artifact refresh. Historical deployment compiler snapshots retain the exact
source paths and bytes used for those deployments.

`python scripts/dev.py release` invokes the full checked validation workflow.
Use it for a stabilized release candidate, not as the default edit/test loop.
See [release artifacts](docs/reference/tooling/release-artifacts.md) and
[release policy](docs/release-policy.md) for the authoritative generator order.

## Pull requests and review

Use `codex/` branches for automated work. Fill the [PR template](.github/PULL_REQUEST_TEMPLATE.md)
with the concrete problem, resulting behavior, issue/scope, validation, and any
release impact. Open a draft while work is incomplete. Request CodeRabbit review
with `@coderabbitai review`; inspect its findings against the actual source.
Do not mistake a skipped or rate-limited review for completed review.

Merge after required CI passes, actionable findings are fixed or explicitly
accepted with evidence, and the final diff matches its description. Report
tests that were not run and environmental blockers accurately. Use the
[issue forms](.github/ISSUE_TEMPLATE/) for implementation and integration work.
Do not close a broader parent issue because one implementation slice shipped.

## Security and maturity

Never commit private keys, seed phrases, RPC credentials, signing secrets,
or unredacted private broadcasts. Report exploitable vulnerabilities through
[SECURITY.md](SECURITY.md), not public issues or PR comments.

Tests and development deployments do not prove protocol correctness or audit
completion. [Release readiness](docs/release-readiness.md) retains the audit,
signing, custody, deployment-verification, and external operational requirements;
the [backlog](ops/EXECUTION_BACKLOG.md) tracks unsupported full-v1 work.
