# Slither reference

This is detailed maintainer reference. Start everyday work with the
[developer commands](../../tooling.md); run aggregate release validation only when
preparing the corresponding evidence. Commands below run from the repository root.

## Slither Gates And Raw Diagnostics

The default `make check` path includes the fast
`slither-baseline-metadata-check`. It runs the checker tests plus
`tools/security/check_slither_baseline.py --baseline-only`, validating the normalized
baseline and dispositions without launching Slither. The dedicated Ubuntu CI
job runs `make slither-baseline-check` with the pinned Foundry and Python
toolchain. That target invokes `tools/security/check_slither_baseline.py --run-slither`
and fails when the live normalized first-party High/Medium set adds a new row or
leaves a tracked row stale.

The current checked baseline retains 44 findings: 4 High and 40 Medium.
Thirty remain Open and 14 have reviewed, detector-specific False Positive
dispositions. The compact normalized JSON lives at
[`ops/SLITHER_BASELINE.json`](../../../ops/SLITHER_BASELINE.json), with source-traced
rationales and focused regression references in
[`ops/SLITHER_BASELINE.md`](../../../ops/SLITHER_BASELINE.md).

The live gate uses Crytic Compile's production-only Foundry mode: every
`smart-contracts/**/*.sol` input is compiled, while `test/` and `script/`
constructor closures are excluded. It omits `--foundry-compile-all` and retains
the exact first-party High/Medium comparison. The current unfiltered
production capture contains 784 results (5 High, 49 Medium, 102 Low,
620 Informational, 8 Optimization), including all 143 production source files.
High/Medium scope totals are production `4/40/44`, vendored `1/9/10`, and zero
for excluded test/script scopes and other sources. Exact source commit,
capture time, tool versions, and raw digest remain in the canonical baseline.
Raw Slither JSON is temporary analyzer output and is never committed.
After a production-source edit intentionally stales the strict provenance hash,
use the diagnostic `--candidate-slither-json` plus `--candidate-output` mode to
materialize semantic identities and scope counts in an OS temporary directory
or ignored `cache/`. Candidate output has no triage or
proof fields, cannot overwrite the canonical JSON/Markdown pair, is never
release evidence, and must not be committed. After reviewed JSON/provenance
updates, regenerate the mirror with `--render-markdown` before rerunning both
gates.

`make slither` remains the raw diagnostic:

```bash
slither . --config-file slither.config.json --foundry-compile-all
```

It can exit non-zero while baseline findings remain open. Likewise,
`forge fmt --check smart-contracts` is a raw formatting diagnostic because it
still prints the vendored/provenance exemption diff; the scoped
`make fmt-check` gate is part of `make check` and CI. Passing either Slither
baseline gate proves consistency with the committed checked inventory only. It
does not prove the findings harmless, complete an external audit, or promote
public-beta or production readiness. See [`docs/slither.md`](../../slither.md) for the
full workflow.
