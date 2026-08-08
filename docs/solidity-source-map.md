# Solidity Source Map

The Foundry source root is [`smart-contracts/`](../smart-contracts), configured
by [`foundry.toml`](../foundry.toml). Its domain-first hierarchy separates
first-party implementations from protocol interfaces, external integrations,
vendored sources, shared libraries, and compatibility-only surfaces.

The exact 120-file migration is recorded immutably in the reviewed
[`source-layout.json`](../smart-contracts/source-layout.json) manifest. That
manifest and `scripts/check_solidity_source_layout.py` are authoritative for
source placement. The release contract catalog and generated surface artifacts,
not this prose, remain authoritative for the contracts and interfaces included
in a release.

## Directory Boundaries

| Directory | Responsibility |
| --- | --- | --- |
| [`core/`](../smart-contracts/core) | Permanent Core implementation and its tightly coupled bounded-read libraries |
| [`domains/`](../smart-contracts/domains) | First-party implementations grouped by access, auctions, dependencies, finality, governance, metadata, minting, modules, parameters, preservation, records, and revenue |
| [`interfaces/stream/`](../smart-contracts/interfaces/stream) | Current protocol ABI boundaries implemented or consumed by Stream components |
| [`interfaces/standards/`](../smart-contracts/interfaces/standards) | Minimal protocol-owned standard interfaces that are not vendored copies |
| [`interfaces/compatibility/`](../smart-contracts/interfaces/compatibility) | ABI-only legacy and compatibility interfaces; contracts and libraries are forbidden here |
| [`integrations/`](../smart-contracts/integrations) | Arrng, delegation, NextGen, and randomizer provider boundaries and adapters |
| [`libraries/`](../smart-contracts/libraries) | Shared first-party utilities that are not owned by one domain |
| [`vendor/`](../smart-contracts/vendor) | Locally retained OpenZeppelin and Chainlink sources, preserving provider provenance and formatting boundaries |
| [`compatibility/`](../smart-contracts/compatibility) | Non-interface historical implementations or adapters; ABI-only interfaces are forbidden here |

Directory placement is a review boundary, not proof of release scope. Use the
machine-readable catalogs below before treating any file as production,
deployed, permanent, or supported.

## Component Map

| Domain | Common source families | Start with |
| --- | --- | --- |
| Core token identity and lifecycle | `StreamCore*`, `IStreamCore*` | [`architecture.md`](architecture.md), [`launch-v1-target-architecture.md`](launch-v1-target-architecture.md) |
| Administration, roles, and governance | `StreamAdmins`, `StreamGovernance*`, `StreamRole*`, parameter hosts, stores, and probes | [`adr/0004-admin-governance.md`](adr/0004-admin-governance.md), [`threat-model.md`](threat-model.md) |
| Minting, drops, auctions, and payments | `StreamMint*`, `StreamDrops`, `StreamMinter`, auction, settlement, revenue, and split components | [`mint-policy-and-accounting.md`](mint-policy-and-accounting.md), [`stream-sales-and-auctions.md`](stream-sales-and-auctions.md) |
| Metadata, collection state, and finality | metadata renderers and routers, collection metadata, artwork finality, preservation, and dependency components | [`metadata-router-and-renderer.md`](metadata-router-and-renderer.md), [`collection-metadata-contract.md`](collection-metadata-contract.md) |
| Randomness and entropy | `Randomizer*`, lifecycle interfaces, entropy coordinator/provider interfaces | [`stream-entropy-coordinator.md`](stream-entropy-coordinator.md), [`stream-entropy-providers.md`](stream-entropy-providers.md) |
| Modules and registries | module, mint-module, dependency, asset-policy, and compatibility registries/adapters | [`stream-long-term-architecture.md`](stream-long-term-architecture.md), [`launch-conformance-matrix.md`](launch-conformance-matrix.md) |

The protocol specifications own intended permanent and replaceable semantics.
The current source tree may contain transitional, rehearsal, compatibility, or
non-release surfaces that do not conform to the final target yet.

## Authoritative Inventories

Use these artifacts instead of maintaining manual contract lists:

- [`release-artifacts/contracts.json`](../release-artifacts/contracts.json):
  release-tracked production contract catalog and runtime-size policy.
- [`release-artifacts/stream-core-permanent-interface.json`](../release-artifacts/stream-core-permanent-interface.json):
  pre-genesis permanent Core interface target.
- [`release-artifacts/latest/protocol-surface-report.json`](../release-artifacts/latest/protocol-surface-report.json):
  generated public functions, events, custom errors, hashes, and sizes.
- [`release-artifacts/latest/interface-ids.json`](../release-artifacts/latest/interface-ids.json):
  generated interface identifiers.
- [`release-artifacts/latest/event-topic-catalog.json`](../release-artifacts/latest/event-topic-catalog.json):
  generated event signatures and topics.
- [`release-artifacts/latest/custom-error-catalog.json`](../release-artifacts/latest/custom-error-catalog.json):
  generated release-relevant error surface.
- [`release-artifacts/baselines/v0.1.0/natspec-coverage.json`](../release-artifacts/baselines/v0.1.0/natspec-coverage.json):
  checked documentation coverage for the release surface.

[`protocol-surface.md`](protocol-surface.md) explains how these generated
surfaces relate and what they do not prove.

## Finding Code And Coverage

Useful read-only searches:

```bash
rg -n "^(abstract )?(contract|interface|library) " smart-contracts
rg -n "^import " smart-contracts/core/StreamCore.sol
rg -n "ContractOrFunctionName" smart-contracts test docs
rg -n "smart-contracts/.+\\.sol" release-artifacts/contracts.json
```

For a public function, event, or error, search the generated protocol surface
report and the tests as well as the declaring source file. Cross-contract
behavior often has focused tests, composition tests, invariant tests, and
release-artifact checks.

## Migration And Drift Guard

Issue #716 moved the former flat source tree once as a dedicated,
behavior-neutral migration. The move changed imports, compiler source
identifiers, source-verification inputs, release manifests, checksums,
baselines, documentation links, and reviewer paths without changing protocol
logic.

Therefore:

- keep new Solidity sources inside the reviewed hierarchy; the checker permits
  approved nested additions but the historical 120-row migration map itself
  must not be edited;
- do not reorganize paths again as opportunistic cleanup;
- keep vendored files under the provenance and formatting policy in
  [`vendored-libraries.md`](vendored-libraries.md);
- run `python scripts/test_solidity_source_layout.py`,
  `python scripts/test_solidity_layout_equivalence.py`, and
  `python scripts/check_solidity_source_layout.py` after path changes;
- validate the immutable historical receipt in permanent checks with
  `python scripts/check_solidity_layout_equivalence.py --check-receipt`;
- use `python scripts/check_solidity_layout_equivalence.py --check-source` only
  when explicitly recomputing the completed migration proof against its fixed
  base, because ordinary later source edits are outside that receipt lifecycle;
  and
- update generated artifacts from their generators rather than editing them by
  hand.

The equivalence checker has no implicit mode. Historical receipt generation is
available only through `--generate`, and that mode requires `--before-out`,
`--after-out`, `--before-release-out`, and `--after-release-out` together before
it can write either the default receipt or an explicit `--output`. The output
must resolve inside the repository checkout; absolute external paths and
repository-escaping paths are rejected before migration or artifact inputs are
read. Bare or partial generation invocations fail without writing.

The equivalence receipt at
`release-artifacts/evidence/solidity-layout-equivalence.json` records both the
exact normalized source/compiler-input match and the raw compiler-output delta.
Solidity 0.8.19 via-IR changes internal function ordering and jump destinations
when source identities move, so the receipt deliberately does not claim raw
byte-for-byte initcode or runtime equality. It instead requires exact source
semantics after import resolution plus exact ABI, method-identifier, event,
error, and storage-layout surfaces, and reports every raw bytecode mismatch for
review.

## Validation

Start with the focused tests for the changed component. For Solidity behavior
changes, broaden validation according to [`tooling.md`](tooling.md) and the
repository contribution guide:

```bash
forge build
forge test -vvv
make check
```

On Windows, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
```
