# Toolchain reference

This is detailed maintainer reference. Start everyday work with the
[developer commands](../../tooling.md); run aggregate release validation only when
preparing the corresponding evidence. Commands below run from the repository root.

## Versions

| Tool | Version |
| --- | --- |
| Foundry | `v1.7.1` |
| Solidity compiler | `0.8.19` |
| Python (Linux CI/release) | `3.12.13` |
| Python (native Windows CI) | `3.12.10` |
| Slither | `0.11.5` |
| Crytic Compile | `0.3.11` |
| solc-select | `1.2.0` |
| eth-abi | `5.2.0` |
| eth-hash | `0.8.0` |
| jsonschema | `4.25.1` |
| Playwright | `1.60.0` |


## Reproducible Python Audit And Release Toolchain

[`requirements-tools.txt`](../../../requirements-tools.txt) is the short,
human-maintained list of direct tool intent. The generated
[`requirements-tools.lock`](../../../requirements-tools.lock) is the complete checked
CI/release dependency graph. Every direct and transitive package is pinned to
one version and has one or more reviewed SHA-256 artifact hashes. Linux CI and
manual release mode select CPython `3.12.13`; native Windows CI selects the
final Windows-backed 3.12 runtime, CPython `3.12.10`. Both use the full-SHA
pinned `actions/setup-python` action and install exactly the same lock with:

```bash
python -m pip install --disable-pip-version-check --require-hashes --only-binary=:all: -r requirements-tools.lock
python -m pip check
```

There is no live `pip --upgrade` step. The exact Python tool-cache artifact
provides pip, and `--require-hashes` fails if an artifact differs or dependency
resolution needs a package absent from the lock. `--only-binary=:all:` also
keeps unreviewed source builds out of the checked evidence paths.

`scripts/bootstrap-ec2.sh` and `scripts/bootstrap-windows.ps1` remain
contributor conveniences for heterogeneous local Python installations. They
consume the readable direct requirements and do not upgrade pip, but they are
not release-evidence install paths. Manual Linux release mode and Linux audit
runs must use the exact Linux runtime and hashed lock above. Native Windows CI
uses CPython `3.12.10`, the final setup-python Windows build in the 3.12 line,
with the same hashed lock and its pinned Windows toolchain setup.

### Refresh And Review

Refresh the lock only in a clean Linux x86-64 environment running CPython
`3.12.13`. Use the reviewed generator and vulnerability-scanner versions, then
run the policy checks:

```bash
python -m venv .venv-lock-refresh
source .venv-lock-refresh/bin/activate
python -m pip install "pip-tools==7.6.0" "pip-audit==2.10.1"
CUSTOM_COMPILE_COMMAND='python -m piptools compile --generate-hashes --strip-extras --no-emit-index-url requirements-tools.txt' \
  python -m piptools compile --generate-hashes --strip-extras --no-emit-index-url \
  --output-file=requirements-tools.lock requirements-tools.txt
python -m pip_audit --require-hashes -r requirements-tools.lock
python -m tools.development.test_python_toolchain
python -m tools.development.check_python_toolchain
```

Review the full package/version change and every added or removed hash, not
only the eight direct pins. `pywin32==312` is intentionally direct and guarded
by the exact `sys_platform == "win32"` marker so the common lock closes Web3's
Windows dependency without making Linux resolve a Windows-only wheel. The
generated lock must not contain index URLs,
trusted-host settings, credentials, or private package references. Record or
remediate vulnerability findings before acceptance. Update the deliberately
maintained `EXPECTED_LOCKED_NAMES` closure in
`tools/development/check_python_toolchain.py` in the same reviewed diff; the checker
rejects either missing or extra resolved distributions. The expected generated
diff is the lock plus the downstream release manifest/checksum bundle after the
normal generator sequence; changes to direct intent also update
`requirements-tools.txt`. Update the pinned Python, setup action, compiler, or
scanner deliberately in the same focused PR when one of those inputs changes.

The Playwright Python package is inside the hashed lock. Chromium itself is a
separate runtime download: `python -m playwright install --with-deps chromium`
uses the browser revision encoded by locked Playwright `1.60.0`, while the
runner's operating-system packages installed by `--with-deps` are outside the
Python package lock. Both workflows invoke that same locked module and command;
the Python lock does not claim to checksum Chromium or Ubuntu packages.

Python toolchain provenance is part of release evidence: the checksum bundle
covers the direct requirements, hashed lock, both consuming workflows, and the
checker plus its tests. This binds the reviewed install policy without storing
credentials or private-index configuration. It improves reproducibility only
and does not promote release maturity.

The checker is a static declaration guard for the reviewed workflow grammar,
canonical installer commands, lock closure, and workflow inventory. It is not
a shell sandbox and does not prove the absence of commands assembled dynamically
through variables, `eval`, or equivalent runtime construction. Full-workflow
checksum binding and PR review remain the controls for arbitrary command changes.


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

