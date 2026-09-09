# Build and integrate the current stack

The current implementation combines the permanent ERC-721 Core with separate
contracts for minting, sales, revenue, entropy, metadata and governance. Start
here for the active implementation. The broader specification and historical
release evidence remain useful references; they describe more than this first
integrated build supports.

## Follow one paid mint

1. Genesis deploys the executor, role registry, canonical module registry,
   Core and product satellites. A committed plan registers modules, installs
   pointers, creates the initial collection and configures its entropy and
   metadata. The final calls freeze the SystemManifest pointer and seal setup.
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

The combined test deploys actual protocol contracts and uses a controllable
external randomness provider. It checks the paid flow, auction custody and
refunds, rollback across satellites, and governance after genesis:

```bash
forge test --match-path test/current/StreamCurrentStack.t.sol --via-ir -vvv
```

The focused domain suites are `StreamFixedPriceSaleAdapter`,
`StreamEnglishAuctionHouse`, `StreamMintCanonicalRegistry`, `StreamEntropyMetadata`,
`StreamCollectionArtistRegistry`, `StreamRoyaltyResolver`,
`StreamGenesisInitializer` and `StreamSystemManifest`. Keep their narrow
behavior checks while extending the product test for newly integrated flows.

The helpers in `script/current/` assemble exact governance transition hashes
from deployed objects. They are deployment planning code, not contracts that
replace the executor or bypass Core authorization. Ordinary governance delays
remain after genesis initialization.

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

This is a development/testnet implementation under active integration. Full
artist lifecycle and recovery, additional payment modes, advanced entropy recovery and the wider
full-v1 feature set remain separate work. The supported candidate still needs
the broad validation and actual testnet transaction pass before it is frozen.
