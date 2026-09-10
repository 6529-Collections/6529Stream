# Maintenance tools

Start ordinary contract work with `python scripts/dev.py doctor`, then
`python scripts/dev.py test`. This directory contains the implementation of
repository checks and release tooling. It uses ordinary Python packages and
the standard library unless a specific tool documents an optional dependency.

Run an individual tool as a module **from the repository root**:

```sh
python -m tools.build.check_abi_compatibility --target-only
python -m tools.docs.check_markdown_links
python -m tools.development.test_dev
```

`scripts/dev.py` can also be invoked by absolute path from another directory;
it selects the repository and child-process Foundry profile for you.

| Package | Responsibility |
| --- | --- |
| `build/` | Compiler artifacts, ABI compatibility, source layout, formatting and size budgets |
| `protocol/` | Protocol specifications, parameters, fixtures and domain consistency |
| `docs/` | Documentation, links, contributor guidance and integration examples |
| `deployment/` | Deployment plans, public observations, rehearsals and operational evidence |
| `release/` | Release manifests, checksums, readiness reports and reproducible evidence |
| `security/` | Static-analysis baseline and private reporting workflow checks |
| `development/` | Developer-command and host-wrapper support |
| `shared/` | Small helpers used by multiple packages |

Each `test_*.py` module sits beside the tool it tests. Run it with the same
module syntax. Tests use temporary fixtures to exercise malformed inputs and
failure paths; they do not require deployment keys. See
[tooling](../docs/tooling.md) for the full validation and artifact-generation
sequence.

Use absolute package imports (`from tools.build import …`) for dependencies.
Do not add path-changing import shims or a second command registry. Keep
human-facing entry points and native bootstrap scripts in [scripts/](../scripts/README.md).
