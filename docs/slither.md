# Slither Baseline

6529Stream pins its Slither toolchain and tracks a normalized first-party
High/Medium baseline. The current inventory retains 45 findings: 4 High and
41 Medium. Thirty remain Open, and 15 have detector-specific False Positive
dispositions. Matching this inventory is not an audit or a readiness claim.

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

The production-only capture analyzes every Solidity file under
`smart-contracts/`, including production libraries, interfaces, and vendored
utilities. Crytic Compile's default Foundry mode excludes `test/` and `script/`
constructor closures; normal Foundry regression tests remain independent.
The capture's exact source commit, timestamp, input hashes, native exit, and
raw output digest are recorded in `ops/SLITHER_BASELINE.json`.

The checked compiler inputs contain all 171 production source files, with
contents verified against the source tree and compiler output for every file.
They contain no test or script source. Slither reports 203 analyzed contracts
across its compilation units (175 unique compiler contract outputs), using
101 detectors. This captures all production targets without optimizing the
large deployment/test constructors merely to analyze production code.

The unfiltered production run contains 796 findings: 5 High, 50 Medium,
106 Low, 627 Informational, and 8 Optimization. Its High/Medium split is:

| Scope | High | Medium | Total |
| --- | ---: | ---: | ---: |
| First-party production | 4 | 41 | 45 |
| Vendored | 1 | 9 | 10 |
| Test (excluded from this scan) | 0 | 0 | 0 |
| Script (excluded from this scan) | 0 | 0 | 0 |
| Other | 0 | 0 | 0 |

The current capture is bound to source/config checkpoint
`db8e31ed886faa838a9dc83926d8bad869ce549b`. Its two compiler groups use Solidity
0.8.19 with the configured IR/non-IR split; their union includes exactly the
171 production sources, with matching contents and compiler output for every file.

Compared with the preceding reorganization capture at
`7b4ef22b052419e88d56cf7f207a7a7738dba7a7`, 43 High/Medium identities are unchanged.
The guarded `initializeGenesis` reentrancy row has a new semantic fingerprint
following extraction of scheduling validation; its detector-specific False
Positive disposition was reviewed again. One new `unused-return` row covers
`StreamStateExport._requireActivePublisher`: the helper intentionally selects
the authenticated Core's stored pointer identity fields. Its disposition proves
current-pointer binding, without claiming a live registry-status check.

The 30 Open rows remain Open. There are now 15 reviewed False Positive rows;
no suppression was added. The preceding raw capture and its provenance remain
historical evidence; this refresh does not relabel or overwrite that capture.
Current source/test citations and the two new dispositions are in the normalized
JSON and its deterministic Markdown mirror.

The existing detector-specific dispositions cover JSON formatting, deliberate
sentinels/default locals, omitted tuple fields, guarded callbacks and signed value
flow. They do not attest every possible defect in those functions or replace the
separate registered-scope authorization regression, full integration tests and
independent audit. Raw informational counts can change with source/interface
organization without changing the exact High/Medium gate.

Bounded assembly prevents `StreamGovernanceExecutor` governed-call returndata
bombs, but makes its proposal-selected native-value authority invisible to
Slither's `arbitrary-send-eth` detector. The row's disappearance is not a
remediation or acceptance. The closed-world target/selector/value runtime,
machine catalog, and adversarial value-flow tests now exist, but High open
blocker `RISK-GOV-003` preserves the semantic risk until #656-bound candidate
deployment/rehearsal evidence and independent review under #658 are complete.

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
`python -m tools.security.check_slither_baseline --baseline-only`. It validates the tracked
normalized baseline, provenance, counts, and disposition metadata without
launching Slither. Keeping this path analyzer-free makes the ordinary aggregate
check fast and deterministic.

## Live CI Gate

Run the complete source-to-baseline comparison with:

```bash
make slither-baseline-check
```

The complete target first runs the fast metadata gate, then invokes
`python -m tools.security.check_slither_baseline --run-slither` with the pinned toolchain and
compares the normalized first-party High and Medium rows with the tracked
baseline. The live command omits `--foundry-compile-all`: tests and scripts are
not analyzer targets, while every production source is compiled. New rows and
stale rows fail the check. CI runs this target in a dedicated Ubuntu job with a 45-minute timeout so live analyzer cost does not
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

This optional whole-repository diagnostic also compiles test and script
constructors and can be substantially slower. It can exit non-zero while
tracked baseline findings remain open. Use `make slither-baseline-check` for the fail-on-drift contract.

Capture all production detector impacts while investigating or intentionally
refreshing the normalized baseline:

```bash
python -m slither . --config-file slither.config.json --json-types detectors --json /tmp/slither-report.json --fail-none
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
   python -m slither . --config-file slither.config.json --exclude-low --exclude-informational --exclude-optimization --json-types detectors --json <temp-slither-json> --fail-none
   ```

2. Produce a deterministic, non-gating candidate report without weakening or
   overwriting the canonical baseline:

   ```bash
   python -m tools.security.check_slither_baseline --candidate-slither-json <temp-slither-json> --candidate-output <temp-candidate-json>
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
   python -m tools.security.check_slither_baseline --render-markdown
   ```

6. Rerun the focused tests, metadata gate, and full live gate.

Keep production and test-only findings distinct. Do not close the security or
release-readiness work merely because the baseline is internally consistent.
