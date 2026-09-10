# 6529Stream

`StreamCore` owns NFT identity and ownership; `StreamMintManager` owns mint policy.

6529Stream is a Solidity protocol for NFT collections: a permanent ERC-721 Core
with separate contracts for signed sales, English auctions, artist attribution,
mint accounting, revenue splits, entropy, metadata, royalties, and governance.

The current implementation is **pre-audit and not production-ready**. It supports
the development/testnet flows below; the wider protocol specification includes
features that are still being implemented. See [supported scope](docs/current-stack.md)
and [release readiness](docs/release-readiness.md) before making deployment claims.

## Start developing

Use Foundry **v1.7.1**, Solidity **0.8.19**, and Python **3.12**. Start with
[setup and your first run](docs/first-30-minutes.md), then use the same commands
on Windows, Linux, or macOS:

```text
python scripts/dev.py doctor
python scripts/dev.py build
python scripts/dev.py test
```

These select the current contract profile explicitly. A cold optimized Solidity
build can take tens of minutes; subsequent focused tests reuse its cache.
`python scripts/dev.py check` adds the current code/layout/API checks.
The full release validation is a separate `python scripts/dev.py release` command.

For a paid mint, asynchronous entropy, final artwork, revenue withdrawals, and
NFT transfer against a local Anvil node, follow the
[executable demo](script/current/README.md#local-anvil).

Continue with the [product scenarios](docs/integrations/product-demo.md) to onboard
another artist, buy with ETH or ERC-20, settle an auction and publish a state
export. Applications can use the [TypeScript client](docs/integrations/typescript-client.md)
for typed contract calls, signing payloads and portable snapshots.

## Understand the code

| Task | Start here |
| --- | --- |
| Follow a complete mint or auction | [Current-stack walkthrough](docs/current-stack.md) |
| Understand modules and authority | [Architecture](docs/architecture.md) |
| Find implementations | [Contract source map](smart-contracts/README.md) |
| Import a caller-facing API | [Public interface map](smart-contracts/interfaces/stream/README.md) |
| Build a frontend, indexer, or signing service | [Integration guide](docs/integrations/README.md) |
| Change or review code | [Contributing](CONTRIBUTING.md), [test guide](test/README.md) |
| Deploy or operate a testnet instance | [Current deployment guide](script/current/README.md) |
| Review specifications, evidence, or remaining work | [Documentation index](docs/README.md), [roadmap](ops/ROADMAP.md) |

## Repository layout

| Path | Purpose |
| --- | --- |
| `smart-contracts/core/` | Permanent token ownership, supply, identity, and bounded satellite calls |
| `smart-contracts/domains/` | Protocol implementations grouped by responsibility |
| `smart-contracts/interfaces/stream/` | Domain APIs and smaller caller capabilities |
| `smart-contracts/vendor/` | Retained upstream dependencies and licenses |
| `test/` | Current integration, domain unit, historical regression, and gas tests |
| `script/current/` | Current deployment and genesis planning |
| `scripts/` | Small developer entrypoints and platform runners |
| `packages/stream-client/` | Typed application calls, exact signing payloads and selected-state exports |
| `tools/` | Maintainer Python packages for build, protocol, docs, deployment, release and security |
| `docs/` | Developer guides, integration contracts, specifications, and reference |
| `deployments/`, `release-artifacts/` | Explicit instance evidence and reproducible release outputs |

Current modules and historical modules coexist for regression coverage. The
[legacy reference](docs/reference/legacy-stack/README.md) is clearly separated
from the current integration path; an old `StreamDrops` ABI is not the current
sale adapter. Historical deployment compiler snapshots retain their original
source names and must not be rewritten to match a new checkout.

## Security and release status

Local tests and a working testnet instance do not establish an external audit,
public-beta approval, or production readiness. The full-v1 artist lifecycle,
recovery, and additional protocol work remain in the [backlog](ops/EXECUTION_BACKLOG.md).
The [readiness dashboard](docs/release-readiness.md) tracks audit, signing,
custody, verified deployment, and external operational evidence separately.

Report exploitable vulnerabilities privately through [SECURITY.md](SECURITY.md).
Never commit private keys, RPC credentials, signing secrets, or unredacted private
operational transcripts. See [tooling](docs/tooling.md) for validation commands.
