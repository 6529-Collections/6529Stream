# Developer commands

Use `python scripts/dev.py` from the repository root. It selects the intended
Foundry profile per command, so a leftover shell variable cannot silently select
a different build. Start with the [setup guide](first-30-minutes.md).

| Command | Purpose |
| --- | --- |
| `python scripts/dev.py doctor` | Check Python, Foundry and compiler configuration |
| `python scripts/dev.py build` | Build the current product profile |
| `python scripts/dev.py test` | Run the current whole-stack tests |
| `python scripts/dev.py check` | Current build/tests and focused interface/layout checks |
| `python scripts/dev.py docs` | Documentation validation |
| `python scripts/dev.py release` | Full release validation, including legacy regressions and artifacts |
| `python scripts/dev.py clean` | Remove build outputs; retain transaction broadcasts |

`make` shows help. `make dev`, `make doctor`, `make docs-check` and
`make release-check` are aliases; `make current-stack-check` and `make check`
remain supported current/full validation entrypoints. PowerShell users can also
run `pwsh -NoProfile -File scripts/check.ps1 -CurrentStack` or omit `-CurrentStack`
for the full aggregate wrapper.

## Pick the relevant tests

```text
python scripts/dev.py test --match-contract StreamCurrentStackTest
python scripts/dev.py test --suite unit --match-test testExample
python scripts/dev.py test --suite legacy
python scripts/dev.py test --suite gas
python scripts/dev.py test --suite all
```

Replace example filters with real test names from the [test map](../test/README.md).
The default suite is `current`. Unit, legacy and gas selections use the default
regression profile; they have a different compilation purpose. A cold via-IR build
can take tens of minutes or longer. Warm targeted tests are the normal edit loop.
Changing compiler inputs can invalidate that cache. Do not run concurrent builders
against the same output/cache directories.

## Compiler and evidence boundaries

Foundry is pinned to **v1.7.1**, Solidity to **0.8.19**, and the supported developer
Python line is **3.12** (CI uses 3.12.13 on Linux and 3.12.10 on Windows). The current
profile uses global via-IR. The default profile combines current and historical
regressions with explicit per-source compiler restrictions. The canonical release
builder and retained deployment compiler exports serve separate provenance goals.
An artifact from one closure/profile must not be presented as another's bytecode.

Passing current tests proves the exercised local behaviors. It does not establish
production readiness or replace the [release gates](release-readiness.md). Stream
remains pre-audit and not production-ready.

## Maintainer references

| Task | Detailed reference |
| --- | --- |
| Install pins or refresh the Python lock | [Toolchain](reference/tooling/toolchain.md) |
| Locate an individual checker or full-wrapper stage | [Validation catalog](reference/tooling/validation.md) |
| Change time/gas parameters or governance policy | [Governed parameters](reference/tooling/governed-parameters.md) |
| Format Solidity or review a compiler warning | [Formatting](reference/tooling/formatting.md) |
| Regenerate evidence in dependency order | [Release artifacts](reference/tooling/release-artifacts.md) |
| Capture and compare production Slither findings | [Slither](reference/tooling/slither.md) |

Do not hand-edit generated release files. Preserve retained historical deployment
compilations byte-for-byte. Consult the relevant reference before changing tooling,
and validate a focused change before starting the complete release pass.
