# Test map

Run the current product first:

```text
python scripts/dev.py test
```

This selects the `current` profile and integration suites under `test/current`.
They wire actual permanent Core, governance, canonical registry, sale/auction,
artist attribution, entropy, metadata, ERC-20 payments, state exports and split wallets. Start here to understand
a complete transaction.

| Path | Responsibility | Command |
| --- | --- | --- |
| `current/` | Product, adversarial flow and catalog replacement integration | `python scripts/dev.py test` |
| `current/StreamCurrentStackFuzz.t.sol`, `current/StreamCurrentStackInvariant.t.sol` | Varied signed inputs and dependent handler sequences | `python scripts/dev.py campaign --mode quick --seed 0x6529` |
| `unit/<domain>/` | Current contract/library behavior and focused target components | `python scripts/dev.py test --suite unit` |
| `regression/legacy/<domain>/` | Earlier behavior whose import closure reaches LegacyStreamCore | `python scripts/dev.py test --suite legacy` |
| `gas/` | Scenario snapshots and gas budgets | `python scripts/dev.py test --suite gas` |
| `helpers/`, `mocks/`, `fixtures/` | Shared setup, adversarial collaborators and vectors | Imported by suites |

```text
python scripts/dev.py test --match-contract StreamCurrentStackTest
python scripts/dev.py test --match-contract StreamCurrentStackERC20Test
python scripts/dev.py test --match-contract StreamCurrentStateExportTest
python scripts/dev.py test --suite unit --match-contract StreamFixedPriceSaleAdapterTest
python scripts/dev.py test --suite all
```

Use actual contract/test names from `.t.sol` files. `--match-test` and other Forge
filters are forwarded. Current integration uses global via-IR; unit/legacy/gas/all
use the default regression profile. A cold full build is substantially more
expensive than a warm focused test.

Use `python scripts/dev.py campaign --mode extended --seed 0x6529` for the larger
input/sequence campaign. The [campaign guide](../docs/tooling.md#reproducible-fuzz-and-invariant-campaigns)
documents budgets, cache isolation, failure traces and replay. The handler's
opening sequence and `afterInvariant` success counters complement Foundry's
attempted-call metrics; rejected operations alone must not satisfy the campaign.

Place isolated behavior regressions beside their domain. Put cross-contract
ownership, payment, authorization and rollback assertions in `current/`. Avoid
mock-only proof when a failure depends on real contracts interacting. Preserve
legacy regressions while that implementation remains supported; do not present
them as current API proof. Interface refactors preserve public ABI and advertised
ERC-165 IDs, including aggregate interfaces.

Fixture files are inputs, not credentials. The [full validation command](../docs/tooling.md)
adds Python policy tests, reproducible artifacts and release checks. Run it at the
integration/release boundary rather than for every edit. Passing tests does not
establish production readiness.
