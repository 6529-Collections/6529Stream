# Repository Automation

This directory contains the Python and shell automation that validates,
generates, and packages repository evidence.

Do not confuse it with [`../script/`](../script/), which contains Foundry
deployment and rehearsal contracts. The canonical tool inventory and command
semantics live in [`../docs/tooling.md`](../docs/tooling.md).

## Entry Points

Use the aggregate entrypoint for the platform:

```bash
make check
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```

The Unix implementation is [`check.sh`](check.sh), and the Windows
implementation is [`check.ps1`](check.ps1). The [`../Makefile`](../Makefile)
defines named focused targets for contributors who do not need the complete
gate.

Avoid reconstructing the aggregate gate from individual commands. The
wrappers encode ordering, platform behavior, generated-artifact dependencies,
and failure semantics that a copied command list can lose.

## Naming Conventions

| Prefix | Expected responsibility |
| --- | --- |
| `test_*.py` | Exercise a paired checker, generator, parser, or policy with positive and negative fixtures |
| `check_*.py` | Validate committed or generated state without silently repairing it |
| `generate_*.py` | Produce deterministic artifacts; release-facing generators should support a non-writing check mode where practical |
| `build_*.py` | Build an isolated compilation or evidence input whose environment is part of the result |
| `run_*.py` | Execute a diagnostic or capture step whose output is consumed by another explicit checker |
| `verify_*.py` | Verify a completed bundle or cross-artifact relationship for a reviewer or release consumer |

Some established scripts predate these names. Preserve their public command
surface unless a focused migration updates every caller, document, workflow,
and release checksum that depends on the old path.

## How The Scripts Fit Together

Most checked surfaces follow one of these shapes:

```text
test_* -> check_*
test_* -> generate_* --check
generate_* -> downstream manifest/checksum generators
capture or build -> check_* -> retained or generated evidence
```

- Tests prove that invalid, missing, stale, duplicate, or secret-bearing input
  fails as intended.
- Checkers compare the current repository against reviewed policy or
  deterministic output.
- Generators write artifacts only when explicitly invoked without their check
  mode.
- Release manifests and checksum bundles are downstream outputs. Regenerate
  upstream artifacts first and the manifest/checksum tail last.

Use [`../docs/tooling.md`](../docs/tooling.md) for the exact dependency order.
Use [`../docs/release-policy.md`](../docs/release-policy.md) to determine
whether a script change is release-impacting.

## Finding The Right Script

Search by artifact or policy name before adding another entrypoint:

```bash
rg -n "artifact-name|policy-name" scripts Makefile docs/tooling.md
rg --files scripts | rg "check_|generate_|test_"
```

Also inspect the relevant `Makefile` target and both platform wrappers. A
script present in only one aggregate entrypoint is usually an integration gap,
not a platform-specific exception.

## Change Discipline

When adding or changing automation:

1. Keep the change focused on one policy, artifact family, or evidence gate.
2. Add or update tests for the success path and important rejection paths.
3. Fail with actionable messages that identify the stale or invalid input.
4. Keep default local and CI checks non-interactive.
5. Do not require production secrets, private RPC URLs, signer material, or
   live credentials in the default gate.
6. Use repository-relative paths and deterministic serialization for tracked
   output.
7. Update the `Makefile`, `check.sh`, `check.ps1`, CI workflow, and
   [`../docs/tooling.md`](../docs/tooling.md) together when aggregate gate
   membership changes.
8. Regenerate release manifests and checksums when the changed script is part
   of their covered input set.

Do not hand-edit deterministic release artifacts to make a checker pass.
Follow the generator order documented in [`../docs/tooling.md`](../docs/tooling.md).

## Focused Validation

For a paired Python checker:

```bash
python scripts/test_example.py
python scripts/check_example.py
```

For repository documentation links:

```bash
python scripts/test_markdown_links.py
python scripts/check_markdown_links.py
```

Finish with the smallest honest validation set for the changed surface, then
run the aggregate platform gate when the change affects shared release or CI
behavior.
