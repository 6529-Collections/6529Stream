# Metadata Rendering

This document is the metadata rendering, cache, animation sandbox, and
marketplace integration guide for 6529Stream and completes the current
`INT-006` local documentation slice. It is for React, mobile, Electron,
marketplace, cache, analytics, and indexer teams that need to display token
metadata without treating local evidence as public beta or production proof.

The repository remains a pre-audit local baseline. It is not production-ready
and this document is not a security claim. Local evidence does not replace
fork/testnet/live evidence required for public beta or production release.

Use this with the integration entrypoint in
[`docs/integrations/README.md`](README.md), the event/indexer model in
[`docs/integrations/events-and-indexing.md`](events-and-indexing.md), metadata
policy in [`docs/metadata.md`](../metadata.md), release policy in
[`docs/release-policy.md`](../release-policy.md), release readiness in
[`docs/release-readiness.md`](../release-readiness.md), dependency operations in
[`docs/dependency-operations.md`](../dependency-operations.md), and non-local
evidence intake in
[`docs/non-local-release-evidence.md`](../non-local-release-evidence.md).

## Maturity And Scope

This guide covers:

- token metadata states and expected display/cache behavior;
- `tokenURI` and schema-versioned on-chain JSON behavior;
- ERC-7572-style contract-level metadata through the release-tracked
  `StreamContractMetadata` adapter;
- ERC-4906 `MetadataUpdate` and `BatchMetadataUpdate` cache invalidation;
- `ContractURIUpdated` cache invalidation for contract-level metadata;
- intentional non-emissions on mint-only and burn paths;
- randomizer pending, stale, failed, retry-failed, and final states;
- freeze, burn, dependency pin, dependency deprecation, and release-artifact
  refresh boundaries;
- browser, mobile, and Electron animation sandbox expectations;
- marketplace compatibility caveats; and
- validation commands for docs, fixtures, browser sandbox checks, and release
  artifact drift checks.

This guide does not claim:

- reviewed production deployment addresses;
- completed external audit evidence;
- live marketplace display evidence;
- live indexer replay evidence;
- public-beta approval;
- production metadata-browser evidence; or
- final frontend, mobile, Electron, or marketplace implementation readiness.

The exact public beta and production blockers remain tracked by
[`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json),
[`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json),
[`docs/public-beta-evidence.md`](../public-beta-evidence.md), and
[`docs/non-local-release-evidence.md`](../non-local-release-evidence.md).
These are the current public-beta evidence sources for metadata-browser and
marketplace readiness.

## Source Of Truth

Use checked docs, committed fixtures, generated release artifacts, and tests
rather than hand-maintained metadata snippets.

| Need | Source of truth | Integration note |
| --- | --- | --- |
| Integration entrypoint | [`docs/integrations/README.md`](README.md) | Starts artifact, address, ABI, event, metadata, and flow discovery |
| Metadata policy | [`docs/metadata.md`](../metadata.md) | Current schema, URI policy, size limits, UTF-8 policy, ERC-4906, burn, freeze, dependency, and browser sandbox behavior |
| Event/indexer model | [`docs/integrations/events-and-indexing.md`](events-and-indexing.md) | Event subscriptions, read-after-event calls, confirmation/reorg policy, and event/read gaps |
| Fixed-price flow | [`docs/integrations/contract-flows.md`](contract-flows.md) | Mint-time metadata and randomizer expectations |
| Auction flow | [`docs/integrations/auction-flows.md`](auction-flows.md) | Auction display states before final ownership |
| Wallet/signature guide | [`docs/integrations/wallets-and-signatures.md`](wallets-and-signatures.md) | Signing boundaries before metadata-affecting mints |
| Release readiness | [`docs/release-readiness.md`](../release-readiness.md) | Current launch blocker dashboard |
| Release policy | [`docs/release-policy.md`](../release-policy.md) | Metadata schema and event changes are release-impacting |
| Dependency operations | [`docs/dependency-operations.md`](../dependency-operations.md) | Dependency source packaging, migration, and source retention |
| Randomizer operations | [`docs/randomizer-operations.md`](../randomizer-operations.md) | Provider, funding, lifecycle, stale/failure/retry evidence |
| Non-local evidence | [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md) | Fork/testnet/live retained evidence requirements |
| Public beta evidence | [`docs/public-beta-evidence.md`](../public-beta-evidence.md) | Evidence status and blocker posture |
| Risk register | [`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json) | Generated metadata/marketplace blocker source |
| Release manifest | [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json) | Generated source-of-truth manifest |
| Release checksums | [`release-artifacts/latest/release-checksums.json`](../../release-artifacts/latest/release-checksums.json), [`release-artifacts/latest/SHA256SUMS`](../../release-artifacts/latest/SHA256SUMS) | Signable checksum bundle |
| Event topic catalog | [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json) | Metadata event signature source |
| ABI checksums | [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json) | ABI/bytecode checksum source |
| Interface IDs | [`release-artifacts/latest/interface-ids.json`](../../release-artifacts/latest/interface-ids.json) | ERC-4906 support lookup |
| Core metadata contract | [`smart-contracts/StreamCore.sol`](../../smart-contracts/StreamCore.sol) | `tokenURI`, metadata state, ERC-4906, burn, freeze, and dependency pins |
| Contract metadata adapter | [`smart-contracts/StreamContractMetadata.sol`](../../smart-contracts/StreamContractMetadata.sol) | ERC-7572-style `contractURI()`, `ContractURIUpdated`, URI hash, admin authority, and core address binding |
| Metadata renderer | [`smart-contracts/StreamMetadataRenderer.sol`](../../smart-contracts/StreamMetadataRenderer.sol) | JSON escaping, URI policy, UTF-8 policy, and animation wrapper behavior |
| Randomizer lifecycle | [`smart-contracts/StreamRandomizerLifecycle.sol`](../../smart-contracts/StreamRandomizerLifecycle.sol) | Pending/stale/failed/final request state |
| Dependency registry | [`smart-contracts/DependencyRegistry.sol`](../../smart-contracts/DependencyRegistry.sol) | Versioned dependency bytes, content hashes, and deprecation |
| ERC-4906 interface | [`smart-contracts/IERC4906.sol`](../../smart-contracts/IERC4906.sol) | Metadata update event interface |
| ERC-7572-style interface | [`smart-contracts/IERC7572.sol`](../../smart-contracts/IERC7572.sol) | Contract-level metadata interface used by `StreamContractMetadata` |
| Stream contract metadata interface | [`smart-contracts/IStreamContractMetadata.sol`](../../smart-contracts/IStreamContractMetadata.sol) | Adapter-specific views for core/admin/URI hash binding |
| Golden fixtures | [`test/fixtures/metadata/onchain-pending-schema-v1-token-uri.txt`](../../test/fixtures/metadata/onchain-pending-schema-v1-token-uri.txt), [`test/fixtures/metadata/onchain-stale-schema-v1-token-uri.txt`](../../test/fixtures/metadata/onchain-stale-schema-v1-token-uri.txt), [`test/fixtures/metadata/onchain-failed-schema-v1-token-uri.txt`](../../test/fixtures/metadata/onchain-failed-schema-v1-token-uri.txt), [`test/fixtures/metadata/onchain-final-schema-v1-token-uri.txt`](../../test/fixtures/metadata/onchain-final-schema-v1-token-uri.txt) | Current on-chain JSON examples |
| Off-chain fixtures | [`test/fixtures/metadata/offchain-pending-token-uri.txt`](../../test/fixtures/metadata/offchain-pending-token-uri.txt), [`test/fixtures/metadata/offchain-stale-token-uri.txt`](../../test/fixtures/metadata/offchain-stale-token-uri.txt), [`test/fixtures/metadata/offchain-failed-token-uri.txt`](../../test/fixtures/metadata/offchain-failed-token-uri.txt), [`test/fixtures/metadata/offchain-final-token-uri.txt`](../../test/fixtures/metadata/offchain-final-token-uri.txt) | Current off-chain URI examples |
| Fixture tests | [`test/StreamMetadataGolden.t.sol`](../../test/StreamMetadataGolden.t.sol), [`scripts/check_metadata_fixtures.py`](../../scripts/check_metadata_fixtures.py), [`scripts/test_metadata_fixtures.py`](../../scripts/test_metadata_fixtures.py) | Golden output and fixture policy checks |
| Browser sandbox tests | [`scripts/check_metadata_browser_sandbox.py`](../../scripts/check_metadata_browser_sandbox.py), [`scripts/test_metadata_browser_sandbox.py`](../../scripts/test_metadata_browser_sandbox.py), [`scripts/check_rehearsal_metadata_browser_sandbox.py`](../../scripts/check_rehearsal_metadata_browser_sandbox.py), [`scripts/test_rehearsal_metadata_browser_sandbox.py`](../../scripts/test_rehearsal_metadata_browser_sandbox.py) | Local browser execution checks |
| Metadata behavior tests | [`test/StreamMetadataEvents.t.sol`](../../test/StreamMetadataEvents.t.sol), [`test/StreamContractMetadata.t.sol`](../../test/StreamContractMetadata.t.sol), [`test/StreamMetadataFreeze.t.sol`](../../test/StreamMetadataFreeze.t.sol), [`test/StreamCoreBurn.t.sol`](../../test/StreamCoreBurn.t.sol), [`test/StreamRandomizerLifecycle.t.sol`](../../test/StreamRandomizerLifecycle.t.sol), [`test/StreamRandomizerRetry.t.sol`](../../test/StreamRandomizerRetry.t.sol), [`test/StreamDependencyRegistry.t.sol`](../../test/StreamDependencyRegistry.t.sol) | Current event/state behavior |
| Future public-beta template | [`release-artifacts/evidence/public-beta-templates/fork-testnet-metadata-browser-evidence-template.json`](../../release-artifacts/evidence/public-beta-templates/fork-testnet-metadata-browser-evidence-template.json) | Template only, not completed evidence |

Raw ABIs under ignored `out/` are local build products. For committed review,
use the generated release artifacts and the checked docs above.

## Metadata State Model

Product clients should model metadata as a state machine, not as a single URL.

| State | Primary signal | Display/cache behavior |
| --- | --- | --- |
| `not_minted` | `ownerOf`, `tokenURI`, or collection range says token does not exist | Do not display token metadata; show unavailable or pre-mint UI |
| `pending` | `tokenMetadataState(tokenId) == pending` or pending fixture/URI | Show pending art/state; cache briefly; expect randomizer update |
| `stale` | lifecycle-aware randomizer reports stale while token hash is unset | Show stale/randomness-delayed state; surface recovery/monitoring path |
| `failed` | randomizer reports `FailedPostProcessing` while token hash is unset | Show failed-processing state; expect retry or operator intervention |
| `retry_failed` | retry failure event/request state indicates retry did not complete | Show failed-processing state with retry-failed detail if product UI exposes it |
| `final` | nonzero token hash or `metadata_state: "final"` | Show final art; cache until invalidated by ERC-4906/protocol events |
| `frozen` | `CollectionFrozen` and freeze reads | Treat live token output and burn count as release-critical permanent state |
| `burned` | ERC-721 transfer-to-zero plus `TokenBurned` / burn reads | Remove live metadata; retain audit-only state where useful |
| `dependency_pinned` | `DependencyVersionPinned` / collection dependency reads | Render from pinned registry/key/version/content hash |
| `dependency_deprecated` | dependency registry deprecation event/read | Do not assume token output changed; warn operators if collection uses deprecated source |
| `cache_stale` | update event, release-artifact change, or reconciliation mismatch | Re-read `tokenURI` and refresh derived JSON/render caches |

`pending`, `stale`, `failed`, and `final` are current on-chain JSON
`metadata_state` values. `retry_failed`, `frozen`, `burned`,
`dependency_pinned`, `dependency_deprecated`, and `cache_stale` are product and
indexer states derived from protocol events, reads, and release artifacts.

## TokenURI Behavior

Off-chain metadata returns URI strings:

- pending randomness: `collectionBaseURI + "pending"`;
- stale randomness: `collectionBaseURI + "stale"`;
- failed post-processing: `collectionBaseURI + "failed"`; and
- final randomness: `collectionBaseURI + tokenId`.

The contract performs raw string concatenation. Operators must include the
desired slash or path separator in `collectionBaseURI`.

On-chain metadata returns:

```text
data:application/json;base64,<base64-json>
```

Current on-chain JSON includes:

- `metadata_schema_version`;
- `metadata_state`;
- `name`;
- `description`;
- `image`;
- `attributes`; and
- `animation_url` for final on-chain metadata only.

Clients should treat `metadata_schema_version` as part of cache identity.
Schema changes are release-impacting and should be covered by release policy,
golden fixtures, and release manifest/checksum updates.

## Contract-Level Metadata

Contract-level metadata is exposed by `StreamContractMetadata`, not by
`StreamCore`. The satellite/read-adapter is release-tracked in address books
and manifests and returns an ERC-7572-style `contractURI()` plus a
`contractURIHash()` view. It also binds itself to the canonical core and admin
contracts through
`streamCore()` and `adminsContract()`.

The current adapter stores a content URI, not inline JSON. Accepted contract
metadata URI schemes are `https://`, `ipfs://`, and `ar://`; unsafe, empty,
oversized, whitespace-bearing, control-character, and invalid UTF-8 values are
rejected before storage. `updateContractURI` follows the existing
target-scoped function-admin/global-admin model and is blocked while the
`METADATA_MUTATION` pause domain is active. `updateAdminContract` is also
authorized by the current admin contract and blocked by the same pause before
the adapter can bind to a replacement admin contract.

Subscribe to `ContractURIUpdated()` from the adapter address and then re-read
`contractURI()`, `contractURIHash()`, `streamCore()`, and `adminsContract()`.
Cache keys for contract-level metadata should include chain ID, adapter
address, core address, deployment manifest hash, release manifest hash, and
`contractURIHash()`.
`contractURIHash()` is `keccak256(bytes(contractURI()))` over the exact stored
URI bytes; clients should not normalize the URI before comparing hashes.

This is not yet proof that marketplaces will discover contract-level metadata
from the ERC-721 address. Clients that rely on OpenSea, Reservoir, Blur,
Manifold, wallet, or aggregator behavior must retain fork/testnet/live
evidence showing the exact integration path they use. Until that evidence
exists, treat the adapter as a first-party release/integration source of truth,
not a universal marketplace-discovery guarantee.

## JSON And Fixture Expectations

The committed fixtures are characterization fixtures for the local baseline,
not a final marketplace schema promise. They still matter because they lock the
current output shape.

Fixture checks validate:

- data URI structure;
- base64 decoding;
- strict UTF-8;
- JSON parseability;
- `metadata_schema_version`;
- `metadata_state`;
- allowed content URI schemes;
- allowed script URI schemes;
- semantic `attributes` fragments; and
- final `animation_url` HTML wrapper/script boundaries.

Frontends should not copy fixture JSON into product constants. Instead, use
fixtures to understand current shape and keep runtime parsing tolerant of
future explicitly versioned schema changes.

## ERC-4906 Cache Invalidation

`StreamCore` supports ERC-4906 through `supportsInterface(0x49064906)`.
Indexers and caches should subscribe to:

- `MetadataUpdate(tokenId)`;
- `BatchMetadataUpdate(fromTokenId, toTokenId)`;
- `CollectionFrozen`;
- `DependencyVersionPinned`;
- `DependencyVersionCreated`;
- `DependencyVersionDeprecated`;
- `TokenBurned`; and
- ERC-721 transfer-to-zero.

ERC-4906 events are cache invalidation signals. They do not prove JSON
validity, browser render success, marketplace ingestion, CDN purge, or
production readiness.

The current contract intentionally does not emit ERC-4906 merely because a
token is minted. Burn also does not emit ERC-4906; use ERC-721 transfer-to-zero
and `TokenBurned(collectionId, tokenId, operator, owner)` as the live-token
metadata removal signal.
In short: the current policy is no mint-only ERC-4906 and no burn ERC-4906.

`CollectionFrozen` records permanence state and manifest data but does not
change `tokenURI` bytes by itself. Dependency version creation or deprecation
does not change output for collections pinned to an earlier version.
`ContractURIUpdated` invalidates contract-level metadata only; it does not
imply token JSON changed and should not be treated as an ERC-4906 event.

## Randomness And Retry States

For randomness-aware rendering:

1. Start as `pending` after mint when token hash is unset.
2. Move to `final` after a valid randomizer fulfillment writes a nonzero hash.
3. Move to `stale` when the randomizer marks the request stale and the token
   hash remains unset.
4. Move to `failed` when post-processing fails and the token hash remains
   unset.
5. Keep `failed` or expose `retry_failed` when retry attempts fail.
6. Re-read `tokenURI` and metadata state after fulfillment, stale, failed, or
   retry events.

If lifecycle views are unsupported, malformed, or unavailable, current metadata
falls back to `pending` while token hash is unset. A nonzero token hash wins and
reports `final`.

## Freeze, Burn, And Dependency States

Freeze:

- blocks metadata-significant writes for the collection;
- records freeze manifest and final supply state;
- does not by itself emit ERC-4906;
- does not change existing `tokenURI` bytes; and
- should trigger product UI to show permanence/freeze status.

Burn:

- emits ERC-721 transfer-to-zero and `TokenBurned`;
- makes `ownerOf`, `tokenURI`, and `tokenMetadataState` unavailable;
- keeps selected audit state such as burn count and retained hash state;
- does not emit ERC-4906; and
- is terminal for the burned token ID.

Dependencies:

- collections pin dependency registry address, key, version, and content hash;
- later dependency versions do not affect pinned collections until explicit
  repin;
- dependency deprecation should warn operators but does not automatically alter
  output; and
- release dependency artifact packaging is the source for audit/replay work.

## Animation Sandbox

Final on-chain metadata can include executable HTML in `animation_url`.
Treat it as untrusted artist/dependency code.

Browser products should render animation HTML in an iframe sandbox with script
execution allowed only where needed. The local browser checker uses
`sandbox="allow-scripts"`, stubs the expected dependency request, rejects
unexpected outbound HTTP(S) requests, captures page and console errors, checks
bootstrap token values, and verifies the frame cannot read the parent document.

Electron products must not expose private keys, wallet providers, filesystem
APIs, node integration, shell access, preload secrets, privileged IPC, or
operator credentials to metadata animation frames. Mobile products should use
the platform equivalent of a constrained web view and avoid persistent wallet
secrets inside the renderer context.

The local sandbox checks are not marketplace evidence. They prove committed
fixtures and local deployment-rehearsal output satisfy the current sandbox
policy.

## Cache Strategy

Cache keys should include:

- chain ID;
- contract address;
- contract metadata adapter address and `contractURIHash()` where applicable;
- deployment manifest ID or release manifest hash;
- token ID;
- `metadata_schema_version`;
- collection ID;
- dependency registry address/key/version/content hash;
- token hash where available;
- freeze manifest hash where available; and
- relevant release artifact checksums.

Invalidate or refresh after:

- `MetadataUpdate`;
- `BatchMetadataUpdate`;
- `CollectionFrozen`;
- `ContractURIUpdated`;
- `DependencyVersionPinned`;
- `TokenBurned`;
- ERC-721 transfer-to-zero;
- randomizer fulfillment/stale/failure/retry events;
- token data, image, attribute, or collection metadata writes that emit
  ERC-4906;
- dependency artifact or release-manifest changes; and
- reconciliation mismatches during indexer rescan.

Use historical reads at the event block where possible. If only latest reads
are available, mark derived metadata as reconciliation-required rather than
pretending the historical order is known.

## Marketplace And Evidence Boundaries

This guide does not prove OpenSea, Reservoir, Blur, Manifold, wallets, mobile
clients, Electron shells, CDN caches, or analytics tools ingest metadata
correctly.

Before public beta or production, retained non-local evidence still needs to
show metadata refresh, animation rendering, marketplace display, royalties or
contract metadata where applicable, transfer/listing or sale paths, event
replay, cache invalidation, and reviewer confirmation without secrets or
unreleased payloads.

The current public-beta blocker row for metadata browser evidence remains
missing until reviewed fork/testnet or live evidence is retained.

## Validation Commands

Run these when editing this guide:

```sh
python scripts/test_metadata_rendering.py
python scripts/check_metadata_rendering.py
python scripts/test_metadata_fixtures.py
python scripts/check_metadata_fixtures.py
python scripts/test_metadata_browser_sandbox.py
python scripts/check_metadata_browser_sandbox.py
python scripts/test_rehearsal_metadata_browser_sandbox.py
python scripts/check_rehearsal_metadata_browser_sandbox.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
```

If release-manifest-tracked docs or scripts changed, regenerate and check the
release manifest, bytecode proof, and checksum bundle.

## Maintenance

Update this guide when any of these change:

- metadata schema version or JSON fields;
- `tokenURI` behavior;
- metadata state values;
- ERC-4906 event emission policy;
- burn, freeze, dependency pin, or dependency deprecation behavior;
- randomizer lifecycle, stale, failed, or retry behavior;
- animation wrapper/sandbox policy;
- metadata fixture or browser-sandbox evidence expectations;
- marketplace evidence requirements; or
- public-beta, marketplace, or live metadata evidence posture.
