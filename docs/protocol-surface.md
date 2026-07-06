# Protocol Surface Report

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

This document describes the generated protocol surface report for the current
6529Stream local baseline. The report is pre-audit evidence only: it is not a
production-readiness claim, a security claim, or a substitute for ABI review,
tests, Slither review, external audit, or live deployment verification.

## Source Of Truth

The generated report is tracked at
[`release-artifacts/latest/protocol-surface-report.json`](../release-artifacts/latest/protocol-surface-report.json).
It is derived from the production contract set in
[`release-artifacts/contracts.json`](../release-artifacts/contracts.json) and
the Foundry production build artifacts under ignored `out/` after:

```sh
forge build --sizes --via-ir --skip test --skip script --force
python scripts/generate_release_artifacts.py
python scripts/generate_protocol_surface_report.py
python scripts/generate_custom_error_catalog.py
python scripts/check_natspec_coverage.py
```

Check the committed report without rewriting it with:

```sh
python scripts/test_protocol_surface_report.py
python scripts/generate_protocol_surface_report.py --check
python scripts/test_custom_error_catalog.py
python scripts/generate_custom_error_catalog.py --check
python scripts/test_natspec_coverage.py
python scripts/check_natspec_coverage.py
```

The canonical local gate also runs those commands through `make check`,
`scripts/check.sh`, `scripts/check.ps1`, and CI.

The NatSpec coverage gate in
[`docs/natspec-coverage.md`](natspec-coverage.md) uses this report as its
source of truth for release-surface functions, public variable getters, events,
and custom errors.

## Contents

The report records each release-tracked production contract with:

- source path, Foundry artifact path, ABI hash, creation bytecode hash, runtime
  bytecode hash, and runtime byte size;
- external and public function signatures, selectors, state mutability, read or
  write posture, payable status, inputs, and outputs;
- event signatures, topic0 values, anonymous status, indexed fields, and input
  metadata;
- custom error signatures, selectors, and input metadata;
- per-contract and aggregate counts for functions, read functions, write
  functions, payable functions, events, and custom errors.

The report intentionally does not assert that a function is safe to call or that
an event sequence is complete. It is a deterministic index that makes ABI,
event, and error review easier to diff.

## Related Artifacts

Use the report with these adjacent artifacts:

- [`release-artifacts/latest/abi-checksums.json`](../release-artifacts/latest/abi-checksums.json)
  for ABI and bytecode hashes.
- [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../release-artifacts/baselines/v0.1.0/abi-surface.json)
  for ABI compatibility review.
- [`release-artifacts/latest/event-topic-catalog.json`](../release-artifacts/latest/event-topic-catalog.json)
  for indexer event topics.
- [`release-artifacts/latest/custom-error-catalog.json`](../release-artifacts/latest/custom-error-catalog.json)
  and [`docs/custom-errors.md`](custom-errors.md) for decoded error
  categories, selector traceability, and caller action guidance.
- [`release-artifacts/latest/interface-ids.json`](../release-artifacts/latest/interface-ids.json)
  for ERC-165 interface IDs.
- [`release-artifacts/latest/release-manifest.json`](../release-artifacts/latest/release-manifest.json)
  for the top-level release artifact and document index.
- [`release-artifacts/latest/SHA256SUMS`](../release-artifacts/latest/SHA256SUMS)
  and
  [`release-artifacts/latest/release-checksums.json`](../release-artifacts/latest/release-checksums.json)
  for checksum coverage.

## Maintenance

Regenerate the report whenever a release-tracked contract ABI, event, custom
error, bytecode, source path, or production artifact changes. The report must be
refreshed in the same PR as the covered change unless the PR explicitly scopes
itself away from release artifacts.

Changes to the report are release-impacting when they reflect contract surface
changes, generator schema changes, artifact hashing changes, or contract-set
changes. Record those changes in [`CHANGELOG.md`](../CHANGELOG.md) and keep the
release manifest and checksum bundle current.
