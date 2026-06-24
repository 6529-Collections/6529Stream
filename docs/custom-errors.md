# Custom Error Catalog

6529Stream treats custom errors as part of the external protocol surface.
Auditors, operators, indexers, wallets, and frontend clients should decode
custom errors from the ABI before falling back to raw revert bytes.

The canonical machine-readable catalog is:

- `release-artifacts/latest/custom-error-catalog.json`

The catalog is generated from:

- `release-artifacts/latest/protocol-surface-report.json`
- `scripts/generate_custom_error_catalog.py`

## Scope

The catalog covers release-relevant production contracts present in
`release-artifacts/latest/protocol-surface-report.json`. It records every
ABI-visible custom error for those contracts with:

- contract and source path;
- signature and selector;
- input metadata;
- category and severity;
- caller action guidance;
- source artifact and test traceability.

The generator fails closed when a release-relevant custom error is not covered
by the explicit per-error category map, or when its traceability paths do not
exist in `test/`. New custom errors therefore need a deliberate
category, severity, caller-action, and traceability policy before the catalog
can be regenerated.

This is documentation and traceability evidence. It does not prove protocol
correctness by itself. Correctness still depends on the Solidity tests,
invariants, release checks, external evidence, and audit review.

## Categories

| Category | Meaning |
| --- | --- |
| `access_control` | Caller, signer, coordinator, minter, or authorized contract boundary failed. |
| `pause_emergency` | A pause or emergency domain intentionally blocks the attempted state transition. |
| `metadata_integrity` | Metadata, dependency, freeze, URI, raw attribute, or rendering policy rejected the payload. |
| `randomness_lifecycle` | Randomizer request, provider, epoch, callback, stale, failed, or retry state rejected the payload. |
| `auction_payment_safety` | Reentrancy, payment, or accounting safety boundary rejected the call. |
| `primary_settlement_safety` | Primary-sale settlement context, replay, policy-hash, native transfer, ERC-20 transfer, or exact-delta boundary rejected the call. |
| `revenue_assignment_safety` | Revenue resolver assignment, template, materialized dynamic account, frozen scope, or split-profile verification rejected the call. |
| `split_payment_safety` | Split profile validation, deterministic wallet deployment, asset policy, or split-release accounting rejected the call. |
| `supply_minting` | Collection supply, token existence, mint window, burn, or collection-range state rejected the call. |
| `configuration` | A configured address, parameter, royalty percentage, or other setup value is invalid. |

## Severity

Severity describes how a client or reviewer should treat the error class, not
whether the revert is a vulnerability.

| Severity | Integration posture |
| --- | --- |
| `critical` | Do not retry unchanged. Refresh authority state and verify caller/signer/role assumptions. |
| `high` | Refresh protocol state and follow the relevant runbook before retrying. |
| `medium` | Treat as configuration or lifecycle feedback; fix the submitted parameter or state assumption before retrying. |

## Integration Requirements

Wallets and frontends should:

- decode errors from current ABIs instead of string-matching revert text;
- surface actionable messages for access-control, pause, metadata, randomness,
  revenue assignment, primary settlement, payment, and mint-state categories;
- treat replay, stale, wrong-domain, wrong-provider, wrong-token, frozen, and
  pause errors as terminal for the submitted payload;
- refresh release artifacts when selector or ABI compatibility checks change;
- avoid retry loops on `critical` and `high` errors unless refreshed state says
  the precondition has changed.

Indexers and monitoring should:

- record decoded custom error names for failed operator transactions;
- alert on unexpected `access_control`, `pause_emergency`, and
  `randomness_lifecycle` failures in production ceremonies;
- correlate decoded errors with emitted events and read-after-event checks
  rather than inferring state from a failed transaction alone.

## Maintenance

Run these commands after ABI, error, or release-artifact changes:

```bash
python scripts/generate_protocol_surface_report.py
python scripts/generate_custom_error_catalog.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
```

CI and local gates check drift with:

```bash
python scripts/test_custom_error_catalog.py
python scripts/generate_custom_error_catalog.py --check
```

Changing or removing a custom error is a release-impacting ABI change. The
change must update the catalog, ABI compatibility baseline if accepted,
integration docs when behavior changes, and the changelog.
