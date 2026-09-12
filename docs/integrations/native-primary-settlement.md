# Native official paid mints

`StreamNativeFixedPriceSaleAdapter` implements one-token, signed, fixed-price
`PRE_REVENUE_SINGLE_STEP` purchases through the shared
`StreamPrimarySaleSettlement` recorder. It supports explicit collection
`PRIMARY_SALE` profiles and the current `COLLECTION_ARTIST` template profile.
This is a bounded implementation of the native branch in
[RSR orchestration and settlement](../revenue-splits-and-royalties.md) and
[SSA authorization](../stream-sales-and-auctions.md). The
[ADR 0019 implementation decision](../adr/0019-current-settlement-implementation.md)
continues to govern the separate ERC20/Permit2 graph.

## Deployment and admission

Deploy the native consumer with `(mintManager, recorder, platformSigner,
artistRegistry)`. Its immutable recorder must advertise
`IStreamNativePrimarySaleSettlement`; the former ERC20-only recorder cannot be
used. Core, registry, resolver, factory, manager and artist bindings must agree.
The existing recorder constructor is unchanged.

The canonical module registry must register the native consumer with:

- module type `keccak256("NATIVE_PRIMARY_SALE_ADAPTER")`;
- version `keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")`;
- `type(IStreamNativeSaleBinding).interfaceId` and its actual runtime hash.

This role cannot authorize the ERC20 recorder entry. New programs require
`ACTIVE`; an existing program can finish while `DEPRECATED` only when its stored
creation time and registration revision strictly precede deprecation.
`INCIDENT_REVOKED` rejects execution. These checks use the canonical registry,
including its exact-code ERC165 policy, without an additional owner or allowlist.

Deploy and link `StreamNativeSettlementAdmission`,
`StreamNativeSettlementSupport`, and `StreamNativePriceProgram` using the compiler's
link references. The price-program helper also carries the unchanged fixed
preparation and exact recorder-call logic to keep the consumer within code size. They have
no storage or ownership. Native funding executes in the recorder context;
price-program preparation and the exact recorder call execute in the consumer
context. Direct calls to state-changing library entries reject. Contract 20 and its
permit helper have no native entry or modification in this increment.

## Signing and execution

The owner registers a config containing collection, phase, price, sale window,
mint policy and the exact current primary assignment hash. Both platform and
accepted artist sign the `NativeSaleAuthorization` typed struct from
`IStreamNativeFixedPriceSaleAdapter`, under EIP712 name
`6529StreamNativeFixedPriceSaleAdapter`, version `1`, current chain and the
native consumer address. The struct includes the exact concrete
`expectedPrimaryPolicyHash`. The public `authorizationDigest` and
`previewExecution` reads expose the values to verify before paying.

Call `purchase(execution)` with `msg.sender == payer == executor` and exactly
the configured price. A Safe can execute this payable call, sign as the artist
through its actual ERC1271 handler, and receive the NFT or split proceeds.
Signatures are not restricted to EOA-length proofs. Direct Stream contract
signature verification uses the factory's current `ERC_1271_GAS_LIMIT`.

The manager ticket uses the full signed digest:

```solidity
authorizationId = keccak256(abi.encode(
    keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
    fullEIP712AuthorizationDigest
));
```

The signer-scoped commercial nonce and `(saleId, executionNonce)` remain
independent replay boundaries. A separate native execution commitment binds
the sale, payer, executor, nonce, digest, mint policies and previewed operation
root. The recorder's asset-independent key binds itself, sale adapter and that
execution ID. `StreamNativeSettlementHash` is the exact reference for both
native commitment preimages.

The consumer validates signatures and previews the manager's root and single
operation ID before consuming its lanes. The recorder independently validates
admission and rights, consumes its official key, materializes once, funds the
wallet or escrow, and records its twelve-word result. The consumer then mints
and checks the actual root/ID and current provider/assignment authority. Any
later mint or recipient failure rolls back all payment, registration, credit,
replay and event effects.

## Templates and money

The resolver derives template kind and concrete rights. An authorization made
before a payout designation changes becomes invalid. A change during a later
recipient callback cannot redirect the already materialized payout. Future
authorizations can select the new designation; prior wallets remain immutable
and payable. This profile does not add paid collaborator-template admission.

An undeployed verified template prediction receives an exact escrow credit;
the sale never sends ETH to an empty predicted address. Existing verified
wallets receive a bounded call using current `WALLET_DEPOSIT_GAS_LIMIT`, including
the value stipend and EIP150 admission reserve. Only a failed call can fall back
to escrow. Successful malformed return data or inexact balance movement reverts
the purchase. Escrow requires the recorder to be an admitted credit producer.
Producer revocation blocks a needed fallback but does not prevent a successful
direct wallet deposit. Permissionless escrow flush and split release complete
the payout.

The recorder and consumer preserve their original passive ETH surplus.
Native execution does not consult token asset-status or permit-policy reads.
The four existing canonical recorder events are reused with native asset zero
and payment-adapter zero; neither a donation nor a raw wallet transfer creates
official sale accounting.

## Evidence scope

The focused tests use actual registry, resolver, factory, split wallets, escrow,
recorder, native consumer and official Safe contracts. Core, manager and artist
read/callback seams are explicitly named domain doubles. The native wallet
failure test is value-specific fault injection; it does not assert that a
canonical wallet normally reverts. Malformed read/result tests likewise label
their injected boundary failures. These tests are not full current-Core,
governance-delay or fully cold gas evidence.

The separate `test/current/StreamCurrentNativeSettlement.t.sol` suite uses actual
Core, Manager, artist owners, governance, resolver and two-owner Safe wallets.
`1b41cff4` records its three cases passing with the three current ERC-20 regressions:
native PROFILE purchase/reveal/claims/replay, governed COLLECTION_ARTIST template
creation and deferred-wallet escrow/deploy/flush/claims, and a late recipient
rejection that rolls back all money and mint state before an identical retry.
Only the external entropy service is mocked in this composition. Independent
review binds the exact six-case snapshot and compiler outputs; it does not
establish the complete feature set or a new release candidate.

Explicit free, PWYW and open-edition execution is described in
[native price programs](native-price-programs.md). Prepared minting, deferred
custody settlement, refund windows, native auctions, Dutch/private/public sale
modes and collaborator templates remain separate
implementation slices. A Safe receiving the immediately minted NFT proves
recipient custody, not a deferred custody settlement order.
