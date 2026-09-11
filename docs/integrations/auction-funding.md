# English-auction funding and retained proceeds rights

An English auction binds its artist-approved primary split when the auction is
created. Settlement pays that retained profile even if a later prospective
artist agreement selects a different profile. The winner's bid cannot be
redirected by changing current artist or primary-resolver state after creation.

The constructor is now
`(core, mintManager, revenueResolver, platformSigner, artistRegistry, revenueEscrow)`.
The factory comes from the resolver and must match the escrow's pinned factory,
wallet runtime, asset registry and governance authority. The manager, resolver
and artist facade must bind the same Core. Admission as an escrow credit
producer is required for fallback funding; ordinary direct wallet funding does
not require that producer permission.

## Creation authorization

EIP-712 uses `6529StreamEnglishAuction`, **version 2**, the actual chain ID and
auction-house address. `AuctionAuthorization` inserts
`bytes32 expectedPrimaryPolicyHash` immediately after `profileId`:

```text
AuctionAuthorization(uint256 collectionId,bytes32 phaseId,address artist,bytes32 profileId,bytes32 expectedPrimaryPolicyHash,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 reservePrice,uint64 startTime,uint64 endTime,uint32 extensionWindow,uint16 minBidIncrementBps,bytes32 nonce,uint64 deadline,uint64 signerEpoch)
```

Both the platform and artist sign the whole payload. The previous ABI and
version-1 signatures have no fallback. Obtain the current commitment with
`primaryPolicy(collectionId)`: creation supports only an explicit collection
`PRIMARY_SALE` PROFILE assignment and its deployed, verified wallet. The signed
profile and canonical primary-policy hash must both match.

Before consuming the artist nonce or minting into auction custody, the house
previews one nonzero operation root and exactly one nonzero operation ID. The
mint must return exactly that root and ID, one nonzero token, and actual NFT
custody at the house. A mismatch reverts the mint and nonce together.

The retained `Auction` record appends `authorizationId`, `operationRoot` and
`primaryPolicyHash` to its existing fields. These describe creation-time rights;
they are not recomputed when bids or artist agreements change. New applications
must decode the extended record and use the new authorization ABI.

## Settlement and exits

Paid settlement first accounts for the winning bid, then funds the retained
wallet using the shared [sale-funding rules](sale-funding.md). It reads the
factory's live deposit gas budget and verifies the pinned factory, escrow and
wallet identity. A reverted or out-of-gas direct deposit can become an exact
escrow debt to the same retained profile. Successful funding is followed by the
NFT transfer. If the winner's recipient rejects the NFT, all proceeds, bid
liabilities, transfers and escrow changes revert. The winner can set a valid
recipient and retry without losing the bid.

After a paid settlement succeeds, `SaleRevenueFunded` emits schema version 1,
the retained authorization ID, mint root and profile ID, then wallet, native
asset address zero, amount and `escrowed`. Existing auction settlement events
remain. Unsold returns and cancellation make no payment and emit no funding
event. Refund credits remain liabilities of the auction house; they are not
moved into revenue escrow or counted as proceeds.

Pausing prevents new auctions and bids. Existing settlement, refund withdrawal,
recipient selection, cancellation under its existing conditions, and explicit
contract-artist no-bid recovery remain available. These exits do not re-resolve
the current artist or primary assignment. Removing an escrow producer cannot
erase bids or existing debts: it blocks a newly needed fallback, which reverts
atomically; direct wallet settlement and unrelated refunds remain available.
Native funding does not consult token deprecation status.

Actual Safe accounts can supply threshold ERC-1271 artist/platform signatures,
create auctions, bid with native ETH, change their delivery recipient, withdraw
refunds, settle, receive NFTs and claim wallet proceeds. Role-bearing Safes also
perform administration and artist recovery through `execTransaction`. Safe
owner keys do not individually inherit the Safe's caller authority. Direct
Safe calls to the Core-only NFT callback are rejected; normal custody minting
invokes that callback through the Core.

## Validation scope

Focused tests use the actual auction, factory, primary resolver, escrow and
wallet, with official Safe 1.4.1 singleton/proxy/compatibility-handler artifacts
and 2-of-3 threshold proofs. They exercise all public selectors, money/NFT
flows, bid/refund conservation fuzzing, complete legacy authorization rejection,
mint identity mismatch, reentry, funding-event identity, pause and pointer-change
exits, revocation behavior, and failed-recipient rollback with successful retry.

Core/NFT and manager execution remain domain boundary fixtures; the later
prospective assignment is represented by an exact resolver-read seam. A refused
ordinary native wallet deposit is value-specific fault injection. These tests
do not claim real current-Core/artist/timelock integration, all-cold gas sizing,
all possible Safe configurations or SDK/deployment migration. This bounded
native English-auction change does not add templates, ERC20 auctions, universal
settlement, Dutch auctions or other full-v1 sale mechanisms.
