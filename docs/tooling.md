# Tooling

6529Stream currently uses a pinned Foundry smoke baseline.

## Versions

| Tool | Version |
| --- | --- |
| Foundry | `v1.7.1` |
| Solidity compiler | `0.8.19` |
| Slither | `0.11.5` |
| solc-select | `1.2.0` |

## Local Checks

Run the canonical Gate A smoke check:

```bash
make check
```

This runs:

```bash
forge build
forge test -vvv
```

Windows contributors can run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

The Windows script prepends `%USERPROFILE%\.foundry\bin` to the current process
`PATH` so a fresh shell can find `forge` after bootstrap.

## Bootstrap

Linux or EC2:

```bash
bash scripts/bootstrap-ec2.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-windows.ps1
```

Windows bootstrap requires Python 3.8+ or the `py` launcher for the local
Slither and `solc-select` tool environment. Foundry itself is downloaded from
the pinned release asset and verified with SHA256 before extraction.

## Non-Gating Diagnostics

These commands are intentionally not part of `make check` yet:

```bash
make fmt-check
make slither
```

`make slither` runs:

```bash
slither . --config-file slither.config.json --foundry-compile-all
```

The current Slither high/medium baseline is tracked in
[`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md). Slither exits non-zero
while findings exist; that is expected until the baseline is accepted as a CI
gate.

Formatting and Slither have known baselines and should become gates only after
the roadmap items for formatting triage and Slither baseline acceptance land.
See [`docs/slither.md`](slither.md) for the full Slither workflow.
