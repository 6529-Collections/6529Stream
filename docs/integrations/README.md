# Integrate the current Stream stack

These guides describe the implemented permanent Core stack. It is **pre-audit and
not production-ready**. Verify chain, addresses, source revision and module
configuration before constructing transactions. A local demo is not production
deployment evidence.

| Task | Guide |
| --- | --- |
| Resume the developing modular artist authority batch | [Current artist activation](current-artist-activation.md) |
| Integrate the new native/ERC-20 funding boundary | [Sale funding](sale-funding.md) |
| Integrate auction V2 and retained proceeds rights | [Auction funding](auction-funding.md) |
| Build typed calls, signing payloads and portable snapshots | [TypeScript client](typescript-client.md) |
| Onboard another artist and exercise sales and auctions | [Executable product scenarios](product-demo.md) |
| Finish a collection and verify its portable artwork | [Collection completion and collector package](collector-package.md) |
| Buy one NFT with native ETH | [Fixed-price purchase](contract-flows.md) |
| Buy with an ERC-20 and payer consent | [ERC-20 sales](erc20-sales.md) |
| Discover, publish or challenge a state export | [State exports](state-exports.md) |
| Build both signatures | [Wallets and EIP-712](wallets-and-signatures.md) |
| Approve fixed-profile economics and freeze royalties on the modular artist line | [Artist economics](artist-economics.md) |
| Integrate developing content consent and defensive artist freezes | [Artist content](artist-content.md) |
| Register and discover immutable split profiles on the new factory line | [Split profiles](split-profiles.md) |
| Authorize split releases and handle deprecated assets | [Split-wallet releases](split-wallet-releases.md) |
| Create, bid on and settle an auction | [English auctions](auction-flows.md) |
| Index purchases and state changes | [Events and indexing](events-and-indexing.md) |
| Display pending and final artwork | [Metadata and rendering](metadata-rendering.md) |
| Withdraw proceeds or bid refunds | [Payments and withdrawals](withdrawals-and-credits.md) |
| Run the complete flow locally | [Current deployment demo](../../script/current/README.md) |

The current purchase path is `StreamFixedPriceSaleAdapter.buy`, followed by
`StreamMintManager` and `StreamCore`. `StreamDrops.mintDrop` and
`DropAuthorization` belong to the [legacy stack](../reference/legacy-stack/README.md).
Their ABIs and signing schemas are not interchangeable with this stack.

Start from the [caller interface map](../../smart-contracts/interfaces/stream/README.md).
Use the exact ABI from your build or deployment's retained compiler export;
`release-artifacts/latest` also contains earlier reference surfaces and is not a
universal current address book. Inspect [deployment records](../../deployments/README.md)
for each retained deployment's identity and limitations.

The current stack supports signed native and ERC-20 sales, governance-hosted
state-export publication, English auctions, immutable split
wallets, accepted collection attribution, mint-time entropy binding and onchain
metadata. Configured Sepolia uses Chainlink VRF; the local demo uses explicitly
insecure development entropy. Full Artist V2, finality and broader revenue-routing
specifications remain separate work; see [status](../status.md) and
[readiness](../release-readiness.md).

The [React](../reference/legacy-stack/integrations/frontend-reference-architecture.md), [mobile](../reference/legacy-stack/integrations/mobile-walletconnect.md),
[Electron](../reference/legacy-stack/integrations/electron-security-wallets.md) and [operator UI](../reference/legacy-stack/integrations/operator-admin-ui.md)
notes contain legacy API examples alongside useful platform considerations.
Their scope notices identify those boundaries. Report integration mismatches with
public addresses, chain ID, source revision and reproducible input; never include
private keys or RPC credentials. Report exploitable vulnerabilities privately under
[SECURITY.md](../../SECURITY.md).
