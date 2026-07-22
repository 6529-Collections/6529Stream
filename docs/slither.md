# Slither Baseline

Slither is a direct pin in `requirements-tools.txt` and is transitively
hash-locked for Linux CI/release through `requirements-tools.lock`. It is
currently a non-gating diagnostic. It is expected to report high and medium
findings until the roadmap triage work fixes, accepts, or scopes each row.

## Versions

| Tool | Version |
| --- | --- |
| Slither | `0.11.5` |
| solc-select | `1.2.0` |
| Solidity compiler | `0.8.19` |

## Local Run

Bootstrap the tools first:

```bash
bash scripts/bootstrap-ec2.sh
```

or on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1
```

Then run Slither:

```bash
solc-select use 0.8.19
make slither
```

The target runs:

```bash
slither . --config-file slither.config.json --foundry-compile-all
```

On Windows without `make`, run the local virtual-environment binary directly:

```powershell
$env:Path = "$HOME\.foundry\bin;$PWD\.venv-tools\Scripts;$env:Path"
.\.venv-tools\Scripts\solc-select.exe use 0.8.19
.\.venv-tools\Scripts\slither.exe . --config-file slither.config.json --foundry-compile-all
```

Slither currently exits non-zero because findings exist. A non-zero exit from
this command is expected until the baseline is accepted as a gate.

The bootstrap scripts install and select Solidity `0.8.19`. Run the
`solc-select use` command explicitly when refreshing the baseline from an
existing shell or virtual environment.

## JSON Output

Raw JSON output is useful for refreshing the baseline, but it is not committed
because it is large and noisy.

```bash
slither . --config-file slither.config.json --foundry-compile-all --json slither-baseline.json
```

`slither-baseline.json`, `slither-report.json`, `slither-results.json`, and the
default Slither triage database are ignored by Git.

## Baseline Process

The tracked high/medium baseline lives in
[`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md).

When refreshing it:

1. Run Slither with the pinned toolchain and config.
2. Record the total count, impact counts, and high/medium detector rows.
3. Keep production findings `Open` until a PR fixes them or a maintainer
   accepts them with rationale.
4. Keep test-only findings separate from production findings.
5. Add or update the required regression test for every fixed production
   finding.

Slither should become a CI gate only after the high/medium baseline is fixed,
accepted, or explicitly documented as false positive.
