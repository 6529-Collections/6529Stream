# Build and integrate the current stack

The current implementation combines the permanent ERC-721 Core with separate
contracts for minting, sales, revenue, entropy, metadata and governance. Start
here for the active implementation. The broader specification and historical
release evidence remain useful references; they describe more than this first
integrated build supports.

The [Sepolia evidence package](../deployments/current/sepolia-2026-09-10/README.md)
provides the deployed addresses, strict client configuration and a completed
native-sale flow using real Chainlink randomness.

## Follow one paid mint

1. Genesis deploys the executor, role registry, canonical module registry,
   Core and product satellites. A committed plan registers modules, installs
   pointers, creates the initial collection and configures its entropy and
   metadata. A separate preparation transaction binds the exact committed
   governance catalog and guardians. Activation executes all product changes
   atomically; its final calls freeze the SystemManifest pointer and seal setup.
   The collection's nominated artist then accepts its attribution, directly
   or through a relayed EIP-712 signature. Acceptance requires no artist gas
   when relayed and cannot be replaced after it is recorded.
2. The mint manager's phase allows the fixed-price sale adapter as an executor.
   Its ledger enforces the configured supply counter and consumed operations.
3. The artist and platform sign the same EIP-712 `SaleAuthorization`. It binds
   the chain and adapter, collection/phase, payer, recipient, artist, immutable
   split profile, token data, mint commitment, policy, price, nonce and deadline.
4. The payer calls `buy` with exact native ETH and both signatures. The adapter
   funds the split wallet before minting through manager → ledger → Core.
   A failing receiver or mint hook rolls the whole transaction back.
5. Core records the token's coordinator at mint and registers its entropy.
   A public or permitted caller requests randomness. The configured provider
   returns the result, and the coordinator commits the token's final seed.
6. `Core.tokenURI` calls the metadata router. The router reads the token's
   original coordinator, so replacing the collection's current pointer does
   not silently change an older token's seed source.
7. Split recipients withdraw through the wallet. NFT transfer and burn use
   Core; burn preserves collection identity and does not replenish minted supply.
   `Core.royaltyInfo` discloses the configured split wallet and secondary-sale
   royalty. Collection settings may override a default or explicitly disable
   royalties; freezing a collection captures its effective default.

## Pay with an ERC-20

The separate `StreamERC20FixedPriceSaleAdapter` registers immutable sale terms
under canonical sale IDs. Platform and artist signatures bind those terms and
each mint. A relayer additionally supplies the payer's pinned `PaymentIntent`;
the literal payer may authorize its own call directly. The adapter checks the
active asset and canonical primary policy, previews manager identities, pulls
exact tokens into the verified split wallet, and mints atomically. Tokens with
transfer taxes, misleading returns or incompatible balance changes are rejected.

The current primary resolver supports fixed-profile collection/default
assignments in this path. Deployment installs the resolver, adapter and mint
phase, then transfers their configuration to governance. ERC-20 asset admission
and sale registration remain explicit configuration steps. See the
[ERC-20 integration guide](integrations/erc20-sales.md) for exact signatures,
allowance, revocation, withdrawals and supported assignment boundaries.

## Publish a state export

The actual governance Executor exposes the locked state-export read interface,
with separate publication and history capabilities. Live export-role holders
append recent canonical block commitments; anyone may challenge them. Forward
supersession links retain every original claim. Core pointer replacement stops
old writes while preserving historical reads. These operations run outside
governance batches. See [state exports](integrations/state-exports.md) for anchor
windows, authority, event schemas and reconstruction boundaries.

## Follow an auction

The artist and platform sign an `AuctionAuthorization` binding the artwork,
mint phase, split profile, reserve, start/end times and bid-extension rules.
The auction house mints the token into its own custody. Bids escrow native
ETH; outbid payers withdraw refund credits independently. Settlement pays the
split wallet and delivers to the winning recipient. A recipient that rejects
the NFT can be corrected by the winner, and an auction without bids can be
claimed by the artist. Pausing creation and bidding leaves refunds and
settlement available.

Read the [interface map](../smart-contracts/interfaces/stream/README.md) for
exact caller types and the [source map](../smart-contracts/README.md) for
implementation ownership.

## Run the product tests

The product suites deploy actual protocol contracts and use a controllable
external randomness provider. They check the paid flow, auction custody and
refunds, rollback across satellites, stale consent, shared lifetime supply,
payment conservation, and governance after genesis:

```bash
FOUNDRY_PROFILE=current forge test -vvv
```

On Windows, set `$env:FOUNDRY_PROFILE = 'current'` before `forge test -vvv`.
The `current` profile selects these integration suites and their shared
compilation settings. Run `make current-stack-check` or the Windows
`scripts/check.ps1 -CurrentStack` wrapper to include artifact and layout checks.
Use the default profile for the broader regression suite before release.

The focused domain suites are `StreamFixedPriceSaleAdapter`,
`StreamEnglishAuctionHouse`, `StreamMintCanonicalRegistry`, `StreamEntropyMetadata`,
`StreamCollectionArtistRegistry`, `StreamRoyaltyResolver`,
`StreamGenesisInitializer`, `StreamSystemManifest`, `StreamERC20FixedPriceSaleAdapter`
and `StreamPaymentIntentVerifier`. Keep their narrow
behavior checks while extending the product test for newly integrated flows.

The helpers in `script/current/` assemble exact governance transition hashes
from deployed objects. They are deployment planning code, not contracts that
replace the executor or bypass Core authorization. Ordinary governance delays
remain after genesis initialization.

Use the [deployment guide](../script/current/README.md) for offline simulation,
an existing local Anvil node, and Sepolia configuration. Rehearse the exact
selected compilation and check every transaction against the chain's gas cap;
the extended governance catalog and deployment add work beyond the earlier
native-sale prototype. Local receipts and successful testnet execution are
separate evidence.

Fitting the transaction cap does not prove gas sufficiency: estimates can be
low, and receipt gas after refunds can understate the gas a call needs to finish.
Rehearse explicitly reviewed lower gas multipliers against the exact plan before
broadcasting; preserve partial receipts if a later transaction fails.

## Replace and configure modules

Core pointers and the action catalog are separate controls. A replacement
module must first be registered and admitted to governance's allowed calls;
changing a pointer does not grant configuration authority automatically.

`IStreamGovernanceCatalog` permits the governance root to propose append-only
catalog additions after sealing. An extension waits 48 hours and executes in
the same batch as a fresh SystemManifest publication. Existing entries cannot
be rewritten, and an invalid publication rolls the entire extension back.
Each extension accepts at most 64 entries; the whole catalog is capped at
1,024. Newly admitted calls still use their normal action class and delay.

The current-stack catalog tests exercise the real SystemManifest's second
publication and then configure a replacement entropy coordinator through the
actual executor. Existing tokens retain their original entropy coordinator.

## Application boundaries

- Read ERC-721 ownership from Core, display data from the router, and entropy
  from `coordinatorAtMint(tokenId)` plus `IStreamEntropyView`.
- Before signing a sale, read the current phase policy hash and signer epoch.
  Changes invalidate stale authorizations; a transaction must carry the exact
  signed payer, recipient and value.
- Read accepted attribution from `IStreamCollectionArtistRegistry`. A pending
  nomination is not an accepted artist. The sale and auction require the
  authorization's artist to match that accepted collection attribution.
- Withdrawal is a separate wallet call. Sale receipts describe official sale
  proceeds; unsolicited wallet deposits can also accrue to its split recipients.
- Deployment facts identify which modules exist. Absent optional satellites
  are represented by zero discovery fields; they are not simulated features.
- Metadata reads at the supported maximum content size need at least
  16 million total call gas; the deployment planner gives the router 12 million.
  Completed on-chain metadata carries token data inside `animation_url` and
  declares `token_data_location` as `animation_url:tokenDataBase64`.

This is a development/testnet implementation under active integration. Full
artist lifecycle and recovery, broader payment/escrow modes, advanced entropy recovery and the wider
full-v1 feature set remain separate work. The native Sepolia transaction flow is
complete; final repository validation and review precede the supported candidate
freeze.
