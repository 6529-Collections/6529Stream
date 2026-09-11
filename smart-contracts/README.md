# Contract source map

Start with the [current-stack walkthrough](../docs/current-stack.md), then
import the [public interfaces](interfaces/stream/README.md) for the domain
you are integrating.

| Directory | Responsibility |
| --- | --- |
| [core](core/StreamCore.sol) | ERC-721 ownership, collection supply, permanent token identity, governed satellite pointers |
| [domains/mint](domains/mint/StreamMintManager.sol) | Signed sale adapters, mint phases, executor permissions, accounting and replay protection |
| [domains/auctions](domains/auctions/StreamEnglishAuctionHouse.sol) | Artist-authorized English auctions, custody, bids, settlement and refunds |
| [domains/artist](domains/artist/StreamCollectionArtistRegistry.sol) | Artist nomination, signed acceptance and permanent collection attribution |
| [domains/entropy](domains/entropy/StreamEntropyCoordinator.sol) | Token/scope registration, external randomness requests and final seeds |
| [domains/metadata](domains/metadata/StreamMetadataRouter.sol) | Collection presentation, token metadata and artwork rendering |
| [domains/revenue](domains/revenue/StreamSplitFactory.sol) | Immutable split profiles, pull withdrawals, asset policies and revenue assignments |
| [domains/governance](domains/governance/StreamGovernanceExecutor.sol) | Scheduled governance, roles, one-time genesis setup, deployment discovery and state-export publication |
| [domains/modules](domains/modules/StreamModuleRegistry.sol) | Canonical registration and eligibility of installed modules |
| Other `domains/` folders | Finality, preservation, dependencies and records; implementation maturity varies by component |
| `interfaces/` | Public protocol, external integration and historical interfaces |
| `libraries/` | Shared Solidity utilities |
| `integrations/` | External service adapters |
| `compatibility/` | Historical compatibility surfaces |
| `vendor/` | Vendored dependencies; keep upstream identity and licensing intact |

The deployable current Core is `core/StreamCore.sol`. The historical Core in
`test/regression/legacy/helpers/LegacyStreamCore.sol` exists to retain earlier regression tests.
Use `test/current/` to prove combinations of the current contracts work
together. Domain tests elsewhere may intentionally substitute neighboring
contracts to isolate behavior.

Keep protocol implementations in their domain, shared caller contracts in
`interfaces/stream/<domain>`, and deployment-only planning in `script/current`. Prefer
one explicit interface per responsibility. New behavior belongs in satellites
unless it must change token ownership, supply, or permanent identity.

The previous mint, auction, and randomizer implementations are isolated in
`domains/mint/legacy/`, `domains/auctions/legacy/`, and
`integrations/randomizers/legacy/`. Their caller interfaces live under
`interfaces/stream/legacy/`. Current mint-module compatibility is separately
named `interfaces/stream/mint/compatibility/`; it does not replace the canonical
module registry in a new deployment.
