# Slither Baseline

6529Stream pins its Slither toolchain and tracks a normalized first-party
high/medium baseline. The current baseline contains 30 open findings: 3 High
and 27 Medium. Those rows are a review and burn-down queue; they are not proof
of exploitability, an audit completion claim, or evidence that the protocol is
ready for public beta or production.

Slither is a direct pin in `requirements-tools.txt` and is transitively
hash-locked for the Linux CI/release boundary through
`requirements-tools.lock`.

## Versions

| Tool | Version |
| --- | --- |
| Foundry | `v1.7.1` |
| Solidity compiler | `0.8.19` |
| Slither | `0.11.5` |
| Crytic Compile | `0.3.11` |
| solc-select | `1.2.0` |

## Current Capture

The canonical unfiltered capture was produced at source commit
`55a2e817876eac754355a14ae3907053e3d3deed` on
`2026-07-24T04:58:03Z`. It contains 3,017 findings across all impacts and
scopes: 47 High, 728 Medium, 1,212 Low, 990 Informational, and 40
Optimization. The High/Medium scope split is:

| Scope | High | Medium | Total |
| --- | ---: | ---: | ---: |
| First-party production | 3 | 27 | 30 |
| Vendored | 1 | 9 | 10 |
| Test | 43 | 685 | 728 |
| Script | 0 | 7 | 7 |
| Other | 0 | 0 | 0 |

All 30 retained first-party High/Medium fingerprints are unchanged from the
prior canonical baseline, and the refresh added no row. Exactly three Medium
`incorrect-equality` rows disappeared because ADR 0017 retired
`StreamCadenceProbe`; source retirement is not finding acceptance or a claim
that the removed probe behavior was remediated.

Bounded assembly prevents `StreamGovernanceExecutor` governed-call returndata
bombs, but makes its proposal-selected native-value authority invisible to
Slither's `arbitrary-send-eth` detector. The row's disappearance is not a
remediation or acceptance: High open blocker `RISK-GOV-003` preserves the
semantic risk until closed-world target/selector/value policy, deployment
binding, adversarial value-flow tests, and independent review are complete
under issues #658 and #685.

The reproducible Linux CI/release path installs the hashed lock before selecting
the compiler:

```bash
python -m pip install --disable-pip-version-check --require-hashes --only-binary=:all: -r requirements-tools.lock
python -m pip check
solc-select install 0.8.19
solc-select use 0.8.19
```

The EC2 and Windows bootstrap scripts perform the equivalent setup for their
supported contributor environments from the readable direct requirements;
those heterogeneous convenience paths are not release evidence.

The baseline records the analyzed source commit and raw capture identity
separately from the current live-gate configuration. The
`requirements-tools.txt` hash therefore identifies the current reproducible
gate toolchain; it does not claim that those direct pins existed at the older
analyzed commit.

## Fast Default Gate

The default `make check` includes:

```bash
make slither-baseline-metadata-check
```

The Bash and PowerShell check wrappers run the same two commands directly. The
target runs the checker tests and then
`scripts/check_slither_baseline.py --baseline-only`. It validates the tracked
normalized baseline, provenance, counts, and disposition metadata without
launching Slither. Keeping this path analyzer-free makes the ordinary aggregate
check fast and deterministic.

## Live CI Gate

Run the complete source-to-baseline comparison with:

```bash
make slither-baseline-check
```

The complete target first runs the fast metadata gate, then invokes
`scripts/check_slither_baseline.py --run-slither` with the pinned toolchain and
compares the normalized first-party High and Medium rows with the tracked
baseline. New rows and stale rows fail the check. CI runs this target in a
dedicated Ubuntu job with a 45-minute timeout so live analyzer cost does not
make the default wrappers slow.

The canonical machine-readable baseline is
[`ops/SLITHER_BASELINE.json`](../ops/SLITHER_BASELINE.json). The reviewer-facing
classification and open-proof appendix is
[`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md). Both are checked
inventory, but neither replaces source review, focused tests, or an independent
security audit.

## Raw Diagnostic

The existing raw command remains available:

```bash
make slither
```

It runs:

```bash
slither . --config-file slither.config.json --foundry-compile-all
```

This unfiltered diagnostic can exit non-zero while tracked baseline findings
remain open. Use `make slither-baseline-check` for the fail-on-drift contract.

Raw JSON is useful while investigating or intentionally refreshing the
normalized baseline:

```bash
slither . --config-file slither.config.json --foundry-compile-all --json /tmp/slither-report.json
```

Raw Slither JSON can be large, is temporary working data, and must never be
committed; only the compact normalized baseline and reviewer-facing Markdown
inventory belong in the repository. On Windows, write the temporary report
outside the repository or to an ignored local path.

## Baseline Review Process

When source changes intentionally add, remove, or alter a first-party High or
Medium row:

1. Expect the strict baseline/live gate to fail the production-source provenance
   check immediately after a `smart-contracts` edit. Generate fresh High/Medium
   detector JSON in an operating-system temporary directory instead:

   ```bash
   python -m slither . --config-file slither.config.json --foundry-compile-all --exclude-low --exclude-informational --exclude-optimization --json-types detectors --json <temp-slither-json> --fail-none
   ```

2. Produce a deterministic, non-gating candidate report without weakening or
   overwriting the canonical baseline:

   ```bash
   python scripts/check_slither_baseline.py --candidate-slither-json <temp-slither-json> --candidate-output <temp-candidate-json>
   ```

   The `6529stream.slither-normalized-candidate.v1` output contains semantic
   identities and scope counts only. It deliberately has no triage status,
   rationale, owner, issue, or required proof; keep it in the OS temp directory
   or ignored `cache/`, never commit it, and never use it as release evidence.
3. Verify each candidate finding against the source rather than accepting analyzer output
   mechanically.
4. Fix confirmed defects and add focused regression coverage. For an intentional
   design or false positive, record a narrow, reviewable disposition instead of
   adding a broad suppression.
5. Deliberately update the checker snapshot constants, normalized JSON,
   provenance, triage metadata, and required proof. Then regenerate the exact
   Markdown mirror:

   ```bash
   python scripts/check_slither_baseline.py --render-markdown
   ```

6. Rerun the focused tests, metadata gate, and full live gate.

Keep production and test-only findings distinct. Do not close the security or
release-readiness work merely because the baseline is internally consistent.
