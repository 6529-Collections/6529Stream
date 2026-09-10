# Solidity source map

The Foundry source root is [smart-contracts/](../smart-contracts), configured by
[foundry.toml](../foundry.toml). Implementations and caller interfaces are grouped
by responsibility; historical components are visibly separated from current ones.
Start with [architecture](architecture.md) for the working product and the
[interface map](../smart-contracts/interfaces/stream/README.md) for imports.

## Directory boundaries

| Directory | Responsibility |
| --- | --- |
| [core/](../smart-contracts/core/) | Permanent Core and tightly coupled bounded reads |
| [domains/](../smart-contracts/domains/) | First-party implementations by domain; older mint/auction implementations live in explicit legacy subdirectories |
| [interfaces/stream/](../smart-contracts/interfaces/stream/) | Domain interfaces and smaller caller capabilities; legacy APIs separated |
| [interfaces/standards/](../smart-contracts/interfaces/standards/) | Shared minimal standards used by first-party code |
| [interfaces/compatibility/](../smart-contracts/interfaces/compatibility/) | ABI-only compatibility surfaces |
| [integrations/](../smart-contracts/integrations/) | External boundaries; older randomizers under randomizers/legacy |
| [libraries/](../smart-contracts/libraries/) | Utilities shared across domains |
| [vendor/](../smart-contracts/vendor/) | Retained upstream code and provenance |
| [compatibility/](../smart-contracts/compatibility/) | Historical non-interface implementations/adapters |

Directory placement is not a maturity claim. Some domain sources implement future
specification components that the current stack does not install. The
[current walkthrough](current-stack.md), [status](status.md) and
[release catalog](../release-artifacts/contracts.json) describe distinct scopes.

## Caller interfaces

Core's existing capabilities now have separate files under `interfaces/stream/core`;
`IStreamCore` remains the aggregate compatibility API. Governance and mint expose
execution, administration and reads separately. Entropy already distinguishes
coordinator, provider and read-only views. Import the smallest interface your
caller needs, without inventing a local duplicate of a shared boundary.

Facade inheritance is a source dependency choice, not a new access-control rule.
Existing aggregate ABIs and advertised ERC-165 IDs remain compatibility constraints.
The implementation's NatSpec and tests define call behavior; source layout alone
does not make a planned interface implemented or advertise a new interface ID.

## Current inventory and historical evidence

[Source-layout-current](../smart-contracts/source-layout-current.json) owns the
active inventory and this reorganization's 57 relocations. The original
[source-layout.json](../smart-contracts/source-layout.json) records the earlier
120-file migration and remains immutable. Its
[equivalence receipt](../release-artifacts/evidence/solidity-layout-equivalence.json)
is historical proof for that migration, not a checksum of today's whole tree.

```text
python -m tools.build.check_solidity_source_layout
python -m tools.build.check_solidity_layout_equivalence --check-receipt
```

The active layout check validates current placement/import boundaries. The receipt
check validates retained history. Recomputing the old receipt with `--check-source`
or `--generate` is a deliberate historical-proof task, not ordinary development.
Preserve deployment compiler snapshots and their original source names exactly.

Moving source identities can change Solidity via-IR bytecode ordering even when
ABI, storage and execution behavior are unchanged. Compare compiler output and
record differences honestly; do not claim identical deployment bytecode from
source-level equivalence alone. Generated release ABI, event, error and size
reports remain authoritative for their explicitly named compiler inputs/profile.

## Find code and tests

```text
rg -n "^(abstract )?(contract|interface|library) " smart-contracts
rg -n "ContractOrFunctionName" smart-contracts test docs
```

Follow [the test map](../test/README.md): current integration for complete flows,
unit domains for focused behavior, and legacy regressions for older implementations.
Use `python scripts/dev.py test` for the current suite and
`python scripts/dev.py check` for its validation boundary. Full release work follows
[tooling](tooling.md), including generator order and exact profile provenance.
