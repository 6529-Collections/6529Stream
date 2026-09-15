# Documentation

Start with the implementation you will actually run. The current stack is
pre-audit and not production-ready; specifications and historical evidence have
their own scope and must not be read as a list of installed features.

## Develop and integrate

| Need | Guide |
| --- | --- |
| Install tools and run the product | [Setup and first run](first-30-minutes.md) |
| Follow a mint and auction across contracts | [Current-stack walkthrough](current-stack.md) |
| Understand storage, authority, and module boundaries | [Architecture](architecture.md) |
| Find source or a caller capability | [Source map](../smart-contracts/README.md), [interface map](../smart-contracts/interfaces/stream/README.md) |
| Sign, buy, bid, index, withdraw, or render | [Integration guide](integrations/README.md) |
| Use typed calls and export selected state | [TypeScript client](integrations/typescript-client.md) |
| Publish and reconstruct interpretation documents | [Schema registry](schema-registry.md) |
| Publish attributed records and recover their original bytes | [Current metadata records](integrations/metadata-records.md) |
| Bind content roots and inspect finality component hosts | [Finality adapters and content commitments](finality-host-adapters.md) |
| Verify every content leaf against preserved manifest bytes | [Content leaf manifests](integrations/content-leaf-manifests.md) |
| Inventory native artwork dependencies and prove their archival coverage | [Render-critical inventory and archive bundles](guides/preservation-inventory.md) |
| Validate retained Linked Art documents offline | [Museum tooling](../tools/museum/README.md), [validation boundary](museum-linked-art-validation.md) |
| Declare platform works, file attribution claims and inspect corrective binding | [Platform works](guides/artist-platform-works.md) |
| File and answer Artist attribution disputes | [Attribution disputes](artist-attribution-disputes.md) |
| Publish complete independent collection views | [CollectionViews](integrations/collection-views.md) |
| Burn a Stream token and retain a redemption receipt | [Burn redemption](integrations/burn-redemption.md) |
| Recover incident escrow and manage factory/runtime status | [Runtime and escrow recovery](guides/revenue-runtime-escrow-recovery.md) |
| Fund native-sale reveals and claim unused ETH | [Immediate sale payments](native-immediate-reveal.md) |
| Publish test-image records through actual contracts and export four museum formats | [Current media capture](museum-current-media-capture.md) |
| Run a second artist through sales and auctions | [Product scenarios](integrations/product-demo.md) |
| Complete a collection and retain its artwork | [Collector package](integrations/collector-package.md) |
| Choose a command or compiler profile | [Tooling](tooling.md) |
| Add tests or submit a change | [Tests](../test/README.md), [Contributing](../CONTRIBUTING.md) |
| Run local or testnet transactions | [Current deployment guide](../script/current/README.md) |

## Review the protocol and its evidence

| Need | Reference |
| --- | --- |
| Normative target and precedence | [Specification policy](spec-policy.md), [launch architecture](launch-v1-target-architecture.md) |
| Museum records, authority mappings and archival exports | [Museum semantic specification](museum-semantic-mapping.md), [delivery and evidence](../ops/MUSEUM_DELIVERY.md) |
| Decisions and unresolved design work | [ADRs](adr/README.md), [open questions](spec-open-questions.md) |
| Shared feature-by-feature delivery status | [Build, testing, integration and remaining work](../ops/STREAM_FEATURE_STATUS.md) |
| Full-v1 conformance and implementation gaps | [Conformance matrix](launch-conformance-matrix.md), [roadmap](../ops/ROADMAP.md), [backlog](../ops/EXECUTION_BACKLOG.md) |
| Audit scope and reporting | [Audit package](audit-package.md), [threat model](threat-model.md), [SECURITY.md](../SECURITY.md) |
| Release decision | [Readiness](release-readiness.md), [known blockers](known-blockers.md), [external evidence](non-local-release-evidence.md) |
| Reproduce release outputs | [Release workflow](reference/tooling/release-artifacts.md), [artifact guide](../release-artifacts/README.md) |
| Understand earlier modules and fixtures | [Legacy stack reference](reference/legacy-stack/README.md) |

`current-stack.md` and the current integration guides describe the working
product path. Specifications describe the permanent target. Readiness reports
describe accepted evidence. None of those surfaces silently replaces another:
an implemented testnet feature is not necessarily complete full-v1 behavior or
approved production evidence.

Historical compiler inputs and deployed bytecode snapshots under `deployments/`
identify their original build. Their paths are intentionally frozen. Use the
current source/interface maps for new code rather than editing those snapshots.
