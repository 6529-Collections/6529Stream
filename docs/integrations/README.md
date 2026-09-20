# Integrate the current Stream stack

These guides describe the implemented permanent Core stack. It is **pre-audit and
not production-ready**. Verify chain, addresses, source revision and module
configuration before constructing transactions. A local demo is not production
deployment evidence.

| Task | Guide |
| --- | --- |
| Publish original native reference renders and retained runtime evidence | [Native reference render](../guides/native-reference-render.md) |
| Retain and validate exact independent finality manifest bytes | [Finality input manifests](finality-input-manifests.md) |
| Discover the fixed required finality components | [Fixed finality discovery](fixed-finality-discovery.md) |
| Preserve and verify large external runtime objects | [External object archive](../guides/external-object-archive.md) |
| Publish and retrieve retained native collection snapshots | [Native onchain snapshots](native-onchain-snapshots.md) |
| Freeze and serve every original entropy source through one route | [Original entropy source sets](original-entropy-source-sets.md) |
| Validate a published root against current preserved content | [Finality content evidence](finality-content-evidence.md) |
| Derive independent serving families from actual Router sources | [Router evidence provider](finality-router-evidence.md) |
| Discover all coordinators retained at mint for a scope | [Original coordinator inventory](original-coordinator-inventory.md) |
| Read every original coordinator policy for a scope | [Complete original policy evidence](original-coordinator-policy-evidence.md) |
| Consume authenticated artist intent, waiver and interview selections | [Conservation evidence](finality-conservation-evidence.md) |
| Prepare recovery with complete guardian history and veto rights | [Recovery preparation](../architecture/artist-recovery-preparation-v1.md) |
| Encode complete artist intent, waiver and interview records | [Conservation record JSON](conservation-record-json.md) |
| Select original intent/waiver records and preserve interview attribution | [Conservation selection](../architecture/conservation-record-selection-profile.md) |
| Integrate the initial adjudicated identity-recovery profile | [Initial identity recovery](initial-identity-recovery.md) |
| Read a fixed coordinator's original locked collection policy | [Entropy policy evidence](entropy-finality-evidence.md) |
| Preserve configured policies and original provider callers across Coordinator replacement | [Entropy policy import and relay](entropy-policy-import-relay.md) |
| Consume exact current WORK and RIGHTS selections | [Description evidence](finality-description-evidence.md) |
| Authenticate published RELEASE, SEASON and VIEW membership | [Scope membership](../scope-membership.md) |
| Resume the developing artist and reveal authority batch | [Current activation](current-artist-activation.md) |
| Fund reveal requests and settle collection escrow | [Reveal-fee funding](reveal-fee-funding.md) |
| Approve a positive-share primary template through the Artist Safe | [Template economics consent](../artist-template-economics.md) |
| Split primary revenue among the artist, sale poster and accepted collaborators | [Dynamic primary templates](../dynamic-primary-template-commerce.md) |
| Elect and authorize royalties frozen at each prepared mint | [Artist snapshot consent](../artist-snapshot-royalty-consent.md) and [prepared snapshot decision](../adr/0044-prepared-royalty-snapshot-consent.md) |
| Record artist approval of exact sale terms | [Sale-parameter consent](sale-parameter-consent.md) |
| Execute canonical signed or public native fixed/open sales | [Canonical immediate sales](native-immediate-sales.md) |
| Execute canonical free and pay-what-you-want native claims | [Canonical claims](native-claim-sales.md) |
| Integrate the closed signed/public ERC20 Dutch recorder entries | [Dutch recorder](erc20-dutch-recorder.md) |
| Integrate the new native/ERC-20 funding boundary | [Sale funding](sale-funding.md) |
| Prepare a token and settle its native payment atomically | [Prepared native settlement](prepared-native-settlement.md) |
| Accept a signed native offer for a new token or selected work | [Native primary offers](native-primary-offers.md) |
| Accept a signed ERC20 offer through the sole payer verifier | [ERC20 primary offers](erc20-primary-offers.md) |
| Burn Stream tokens and pay ERC20 atomically for one new token | [ERC20 paid burn-to-mint](erc20-burn-to-mint.md) |
| Integrate auction V2 and retained proceeds rights | [Auction funding](auction-funding.md) |
| Mint and pay atomically at native auction settlement | [Native deferred auctions](native-deferred-auctions.md) |
| Deploy and activate the native recorder and auction house through a Safe root | [Native commerce deployment](native-commerce-deployment.md) |
| Build typed calls, signing payloads and portable snapshots | [TypeScript client](typescript-client.md) |
| Onboard another artist and exercise sales and auctions | [Executable product scenarios](product-demo.md) |
| Finish a collection and verify its portable artwork | [Collection completion and collector package](collector-package.md) |
| Buy one NFT with native ETH | [Fixed-price purchase](contract-flows.md) |
| Buy with an ERC-20 and payer consent | [ERC-20 sales](erc20-sales.md) |
| Discover, publish or challenge a state export | [State exports](state-exports.md) |
| Build both signatures | [Wallets and EIP-712](wallets-and-signatures.md) |
| Review all-CALL Safe atomicity and its current execution boundary | [Current Safe batches](current-safe-batches.md) |
| Review actual governed mint import and pointer cutover coverage | [Current mint continuity acceptance](current-mint-continuity-acceptance.md) |
| Approve fixed-profile economics and freeze royalties on the modular artist line | [Artist economics](artist-economics.md) |
| Integrate developing content consent and defensive artist freezes | [Artist content](artist-content.md) |
| Register and discover immutable split profiles on the new factory line | [Split profiles](split-profiles.md) |
| Authorize split releases and handle deprecated assets | [Split-wallet releases](split-wallet-releases.md) |
| Create, bid on and settle an auction | [English auctions](auction-flows.md) |
| Index purchases and state changes | [Events and indexing](events-and-indexing.md) |
| Display pending and final artwork | [Metadata and rendering](metadata-rendering.md) |
| Lock artwork presentation while retaining live artist authority | [Stable router presentation](stable-router-presentation.md) |
| Index completed mints and compute exact onchain content roots | [Token inventory](collection-token-inventory.md) and [content checkpoints](onchain-content-checkpoints.md) |
| Verify the preserved list behind a content root | [Content leaf manifests](content-leaf-manifests.md) |
| Adopt a verified root with artist consent and governed publisher authority | [Content-root publication](content-root-publication.md) |
| Publish full-byte collection records and recover attributed history | [Developing metadata record host](metadata-records.md) |
| Append institutional records as the current NFT owner | [Owner records](owner-records.md) |
| Publish signed general claims and exact identity notarizations | [General attestations](general-attestations.md) |
| Preserve native Artist attribution and original general claims offline | [Museum native attribution](../museum-native-attribution.md) |
| Encode complete steward designations and recovery responses | [Owner notice JSON](owner-notice-json.md) |
| Authenticate the exact scheduled recovery action before notice | [Recovery action evidence](owner-recovery-action-reads.md) |
| Prepare complete delivery claims and open the owner response window | [Owner recovery notices](owner-recovery-notices.md) |
| Read complete evidence without copying long registration URIs | [Bounded record reads](bounded-record-reads.md) |
| Publish an artist or curatorial description under one record type | [Work-description authority](work-description-authority.md) |
| Select an authenticated current WORK description | [Work-record selection](work-record-selection.md) |
| Encode the complete typed description and its format catalog | [Work-description JSON profile](../work-description-json-profile.md) |
| Reconstruct and validate the complete supported rights JSON bytes | [Rights interpretation profile](rights-json-profile.md) |
| Select a current rights statement and preserve its original evidence | [Rights selection design](../adr/0042-current-rights-record-selection.md) |
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
