# Royalty Policy

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins. For
target royalty behavior this document is superseded by
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md).


This document records the `ONE-003` royalty philosophy and enforcement boundary
for the current 6529Stream local baseline.

The repository is a pre-audit local baseline. It is not production-ready and
this document is not a security claim. Local evidence does not replace
fork/testnet/live evidence for public beta or production release.

## Maturity And Scope

This is a docs-first policy record for the current release line. It explains how
royalties are disclosed today, what the contracts intentionally do not enforce,
and what frontend, marketplace, indexer, operator, and governance teams may
claim from the committed local baseline.

This document does not add a maintained marketplace integration, does not prove
OpenSea, Reservoir, Blur, Manifold, or any other marketplace honors royalties,
does not create creator-fee enforcement, and does not change contract bytecode.
The permanent `StreamCore` target now carries a bounded resolver-backed
ERC-2981 read without adding royalty-payment enforcement. The concrete #670
royalty interface row is still unresolved, so the resolver pointer cannot be
installed in a conforming genesis configuration yet. Future enforcement
features still require a separate design decision, size-budget review,
ABI/event review, and release artifact update. Any future StreamCore
size-budget exception for royalty behavior must be explicitly accepted before
code is added.

## Source Of Truth

Use the following tracked sources before making any royalty claim:

| Need | Source of truth | Notes |
| --- | --- | --- |
| Permanent royalty implementation | [`smart-contracts/core/StreamCore.sol`](../smart-contracts/core/StreamCore.sol), [`smart-contracts/core/StreamCoreExternalReads.sol`](../smart-contracts/core/StreamCoreExternalReads.sol) | Exposes ERC-2981-compatible `royaltyInfo()` through an authenticated, gas-bounded resolver read with a zero-royalty failure tuple |
| Royalty interface | [`smart-contracts/vendor/openzeppelin/IERC2981.sol`](../smart-contracts/vendor/openzeppelin/IERC2981.sol), [`smart-contracts/vendor/openzeppelin/ERC2981.sol`](../smart-contracts/vendor/openzeppelin/ERC2981.sol) | `IERC2981` is used by `StreamCore`; the full vendored helper remains review material |
| Royalty tests | [`test/StreamCorePermanentTarget.t.sol`](../test/StreamCorePermanentTarget.t.sol), [`test/StreamRoyalty.t.sol`](../test/StreamRoyalty.t.sol) | The permanent-target test rejects installation while #670's concrete interface row is unresolved; the retained legacy characterization covers the historical fixed receiver and 690-bps math |
| Metadata boundary | [`docs/metadata.md`](metadata.md), [`docs/integrations/metadata-rendering.md`](integrations/metadata-rendering.md) | Metadata and marketplace display evidence are separate from royalty enforcement |
| Integration entrypoint | [`docs/integrations/README.md`](integrations/README.md) | Routes frontend, mobile, Electron, indexer, operator UI, and backend signing-service teams |
| Event and indexer context | [`docs/integrations/events-and-indexing.md`](integrations/events-and-indexing.md) | Event replay and indexer reconstruction do not prove marketplace royalty payment |
| Marketplace/indexer evidence | [`docs/integrations/marketplace-indexer-evidence.md`](integrations/marketplace-indexer-evidence.md) | `ONE-005` retained marketplace/indexer evidence requirements for royalty display, platform coverage, event replay, and cache invalidation |
| Wallet and signature context | [`docs/integrations/wallets-and-signatures.md`](integrations/wallets-and-signatures.md) | Signing evidence is separate from sale proceeds and secondary-market royalty behavior |
| Provenance context | [`docs/provenance-manifests.md`](provenance-manifests.md) | Artist/story/authenticity provenance is not payment enforcement |
| Release readiness | [`docs/release-readiness.md`](release-readiness.md), [`docs/public-beta-evidence.md`](public-beta-evidence.md), [`docs/non-local-release-evidence.md`](non-local-release-evidence.md) | Public beta and production claims need reviewed retained evidence |
| Release policy | [`docs/release-policy.md`](release-policy.md) | Changed royalty behavior is release-impacting and may be breaking |
| Upgrade and redeployment | [`docs/adr/0007-upgrade-redeployment.md`](adr/0007-upgrade-redeployment.md) | Changed royalty behavior belongs in versioned release/redeployment planning |
| Accepted revenue and royalty specification target | [`docs/adr/0008-revenue-splits-and-royalty-resolver.md`](adr/0008-revenue-splits-and-royalty-resolver.md), [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) | Accepted specification target for arbitrary split profiles, primary-sale templates, split-wallet royalty receivers, and Core-native resolver-backed ERC-2981 from the genesis deployment |
| Release artifacts | [`release-artifacts/contracts.json`](../release-artifacts/contracts.json), [`release-artifacts/latest/release-manifest.json`](../release-artifacts/latest/release-manifest.json), [`release-artifacts/latest/abi-checksums.json`](../release-artifacts/latest/abi-checksums.json), [`release-artifacts/latest/interface-ids.json`](../release-artifacts/latest/interface-ids.json), [`release-artifacts/latest/event-topic-catalog.json`](../release-artifacts/latest/event-topic-catalog.json), [`release-artifacts/latest/risk-register.json`](../release-artifacts/latest/risk-register.json) | Generated artifacts define the reviewed local release surface |

## Current ERC-2981 Behavior

`StreamCore` exposes ERC-2981 royalty disclosure through `IERC2981` and
`royaltyInfo()`. It reports `supportsInterface(0x2a55205a)` for the ERC-2981
interface ID.

Current permanent-target behavior for this release line:

- `royaltyInfo()` reads through the authenticated royalty resolver pointer,
  using governed resolver gas and the shared completion buffer.
- Missing code, insufficient parent gas, a failed read, malformed returndata,
  a zero receiver, zero bps, or bps above `1,000` fails soft to
  `(address(0), 0)`.
- Valid resolver output uses a denominator of `10,000` and overflow-safe
  quotient/remainder math.
- `StreamCore` has no runtime royalty setters, no per-token override, and no
  per-collection override of its own; those values belong to the accepted
  resolver design.
- The concrete #670 royalty interface row remains unresolved. The permanent
  target therefore rejects installation of that pointer rather than claiming
  a deployable royalty configuration.

The retained legacy characterization in `test/StreamRoyalty.t.sol` separately
pins the former fixed default royalty: receiver
`0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377`, `690 basis points`, and
`salePrice * 690 / 10_000`. That historical baseline is not the permanent
Core's resolver implementation and must not be used as candidate evidence.

## Royalty Philosophy

The current product philosophy is royalty disclosure, not payment enforcement.
The protocol should tell wallets, marketplaces, indexers, and collector tools
what royalty information the collection exposes under ERC-2981, while avoiding
claims that the core contracts can force a secondary marketplace to pay it.

For this release line:

- ERC-2981 is the canonical on-chain royalty disclosure mechanism.
- ERC-2981 is encoding and discovery guidance for royalty information, not a
  transfer restriction, sale router, escrow, marketplace adapter, or payment
  accounting system.
- No production-readiness claim depends on marketplaces honoring royalties.
- 6529Stream should preserve permissionless-transfer composability unless a
  future governance decision explicitly accepts the tradeoffs of enforcement.
- Future royalty changes should prefer a versioned release, satellite royalty
  policy contract, or off-core integration layer unless maintainers explicitly
  accept a `StreamCore` size-budget exception.

## Governance And Change Policy

The permanent `StreamCore` has no direct admin function that changes a royalty
receiver, denominator, fee numerator, per-token royalty, or per-collection
royalty. Its authenticated royalty resolver pointer is a governed system
dependency, and its exact interface remains blocked on #670.

Any future change must be treated as release-impacting and reviewed before it is
advertised:

- Changing the default royalty receiver is a governance and release decision.
- Changing `690 basis points` is a governance and release decision.
- Adding per-token override support is a governance, ABI, storage, test, and
  marketplace-display decision.
- Adding per-collection override support is a governance, ABI, storage, test,
  and marketplace-display decision.
- Adding a satellite royalty policy contract requires deployment-manifest,
  address-book, source-verification, integration, and release-manifest updates.
- Adding mutable royalty data requires event, indexer, cache-invalidation,
  admin-ceremony, monitoring, and incident-response coverage.
- Adding royalty enforcement requires an explicit design record that evaluates
  permissionless-transfer composability, wallet/indexer risks, marketplace
  support, admin power, bypass routes, emergency controls, and bytecode cost.

changed royalty behavior is a breaking change when an integrator, marketplace,
or collector tool can observe a different `royaltyInfo()` result, a different
interface surface, a new event signature, a new admin authority, or a new
transfer/listing restriction.

## Enforcement Boundary

ERC-2981 exposes royalty information. It does not enforce secondary-sale
payment.

The current contracts do not include:

- a sale router that forces royalty distribution;
- a transfer validator;
- an operator filter;
- ERC721C-style transfer restriction;
- marketplace allowlist or blocklist enforcement;
- a royalty escrow;
- royalty pull-payment accounting;
- per-marketplace adapter logic;
- event proof that a secondary-sale royalty was paid.

Those exclusions are intentional for this release line. Enforcement would add
governance, composability, integration, audit, and bytecode risk. It would also
require explicit marketplace support assumptions and retained
fork/testnet/live evidence before any public beta or production claim.

## Marketplace Display Guidance

Frontend and marketplace integrations may display the ERC-2981 royalty
information as a local contract read:

1. Confirm the deployed core address from the release manifest and address book.
2. Confirm `supportsInterface(0x2a55205a)` is true.
3. Call `royaltyInfo(tokenId, salePrice)` on `StreamCore`.
4. Display the returned receiver and sale-price-denominated royalty amount as
   disclosure only.
5. Avoid wording that implies payment was enforced, collected, escrowed, or
   guaranteed.

Marketplace support should be treated as external behavior. OpenSea, Reservoir,
Blur, Manifold, wallets, indexers, and aggregator APIs can choose how they
read, display, cache, ignore, or enforce royalty information. Their behavior
must be documented through retained evidence before it appears in public beta
or production release notes.

## Integration Guidance

Integrators should not hardcode royalty assumptions beyond the release they are
building against. They should:

- read `royaltyInfo()` from the deployed core contract;
- treat `IERC2981` as the interface boundary;
- use generated address books, ABI checksums, interface IDs, and the release
  manifest for the target release;
- keep sale-price units consistent with the marketplace or wallet flow;
- keep royalty display separate from token metadata finality, provenance,
  ownership proof, listing state, and payment settlement;
- cache royalty reads with release/address context, not only token ID;
- refresh cached display if a future release adds royalty events or a new
  royalty policy contract;
- document any off-chain marketplace assumptions, API dependencies, or
  aggregator-specific display logic.

Operator UIs should not present a Core-native royalty edit flow for the current
release line because no runtime royalty setter exists in `StreamCore`.

## Evidence And Readiness Boundaries

Local tests and docs prove only the committed local baseline:

- `test/StreamCorePermanentTarget.t.sol` proves unresolved artist and royalty
  pointer interfaces cannot be installed.
- `test/StreamRoyalty.t.sol` proves only the retained legacy fixed-royalty
  characterization.
- The release manifest and ABI checksums prove committed artifact consistency.
- The event topic catalog proves no royalty-payment event exists in the current
  release surface.
- The integration docs describe display boundaries; they do not prove live
  marketplace behavior.

Public beta requires reviewed retained fork/testnet/live evidence for any
marketplace or collector-facing royalty-display claim. Production requires the
same evidence plus normal release signatures, deployed address verification,
explorer verification, and post-audit remediation status.

[`ONE-005`](integrations/marketplace-indexer-evidence.md) owns retained
marketplace/indexer evidence for collector-facing display claims across
OpenSea, Reservoir, Blur, Manifold, or equivalent collector/indexer tooling.
Until that reviewed fork/testnet/live evidence exists, royalty display remains
a local integration boundary and not release readiness proof.

## Testing Strategy

Royalty coverage should stay split across layers:

- Permanent-target Solidity tests cover `supportsInterface(0x2a55205a)` and
  fail-closed installation while the concrete #670 royalty interface row is
  unresolved. Retained legacy tests separately cover the fixed receiver, fixed
  default royalty, arbitrary token IDs, zero sale price, large sale prices, and
  checked overflow behavior.
- Documentation checks cover the non-enforcement boundary, governance policy,
  marketplace display wording, readiness caveats, validation commands, and
  source links.
- The royalty policy checker cross-checks the authenticated royalty resolver
  pointer, governed gas rows, selector preimage, bounded response validation,
  `10_000` denominator, ERC-2981 interface support, unresolved-pointer
  regression, and retained `690`-bps legacy characterization against
  `smart-contracts/core/StreamCore.sol`,
  `smart-contracts/core/StreamCoreExternalReads.sol`,
  `test/StreamCorePermanentTarget.t.sol`, and `test/StreamRoyalty.t.sol`.
- Integration tests that use marketplaces, wallet flows, or indexers belong in
  retained non-local evidence before public beta or production claims.
- If future work adds setter, override, satellite, validator, or enforcement
  behavior, it must add direct happy-path, negative, permission, event,
  migration, ABI, size-budget, and release-artifact tests before merge.

## Validation Commands

Run these focused checks after editing royalty policy or related release docs:

```sh
python scripts/test_royalty_policy.py
python scripts/check_royalty_policy.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update this document when any of the following change:

- `StreamCore.royaltyInfo()` behavior;
- ERC-2981 interface support;
- royalty receiver, fee numerator, or denominator;
- per-token, per-collection, or satellite royalty strategy;
- marketplace display evidence;
- transfer, listing, or sale enforcement strategy;
- release readiness claims that mention royalties;
- integration docs that instruct frontends, marketplaces, indexers, wallets, or
  operator UIs how to display royalty data.

Keep the policy conservative. It should help integrators display royalty data
accurately without weakening the repo's pre-audit and not-production-ready
boundary.
