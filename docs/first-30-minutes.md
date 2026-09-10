# Setup and your first run

This guide gets a contributor into the **current** Stream implementation. It is
the repository's first-30-minutes orientation, not a promise that a cold compiler
run finishes in thirty minutes. Stream remains pre-audit and not production-ready.

## Prerequisites

- Git and Foundry **v1.7.1** (`forge`, `cast`, and `anvil`).
- Solidity **0.8.19**, downloaded/resolved by Foundry from the checked configuration.
- Python **3.12** is required by the developer CLI. For CI parity use
  **3.12.13 on Linux** or **3.12.10 on Windows**.
- PowerShell 7 (`pwsh`) for the supplied local transaction-demo helper. Build and
  test commands themselves work from any ordinary shell.

Clone the repository and check the tools:

```text
git clone https://github.com/6529-Collections/6529Stream.git
cd 6529Stream
forge --version
python --version
python scripts/dev.py doctor
```

If Foundry is missing, follow the official [Foundry installation guide](https://getfoundry.sh/introduction/installation/) to obtain `foundryup`, or install the
matching v1.7.1 release binaries for your platform. Then select the pinned toolchain
with `foundryup --install 1.7.1`. On Windows use a supported installer shell or the
native release binaries; do not paste POSIX shell commands into PowerShell.

If Foundry is installed but `forge` is not on `PATH`, add your user Foundry `bin`
directory and reopen the shell. It is usually `~/.foundry/bin`, or
`$env:USERPROFILE + "\.foundry\bin"` on Windows. With the upstream installer
available, select the pinned toolchain using `foundryup --install 1.7.1`.
`foundryup --version` reports the installer version; it does not install Foundry.

For the complete Python toolchain, use a virtual environment and the hashed lock:

```text
python -m venv .venv-tools
```

Activate it with `source .venv-tools/bin/activate` on a POSIX shell or
`.venv-tools\Scripts\Activate.ps1` on PowerShell, then:

```text
python -m pip install --disable-pip-version-check --require-hashes --only-binary=:all: -r requirements-tools.lock
python -m pip check
```

The bootstrap scripts are optional machine-setup conveniences. Read them before
running; they are not needed when these tools are already installed. See
[toolchain reference](reference/tooling/toolchain.md) for the exact release setup.

## Build and test the current product

```text
python scripts/dev.py build
python scripts/dev.py test
```

The commands select the `current` Foundry profile without leaving a persistent
`FOUNDRY_PROFILE` in your shell. The integration suite constructs the real Core,
executor, registry, and product contracts; it checks paid minting, auctions,
entropy, metadata, revenue, and governance after genesis. It uses a controlled
external randomness provider, not live Chainlink in the test process.

A first optimized build can take tens of minutes on a new machine. Once cached,
use a filter while iterating:

```text
python scripts/dev.py test --match-contract StreamCurrentStackTest
```

Use the [test guide](../test/README.md) for domain suites and the historical
regression boundary. Do not interpret a pass using `LegacyStreamCore` as proof
of the current Core integration.

## Run a complete local transaction flow

In a separate terminal, start Anvil:

```text
anvil --port 8547 --chain-id 31337
```

Then run the supplied demo from the repository root:

```text
pwsh -NoProfile -File scripts/run-current-stack.ps1 -RpcUrl http://127.0.0.1:8547
```

This uses Anvil's public unlocked development accounts. It deploys the actual
stack, accepts the artist, buys a token, completes development entropy, exports
metadata/artwork, releases split shares, and transfers the NFT. The helper prints
its output location. The local provider is deterministic development tooling;
it is not secure randomness. See [deployment](../script/current/README.md) for
the output schema, offline simulation, and separate Sepolia/VRF requirements.

## Choose validation for your change

| Change | During iteration | Before handoff |
| --- | --- | --- |
| Documentation | `python scripts/dev.py docs` | Check linked code, executable commands, and current/legacy labels |
| Contract or test | Filter the affected suite | `python scripts/dev.py check`, plus affected domain tests |
| Release/compiler/evidence inputs | Focused checker or generator check mode | `python scripts/dev.py release` after the implementation stabilizes |

The release command runs the full existing checked pipeline. It includes broad
regressions, canonical compilation, size and gas evidence, static-analysis
policy, documentation, artifacts, and deployment rehearsals. It can take much
longer than the developer loop; it is not a first-run smoke test.

## Troubleshooting

- **Tool missing or wrong version:** run `python scripts/dev.py doctor`, correct
  the tool selection, and inspect [tooling](tooling.md) before installing more software.
- **Compilation appears idle:** optimized Solidity compilation can be CPU-bound
  with little intermediate output. Avoid launching overlapping builds into the same cache.
- **Wrong suite or stale profile:** use the explicit developer command instead
  of relying on a previously exported `FOUNDRY_PROFILE`.
- **Generated artifact drift:** do not hand-edit outputs to make a checker pass.
  Follow the [release workflow](reference/tooling/release-artifacts.md) after
  source changes stabilize; a checker failure is not permission to bless new evidence.
- **Compiler warning:** compare it with [warning dispositions](warning-dispositions.md).
  The scoped formatter preserves vendored provenance; broad reformatting is unnecessary.

Read [Contributing](../CONTRIBUTING.md) for review expectations and
[current architecture](architecture.md) before changing authority or custody.
No local command above authorizes public deployment, signing, custody changes,
or production use. Use [SECURITY.md](../SECURITY.md) for private vulnerability reports.
