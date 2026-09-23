# Current mint entrypoints and Safe acceptance

Source review baseline: `afe8da28345c52ef591900a72bbe2e1131c753c6`,
20 September 2026. The additions described below are authored regression
recipes awaiting the coordinator's matched-source native capture. This is a
source coverage map, not a new passing-runtime report or a release gate closure.

## Composition boundary

All eight Manager mint entrypoints now have source-authored assertions
joining the actual Core, Artist, Manager and Ledger. Four newly joined
families retain their older typed-boundary tests as separate evidence.
The curated and offer additions await coordinated native execution. A `test/current`
path alone does not establish the complete current composition.

- [StreamCurrentStackFixture](../test/helpers/StreamCurrentStackFixture.sol)
  constructs the real protocol authority and Artist graph through original
  artifact constructors. Its external entropy service is a double.
- [NativeEnglishAuctionFixture](../test/helpers/NativeEnglishAuctionFixture.sol)
  uses actual Core, Manager, Ledger and revenue products with typed
  `NativeAuctionArtist`, `NativeAuctionAuthority` and entropy boundaries.
- [NativeCuratedSaleFixture](../test/current/helpers/NativeCuratedSaleFixture.sol)
  inherits that boundary and substitutes `NativeCuratedArtistBoundary`.
- [Standard gate integration](../test/unit/mint/StreamMintStandardGateIntegration.t.sol)
  uses actual gate, Manager, Ledger and Safe with typed Core, Artist and
  governance. Full37 gate admission alone is not a ticket-mint execution.

## Entrypoint map

All eight entrypoints are defined in
[StreamMintManager](../smart-contracts/domains/mint/StreamMintManager.sol).
The following are representative concrete acceptance assertions; they are not
an assertion that every product variant or Safe role is fully joined.

| Manager entrypoint | Public routes | Existing source acceptance and boundary |
| --- | --- | --- |
| `executeSingleStepMint` | Fixed-price `buy`; native fixed/Dutch/clearing purchases; refund finalization; Universal ERC20 callback; English auction creation; ordinary custody registration; nonprepared distribution and burn wrappers | **Actual Artist join.** [Safe](../test/current/StreamCurrentSafe.t.sol) `testSafeArtistBuyerCustodyApprovalTransferAndRevenueRelease`; [native settlement](../test/current/StreamCurrentNativeSettlement.t.sol) `testSafeNativePurchaseMintsRevealsClaimsAndRejectsReplay`; [ERC20](../test/current/StreamCurrentStackERC20.t.sol) `testOfficialSafeERC20PayerApprovalRelayedIntentMintAndCustody`; [Universal](../test/current/StreamCurrentUniversalSettlement.t.sol) `testActualSafeSignedIntentMintsAndRejectsExactReplay`. Safe NFT custody, Ledger replay, authorization, payment/allowance, revenue and reveal assertions. |
| `executePreparedMint` | `registerPreparedCustodyAuction`, `registerPlatformCustodyAuction`; prepared distribution and burn wrappers; directly admitted phase executor | **Actual Artist join.** [Artist custody rights](../test/current/StreamCurrentArtistCustodyRights.t.sol) `testActualArtistTokenProfilePaysAfterOriginalPreparedSnapshotWithoutRemint` binds original funding, authorization, operation, royalty snapshot and reveal fee before resale. [Fallback](../test/current/StreamCurrentMintFallback.t.sol) `testFallbackPreparedMintLateFailureRollsBackAndClearsSentinelOnExactSafeRetry` asserts actual fresh consent, imported replay/caps and late receiver rollback; its entitlement gate is a test boundary. |
| `executePreparedNativeMint` | Native English `registerAuction`, bids, then `settle` for ordinary PROFILE mint at settlement | **Actual Artist join.** [Artist royalty snapshot](../test/current/StreamCurrentArtistRoyaltySnapshot.t.sol) `testActualSafeSnapshotConsentPhaseAuctionAndCanonicalTokenRoyalty` joins Artist/Governor/Payer Safes, snapshot event, operation/root, prepared proof, Ledger consumption, `preparedNativeFactsHash`, PROFILE revenue, reveal fee and withdrawal. `testLaterApprovedSourceCannotRewriteTokenSnapshotOrReuseOldPhase` preserves history and rejects stale authority. |
| `executePreparedNativeRightsMint` | `registerRightsAuction` / `registerPlatformRightsAuction`, bids, then `settle` | **Actual Artist join.** [Consented commerce](../test/current/StreamCurrentConsentedNativeCommerce.t.sol) `testActualArtistConsentRepairsSameGovernanceActionThenSafeAuctionPaysAndReveals` repairs actual consent and pays/reveals. `testActualCommerceEscrowFailureRollsBackMintAndIdenticalSignedSafeRetryPays` retains winner liability while rolling back Core, Manager, revenue and Safe state. [Dynamic royalty](../test/current/StreamCurrentDynamicRoyaltyCommerce.t.sol) `testActualDefaultDriftRollsBackSignedSafeSettlementThenIdenticalCallRetries` adds default-drift retry. |
| `executePreparedNativeContentMint` | `registerCuratedAuction`, bids, then `settle` | **Actual Artist recipe added.** [Curated auction](../test/current/StreamCurrentArtistCuratedAuction.t.sol) joins actual Artist/Governor/Safes with exact settlement rollback and retry. Native execution pending. Earlier typed-boundary evidence: [Curated auction](../test/current/StreamCurrentNativeCuratedAuction.t.sol) `testSafeContentCompletionRollsBackCounterPaymentAndIdenticalTransactionRetries` asserts payment, counter, preparation, admission and Safe rollback; `testOrdinaryManagerEntriesCannotBypassContentAdmission` rejects generic bypass. |
| `executePreparedNativeContentPurchaseMint` | Curated fixed `purchaseSelectedContent`; `commitSelection` then `revealSelection`; private `purchasePrivateContent` | **Actual Artist recipes added.** [Curated purchase](../test/current/StreamCurrentArtistCuratedPurchase.t.sol) joins fixed/private/commit-reveal products to actual Artist and delayed governance. Native execution pending. Earlier typed-boundary evidence: [Curated private Safe](../test/current/StreamCurrentNativeCuratedPrivateSafe.t.sol) `testOfficialSafeBuyerCallsFullPrivateAuthorizationOwnsNFTAndClaimsFeeCredit`, `testOfficialSafeSellerERC1271UsesOriginalSaleDigestAndOfficialFallbackHandler`, and `testIdenticalOfficialSafePrivatePurchaseRetriesLateCoreFailureWithOriginalNonces` cover caller, signer, original digest, delivery, fee credit and retry. Public/commit payment and content controls also exist in [curated fixed sale](../test/current/StreamCurrentNativeCuratedFixedSale.t.sol). |
| `executePreparedNativeOfferMint` | `StreamNativePrimaryOfferSale.acceptPrimaryOffer` | **Actual Artist recipes added.** [Native offers](../test/current/StreamCurrentArtistNativeOffer.t.sol) has three cases for selected/collection authority, original receipt/revenue and exact retry after late escrow failure. Native execution pending. Earlier typed-boundary evidence: [Native primary offer](../test/current/StreamCurrentNativePrimaryOffer.t.sol) `testActualTwoOfTwoSafeBuyerSellerAndDirectHistoricalSellerRevocation` covers distinct buyer/seller signatures, replay and Safe rollback, exact retry, fee/refund and historical seller revocation. Selected-work, collection-level and delegated execution cases are separately authored. |
| `executeERC20OfferMint` | Primary settlement `settleERC20PrimarySaleByPayer`, `WithIntent`, `WithEIP2612Permit`, `WithPermit2`, then offer adapter's restricted callback | **Actual Artist recipes added.** [ERC20 offers](../test/current/StreamCurrentArtistERC20Offer.t.sol) has four cases for dual Safe proofs, original payer intent/delegated executor, fee repair, callback rollback and buyer void. Permit routes retain their separate earlier coverage. Native execution pending. Earlier typed-boundary evidence: [ERC20 primary offer](../test/current/StreamCurrentERC20PrimaryOffer.t.sol) `testActualTwoOfTwoSafeBuyerSellerCallAndExactFailedTransactionRetry`, `testActualSafePayer1271IntentRemainsSeparateFromDelegatedOfferExecution`, and `testFinalNFTFailureRestoresPayerIntentSellerAndLedgerForByteIdenticalRetry` assert all three replay stores, payer-only spending, allowance/balance rollback and original receipt identity. Permit cases remain separate assertions. |

## Safe authority is role-specific

- **CALL:** a Safe calls the public product; Manager normally sees that adapter
  or auction house as executor. Safe-to-Manager calls require phase-executor
  admission. Artist/operator setup additionally uses the actual initial owner
  and final governance handoff in
  [mint setup](../test/current/StreamCurrentMintSetup.t.sol).
- **ERC-1271:** Artist, ticket, seller, buyer-offer and payment-intent signatures
  wrap the original protocol digest in the official SafeMessage envelope.
  Verification itself consumes no Safe transaction nonce.
- **Delegation:** a live signer/executor grant cannot authorize spending an
  unrelated payer's ERC20 balance. Payment intent is independently checked.
- **Auction settlement:** permissionless execution does not replace the stored
  winner's payer, executor or delivery facts.
- **Retry:** a gas-zero Safe failure reverts its envelope and preserves the
  signed transaction. A nonzero `safeTxGas` failure can return false and consume
  the Safe nonce while product state rolls back. For example,
  `StreamCurrentStackERC20.testSafeRelayerFailurePreservesIntentAndSameCalldataRetries`
  proves reuse of product calldata, not reuse of an identical signed envelope.

## Added missing recipes

[StreamCurrentMintTicket](../test/current/StreamCurrentMintTicket.t.sol) adds six
cases with real Artist/Core/Manager/Ledger, production TicketGate admitted by
delayed governance, and separate threshold-two Artist, ticket and executor Safes:

1. Single-step delivery, exact preview/root identity, canonical Ledger ticket
   consumption, replay rejection and actual Coordinator reveal.
2. Prepared delivery with no residual preparation and exact replay rejection.
3. An Artist Safe signature cannot substitute for the ticket Safe's envelope;
   token-data tampering also rejects before accounting. The original correctly
   signed payload then succeeds.
4. Two-token prepared batch: the first completes inside the attempted call,
   the second external recipient rejects delivery, and the entire batch rolls
   back. Repairing only that recipient permits the byte-identical signed Safe
   transaction to commit both tokens and both beneficiary counter debits.
   Reverted trace events establish the failure location, not committed receipts.
5. Direct authorizer-Safe revocation consumes the original ticket ID without
   mint/counter/root allocation and prevents positive prepared execution.
6. Relayed ERC-1271 revocation rejects the ordinary ticket signature and requires
   the separate revocation envelope. The original Safe transaction nonce stays
   unchanged.

The ticket's payer field is authenticated metadata in these generic nonpayable
Manager paths. It does not establish token spending or native-payment authority.
The rejecting recipient and external entropy provider are explicit test boundaries;
protocol Artist, governance, gate, Core and accounting code are not substituted.

The ordinary PROFILE late-failure regression in
[consented commerce](../test/current/StreamCurrentConsentedNativeCommerce.t.sol)
complements its existing Rights regression. It keeps the actual Artist and
payment products, injects an exact native wallet-deposit failure to exercise the
real escrow fallback, denies and repairs the recorder's escrow admission through
actual delayed governance, and retries the original signed Safe settlement.
The PROFILE wallet's unconditional receive normally succeeds; the explicit
deposit-call fault is not a naturally occurring failure claim or a cold-gas proof.

The four previously missing actual-Artist entrypoint joins are now authored
in the [curated batch](MINT_CURATED_CURRENT_ACCEPTANCE.md), integrated as
`5eeee268`, and [offer batch](MINT_OFFER_CURRENT_ACCEPTANCE.md), integrated
as `770ccea5`. They preserve original selection, seller, consent and payer
authority. Their native execution and broader permit/variant acceptance
remain pending; older typed-fixture passes do not validate the additions.
Full37 deployment belongs to Testing; caller APIs belong to Clients.

## Nine fallback cases: joined-capture readiness

Select both original hosts with all their ABI-discovered test names:

- [StreamCurrentMintFallback](../test/current/StreamCurrentMintFallback.t.sol):
  six cases for reserve identity, planner pins, genuine import/delay, ordinary
  and prepared exact Safe retry, and predecessor custody/refund liabilities.
- [StreamCurrentMintFallbackIncident](../test/current/StreamCurrentMintFallbackIncident.t.sol):
  three cases for two real imports plus permanent gap recovery, owner burn
  invalidating scheduled commitments, and late manifest-tail rollback.

Use their original `ArtistArtifactCreate` / `vm.getCode` construction and all
compiler-linked artifacts, including `StreamMintManagerFallback` and
`StreamMintFallbackRecovery`. Keep the explicit `CurrentFallbackStrandingManager`
test artifact separate from the production fallback runtime. No ordinary
production Manager can persist its preparation as that test predecessor does.

The fixture now asserts deployed production reserve/rescue runtime is nonempty
and no larger than 24,576 bytes. It compares actual Core entropy parameter value,
floor, failure class and genesis revision with `StreamCurrentStackPlan`.
At the baseline these are allowance 500,000, floor 120,000, class 2, revision 1;
120,000 is not the callback allowance. Future shared-plan calibration must be
captured at the selected source; this fixture neither overrides nor raises it.

Compile with Solidity 0.8.19, via IR, optimizer 200, Paris, no CBOR and no bytecode
metadata hash, preserving actual linked artifact construction. The coordinator
chooses the joined source after full37 and shared entropy changes stabilize.
No new native acceptance is claimed here. The immutable focused 13-case capture
on `d1a58e4403cfbb80d921e117e0a7ac9b90ff61c7` remains separate evidence with typed
governance, registry, Artist and entropy boundaries; it cannot stand in for
these nine current cases.
