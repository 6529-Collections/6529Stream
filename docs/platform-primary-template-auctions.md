# PLATFORM_WORKS primary-rights auctions

This source supports declared artist-less deferred native auctions through the
existing Core/Manager/official recorder. ABI/type and targeted deployment-size
checks are recorded in the handoff. Focused runtime and joined actual-Artist
acceptance remain pending; this guide does not describe a deployed product.

## Opening and current authority

Use the additive `IStreamPlatformNativeRightsAuction` interface. Its
`registerPlatformRightsAuction` accepts the existing Configuration and
OriginalPolicy tuples, token data, a new PlatformCreationAuthorization and the
configured platform signer's signature. The transaction caller must be the
original poster. There is no Artist signature, synthetic Artist identity or
operation-15 consent. Governance/owner authority still installs primary terms.

The only added rights families are:

| OriginalPolicy.mode | Actual required source |
| --- | --- |
| 8 | Collection TEMPLATE, scope 1 / actual collection |
| 9 | Default TEMPLATE, scope 0 / id 0 |
| 10 | Collection PROFILE, scope 1 / actual collection |
| 11 | Default PROFILE, scope 0 / id 0 |

Families 8 and 9 admit static recipients and `SALE_POSTER`. Artist labels,
`COLLECTION_ARTIST`, paid-collaborator references and other dynamic sources are
rejected in those template families. Families 10 and 11 select existing verified
fixed profiles with deployed canonical wallets and an explicit zero template ID.
They do not turn static profile recipients into dynamic Artist or poster sources.
Existing Artist families and their floor/consent requirements retain
separate explicit modes. An Artist-bound collection cannot choose this route.

The exact new EIP-712 domain is `6529StreamPlatformNativeRightsAuction`, version
`1`, with the current chain and house address. Its type string is:

```text
PlatformNativeAuctionCreation(bytes32 configHash,bytes32 declarationHash,bytes32 nonce,uint64 deadline)
```

`platformRightsConfigurationHash` hashes the domain
`6529STREAM_PLATFORM_NATIVE_RIGHTS_CONFIG_V1`, chain, house, complete existing
Configuration, OriginalPolicy and original declaration hash with `abi.encode`.
`platformRightsCreationDigest` provides the matching digest. Both differ from the
unchanged Artist-authorized creation surface. The shared creator nonce is keyed
by the configured platform signer; the sale/auction nonce and original IDs are
unchanged. Original Artist registration rejects all four platform modes.

Opening requires the canonical current Artist facade/Core/runtime and the full
matching declaration/state reads. NONE or DISMISSED contest state is admitted.
OPEN, SUSTAINED, any pending/refused corrective generation, and accepted Artist
correction reject this platform family. A permissionless claim alone is display
information. Accepted correction instead requires the ordinary Artist consent
and separately authorized sale route; history never becomes current consent.

The house appends the original declaration by sale ID, exposed through
`platformAuctionDeclaration`. Existing Artist association fields remain zero.
The schema-1 `PlatformNativeAuctionBound` event connects the auction, sale,
declaration, family, configuration and creation digest. The declaration commits
its canonical statement document; this route does not claim to load or verify
separately referenced narrative bytes.

## Bidding, minting and payment

Use the unchanged public/signed bid and settlement selectors after platform
registration. Their original digests bind the stored declaration-bearing
configuration and creation digest. `SALE_POSTER` always resolves the original
configuration's poster, never the latest payer, executor or NFT recipient.

`primaryPolicyMode` must be ALLOW_CURRENT (1). Later owner-authorized template
changes are allowed within the signed source and PROFILE/TEMPLATE family. Token/collection/default
precedence is enforced: a default route cannot skip a collection override, and
a prepared route cannot skip an actual token override. The original assignment
and template remain opening evidence. Preview, materialization and post-funding
checks compare the complete selected current assignment, concrete profile,
wallet, entries, original poster and current declaration witness. Fixed-profile
witnesses use `6529STREAM_PLATFORM_PRIMARY_PROFILE_WITNESS_V1` with `abi.encode`
over chain, Resolver, collection, actual token (zero only at opening), signed
mode, declaration, poster, complete resolved assignment and concrete Selection.
The existing template-witness domain and preimage are unchanged. Current
platform authority is checked before bids, before payment, after funding and
after Manager completion. Canonical PRIMARY_POLICY_V1 uses the actual prepared
token ID; the token-0 opening hash remains distinct.

The official recorder advertises the additive
`IStreamPlatformNativePrimarySettlement` capability; registration rejects an
older recorder without it. Fixed PROFILE families additionally require the
`IStreamPlatformProfilePrimarySettlement` marker, so the earlier template-only
platform capability cannot authorize an opening that its recorder cannot settle.
It retains the original result, facts and replay
mappings. A separate schema-1 `PlatformPreparedPrimaryBound` receipt links the
canonical settlement/sale keys, original declaration, family, beneficiary
witness, poster and actual-token policy. Existing rights receipt bytes retain
their original tuple layout. Predicted profiles are materialized through the
real Resolver/Factory. If their wallet is not deployed, the original native
funding worker credits the existing template escrow; a deployed verified wallet
retains the original direct-funding behavior. No new treasury or refund route
is introduced. Fixed profiles pay their already verified wallet through the
original direct native-funding path; they neither materialize a template nor
pretend that its escrow rules apply.

A failed late current-state check rolls back mint, counters, replay, escrow and
payment together, allowing the same complete signed Safe transaction to retry
after repair. No-bid completion, poster pre-bid cancellation and signed-deadline
refund/own-claim exits retain their original authority exemptions. The old
Artist-attribution early-unlock reason is not repurposed as a platform verdict.

The isolated regression fixture uses actual Core, Manager, Ledger, Resolver,
Factory, house, recorder, escrow and threshold Safe, with explicit typed Artist,
governance and entropy boundaries. It covers collection/default and
static/poster payments, raw receipt coordinates, current-state rejection,
source precedence/drift, canonical signing/replay, no-bid/refund exits and an
exact two-credit-call late-failure/identical Safe retry. The fixed-profile
successor adds collection/default direct payment, independently reconstructed
profile receipts, older-recorder and wallet-code refusal with identical opening
retry, source/type drift rejection, corrective-Artist refund escape and an exact
two-wallet-call Safe rollback/retry. These are authored source cases; they have
not been executed as part of this source handoff. Actual Artist declaration
and correction production are accepted prerequisites, not claimed as executed
by this fixture. Token-TEMPLATE platform custody, primary allocation-time
snapshots, other sale products and transaction-capacity acceptance remain
separate scope. ERC-20 native-allowance and inherited/global freeze proposals
remain untouched.


## Prepared platform custody

`IStreamPlatformCustodyAuction` adds an explicit unpaid prepared acquisition for
families 8/9 (static or SALE_POSTER templates) and 10/11 (fixed profiles). The platform signs `PlatformPreparedCustodyAcquisition` under
`6529StreamPlatformPreparedCustodyAuction`, version 1, the actual house and chain.
Its ordered fields are `configHash`, `declarationHash`, `tokenDataHash`,
`expectedSaleNonce`, `expectedTokenId`, `expectedCollectionSerial`,
`expectedOperationNonce`, `contextHash`, `executor`, `revealFeeDeposit`, `nonce`
and `deadline`. Configuration uses the existing declaration-bound platform
configuration hash, with `mintAtSettlement=false` and the expected token ID.
The original Artist custody selectors, domains and signatures are unchanged.

The signed executor calls `registerPlatformCustodyAuction`, supplies exactly the
signed reveal deposit, and owns any excess native pull credit. The original
poster is separately committed in the configuration. Registration requires the
new `IStreamPlatformCustodyPrimarySettlement` marker, canonical recorder/house
binding, current admissible declaration, exact opening profile/source policy,
verified wallet, expected token/serial/operation coordinates and the original
mint phase commitment. It consumes the platform's existing shared creator nonce.
There is no synthetic Artist signature, accepted binding or op15 approval.

The existing prepared Manager operation acquires one token into house custody.
Its snapshot hook runs before completion when the phase requires royalty
snapshots; the retained origin records the actual root, operation, authorization,
manager, artwork, serial and funding account. Source/declaration and actual token
precedence are rechecked after mint completion and reveal funding. The schema-1
`PlatformCustodyAcquired` event preserves the complete signed authorization and
origin. No primary-sale revenue is recorded during acquisition.

Use the existing bid and settlement selectors afterward. The bid contains sale
payment only: reveal funding belongs to the original acquisition. Payment may
follow current owner-authorized profile changes within the signed scope/family,
but cannot skip token or collection overrides. The explicit platform recorder
entry uses canonical actual-token PRIMARY_POLICY_V1, original acquisition facts,
declaration, original rights and the current profile witness. It shares the
canonical sale/settlement replay, result and accounting storage, and emits the
complete schema-1 `PlatformCustodyRevenueRecorded` receipt. The original recorder
entry rejects platform custody rather than issuing its older token-0 receipt.
The paid transfer performs no new mint, counter allocation, reveal or snapshot.

The seven new source regressions include actual Core/Manager/royalty snapshots,
collection/default payment and full receipt reconstruction, capability/signature
refusal, current source precedence, creator-nonce positive controls, operator
refunds and exact two-call Safe rollback/retry at late reveal and wallet funding.
No-bid return, pre-bid cancellation, pending own NFT claims and deadline refund
remain usable despite a later contest or accepted corrective Artist. These cases
are authored and typechecked, not executed in this source handoff. Artist,
governance and entropy retain the fixture's explicit typed boundaries.
Token-specific platform rights and consignment remain separate follow-on workflows;
this route does not admit them.


Template custody additionally requires the additive
`IStreamPlatformTemplateCustodySettlement` marker. The initial custody interface
ID and platform signing fields/preimages remain unchanged. Families 8/9 preserve
the earlier platform template grammar: static recipients and symbolic
`SALE_POSTER`, without Artist entries or collaborator assumptions. The actual
resolved token must still select the signed collection/default source family.
The current template may change under ALLOW_CURRENT, while the original template
and assignment remain in the retained authorization and receipt. The full
candidate records the current nonzero template ID and canonical actual-token
primary policy.

Acquisition previews the primary template but does not materialize primary
revenue. Paid settlement resolves the original signed poster, materializes the
exact current profile through Resolver/Factory, and funds its verified wallet or
canonical template escrow before NFT delivery. Full declaration/source/profile
witnesses are compared before and after funding. The five additional authored
cases cover all collection/default and static/poster combinations, raw candidate
and receipt hashes, actual profile creation/wallet deployment/escrow flush, a
poster different from acquisition and settlement executors, older-recorder and
actual override refusals, current template drift, and exact two-credit-call Safe
rollback/retry. The prior seven fixed-profile cases remain included in the quick
typecheck. No native execution or joined actual Artist authority is claimed by
this source extension.
