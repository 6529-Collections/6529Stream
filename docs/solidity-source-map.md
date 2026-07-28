# Solidity Source Map

The Foundry source root is [`smart-contracts/`](../smart-contracts), configured
by [`foundry.toml`](../foundry.toml). The directory is currently flat, so this
guide provides a stable conceptual map without making source paths part of a
new hierarchy.

This page is a navigation aid. The release contract catalog and generated
surface artifacts, not this prose, are authoritative for the contracts and
interfaces included in a release.

## File Families

| Family | Naming signal | Responsibility |
| --- | --- | --- |
| Protocol implementations | Primarily `Stream*.sol` | First-party state, policy, registries, adapters, and protocol services |
| Protocol interfaces | Primarily `IStream*.sol` | External and cross-contract boundaries implemented by Stream components |
| Standards and provider interfaces | `IERC*.sol`, `IRandomizer.sol`, `IArrng*.sol`, and provider-specific names | ERC surfaces and external randomness/integration boundaries |
| Randomizer adapters | `Randomizer*.sol` and `StreamRandomizerLifecycle.sol` | Provider request, callback, retry, migration, and lifecycle behavior |
| Vendored libraries and bases | OpenZeppelin-style standards and utilities without the `Stream` prefix | Locally retained upstream code governed by [`vendored-libraries.md`](vendored-libraries.md) |
| Historical lineage and compatibility | Legacy or NextGen-named surfaces identified by architecture and release policy | Compatibility or provenance surfaces; presence in the source tree does not make them release targets |

Naming is a search aid, not proof of release scope. Use the machine-readable
catalogs below before treating any file as production, deployed, permanent, or
supported.

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
rg -n "^import " smart-contracts/StreamCore.sol
rg -n "ContractOrFunctionName" smart-contracts test docs
rg -n "smart-contracts/.+\\.sol" release-artifacts/contracts.json
```

For a public function, event, or error, search the generated protocol surface
report and the tests as well as the declaring source file. Cross-contract
behavior often has focused tests, composition tests, invariant tests, and
release-artifact checks.

## Why Paths Should Not Move Casually

Moving files into new subdirectories would improve visual grouping but would
also change imports, compiler source identifiers, source-verification inputs,
release manifests, checksums, baselines, documentation links, and reviewer
history. It may also make a behavior-neutral change look like a large protocol
diff.

Therefore:

- do not reorganize Solidity paths as opportunistic cleanup;
- keep vendored files under the provenance and formatting policy in
  [`vendored-libraries.md`](vendored-libraries.md);
- use a focused, approved migration if source-path organization becomes worth
  the release-evidence churn; and
- update generated artifacts from their generators rather than editing them by
  hand.

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
