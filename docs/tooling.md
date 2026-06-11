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
forge build --sizes --via-ir --skip test --skip script --force
python scripts/test_release_artifacts.py
python scripts/generate_release_artifacts.py --check
python scripts/test_deployment_manifest.py
python scripts/generate_deployment_manifest.py --check
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
```

The size step is the production deployability gate. It skips test and script
contracts so non-production artifacts do not pollute EIP-170/EIP-3860 evidence,
and it uses `via_ir` because the current deployable `StreamCore` release profile
needs the IR optimizer to fit under the runtime limit.

The deployment rehearsal step is the first Gate E local ceremony gate. It uses
non-secret placeholder addresses, deploys the current contract stack, wires the
minter/drops/auction/randomizer surfaces, transfers Ownable control to the Safe
placeholder, and leaves fork/testnet broadcasting for later Gate E work.

The release artifact step is the first Gate G machine-readable artifact gate.
It verifies that `release-artifacts/latest/` matches the production `via-ir`
Foundry build output, including ABI checksums, bytecode checksums, interface
IDs, and the event topic catalog. The generator automatically finds Foundry's
`cast` in `~/.foundry/bin` when the shell has not added it to `PATH`.

The deployment manifest step generates the local Anvil example from
`deployments/config/anvil-6529stream-v0.1.0-001.json`, fills contract ABI and
runtime bytecode hashes from `release-artifacts/latest/abi-checksums.json`, and
checks that the committed example has not drifted.

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

## Release Artifacts

After changing any production contract ABI or event surface, run the production
build and regenerate the tracked release baseline with:

```bash
forge build --sizes --via-ir --skip test --skip script --force
python scripts/generate_release_artifacts.py
python scripts/generate_deployment_manifest.py
```

The check mode is:

```bash
python scripts/generate_release_artifacts.py --check
python scripts/generate_deployment_manifest.py --check
```

The generator uses `release-artifacts/contracts.json` to define the production
contract and interface surface. Standard ERC interface IDs are pinned there when
the advertised ERC ID differs from a raw XOR over the artifact ABI.

The deployment manifest generator uses committed inputs under
`deployments/config/`. Its manifest checksum is the SHA-256 of canonical JSON
with `release_artifacts.manifest_sha256` normalized to `sha256:` plus 64 zeroes,
which avoids a self-referential checksum while making manifest drift
machine-detectable.

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
