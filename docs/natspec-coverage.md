# NatSpec Coverage

This document describes the checked `CON-006` NatSpec coverage gate for the
release-relevant Solidity protocol surface. It is a pre-audit local baseline,
not production-ready, and not a claim that the current API documentation is
complete.

## Scope

The gate reads
[`release-artifacts/latest/protocol-surface-report.json`](../release-artifacts/latest/protocol-surface-report.json)
and checks the first-party release contract surface recorded there:

- public and external ABI functions;
- generated public variable getters that appear in the ABI;
- events;
- custom errors.

The checker scans the source files named by the protocol surface report and
requires nearby NatSpec in the Solidity source. A declaration is considered
documented only when it has a `///` NatSpec line or a `/** ... */` NatSpec block
immediately above it, allowing blank lines between the comment and declaration.

## Baseline

The current accepted-missing baseline lives at
[`release-artifacts/baselines/v0.1.0/natspec-coverage.json`](../release-artifacts/baselines/v0.1.0/natspec-coverage.json).

The baseline is intentional release debt. It exists so the repo can enforce the
rule "do not add more undocumented protocol surface" before the full NatSpec
burn-down is complete.

Current baseline summary:

| Status | Count | Meaning |
| --- | ---: | --- |
| `missing_natspec` | 309 | First-party function, event, or custom error declaration lacks nearby NatSpec |
| `public_variable_getter_missing_natspec` | 105 | Compiler-generated public getter lacks NatSpec on the state variable |
| `declaration_not_in_source` | 166 | ABI entry is inherited or otherwise not declared in the first-party source body |

The checker reports 47 documented release-surface entries and 580 explicit
exclusions in this baseline. That is not acceptable as a final documentation
standard; it is a machine-readable starting line for audit preparation.

## Policy

New or changed release-surface entries must satisfy one of these outcomes:

- add NatSpec directly above the Solidity declaration;
- keep the item outside the production release surface;
- update the baseline with a specific reason and follow-up.

Baseline updates are release-impacting documentation changes. They should be
reviewed like other accepted local-baseline risks because they can hide
integrator-facing ambiguity if used casually.

## Commands

Run the focused gate:

```sh
python scripts/test_natspec_coverage.py
python scripts/check_natspec_coverage.py
```

Refresh the current baseline after intentional NatSpec or release-surface
changes:

```sh
python scripts/check_natspec_coverage.py --write-baseline
```

The refresh command prints the total explicit exclusions, added exclusions,
removed exclusions, and per-status counts so reviewers can see whether the
change burns debt down or accepts new debt.

Then rerun:

```sh
python scripts/test_natspec_coverage.py
python scripts/check_natspec_coverage.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
```

The full local gate also runs NatSpec coverage:

```sh
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Audit Use

Auditors should treat the baseline as a review queue:

- `missing_natspec` rows are first-party declarations that need direct API
  documentation.
- `public_variable_getter_missing_natspec` rows should be documented at the
  variable declaration or converted to explicit view functions when semantics
  need richer docs.
- `declaration_not_in_source` rows should be reviewed to confirm they are
  inherited, generated, or intentionally outside first-party documentation
  scope.

The gate prevents silent drift; it does not replace manual review of whether
the NatSpec content is accurate, complete, or useful to integrators.
