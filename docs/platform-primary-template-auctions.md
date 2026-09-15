# PLATFORM_WORKS primary-template auctions

This source batch adds declared artist-less deferred native auctions through the
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

Both admit static recipients and `SALE_POSTER`. Artist labels,
`COLLECTION_ARTIST`, paid-collaborator references and other dynamic sources are
rejected. Existing Artist families and their floor/consent requirements retain
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
unchanged. Original registration rejects modes 8 and 9.

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
changes are allowed within the signed source family. Token/collection/default
precedence is enforced: a default route cannot skip a collection override, and
a prepared route cannot skip an actual token override. The original assignment
and template remain opening evidence. Preview, materialization and post-funding
checks compare the complete selected current assignment, concrete profile,
wallet, entries, original poster and current declaration witness. Current
platform authority is checked before bids, before payment, after funding and
after Manager completion. Canonical PRIMARY_POLICY_V1 uses the actual prepared
token ID; the token-0 opening hash remains distinct.

The official recorder advertises the additive
`IStreamPlatformNativePrimarySettlement` capability; registration rejects an
older recorder without it. It retains the original result, facts and replay
mappings. A separate schema-1 `PlatformPreparedPrimaryBound` receipt links the
canonical settlement/sale keys, original declaration, family, beneficiary
witness, poster and actual-token policy. Existing rights receipt bytes retain
their original tuple layout. Predicted profiles are materialized through the
real Resolver/Factory. If their wallet is not deployed, the original native
funding worker credits the existing template escrow; a deployed verified wallet
retains the original direct-funding behavior. No new treasury or refund route
is introduced.

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
exact two-credit-call late-failure/identical Safe retry. Actual Artist declaration
and correction production are accepted prerequisites, not claimed as executed
by this fixture. Token-TEMPLATE platform custody, primary allocation-time
snapshots, other sale products and transaction-capacity acceptance remain
separate scope. ERC-20 native-allowance and inherited/global freeze proposals
remain untouched.
