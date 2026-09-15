# Actual Artist and current Core royalty commerce recipe

The authored [five-case suite](../../test/current/StreamCurrentDynamicRoyaltyCommerce.t.sol)
joins actual Artist approval, current Core prepared minting, dynamic primary
materialization and resale of the delivered NFT. Its
[isolated fixture](../../test/helpers/CurrentDynamicRoyaltyCommerceFixture.sol)
uses the existing current graph, original governance delays and real threshold
Safes. Source and ABI checks pass; native execution, selected-product sizing and
transaction capacity for this new suite are pending. This is a local test recipe,
not a broadcast or evidence of a deployed system.

The only shared fixture change makes `_onboardFixtureArtist(address)` virtual.
Its original body and callers remain unchanged. The override proposes and
accepts a real collaborator identity before the primary binding, includes its
paid row in that original proposal, then obtains both acceptances and actual
payout designations. Each identity uses its own nonce. No Artist, Core, Manager,
Resolver, registry or Safe is replaced with a mock. The external entropy service
retains the current fixture's test double. Product creation reads compiled
creation artifacts and performs ordinary CREATE with original constructors;
production admission and size checks still run.

## Transaction sequence

1. Establish the actual collection binding and current baseline economics through
   the Artist Safe. Elect snapshot mode through the current governance Executor.
   Choose a configured-zero collection override, a positive inherited default,
   or a configured-zero inherited default. A missing collection key selects the
   default; a configured-zero collection key suppresses it. The raw default
   assignment remains scope 0, while snapshot approval binds scope 1, the actual
   collection and its election.
2. Register symbolic primary terms through governance: 30% COLLECTION_ARTIST,
   20% the accepted collaborator row, 30% SALE_POSTER and 20% STATIC protocol.
   The Artist Safe records original operation 15 consent. The test reads the
   original binding association and Archive payload. This approves the symbolic
   terms; the later signed auction configuration binds the concrete poster.
3. Install that template and a fresh Manager phase whose wrapped royalty policy
   commits the admitted snapshot source. Record the actual Artist policy consent
   for the phase and its auction executor.
4. Register the mode-3 prepared auction with original platform and Artist
   signatures. The original poster is the fixture account. The collector Safe
   pays the native price and captured reveal fee, then settles. The actual
   Manager/Core allocate and deliver one NFT to that collector. The receipt
   preserves actual-token primary policy, operation root, original poster and
   independently reconstructed Artist/collaborator beneficiary witness. The
   settlement result's separate policy fields are the mint-phase policies.
5. Assert the complete frozen token royalty copy, configured state, revision 1,
   source and token hashes. Primary funds first reach the actual escrow for an
   undeployed dynamic split wallet; flushing deploys and funds the exact wallet.
   Verify all four resolved account/share/label rows.
6. After actual collector delivery, register the existing kind-5 secondary sale.
   The collector Safe grants and deposits custody of that same NFT. A different
   buyer Safe purchases it with the original authorization and native value.
   The actual Core royalty quote supplies the frozen receiver and rate. The
   original account-only claims withdraw consignor proceeds and buyer excess;
   the test checks all liabilities clear without another mint or snapshot write.

## Regression cases

| Case | Authored assertion |
| --- | --- |
| Configured-zero collection | Suppresses a positive default before mint and after later default changes; resale pays zero while retaining a nonzero frozen token assignment. |
| Positive inherited default | A later unapproved zero default closes current snapshot admission; the delivered NFT still pays its original 600 bps on resale. |
| Configured-zero inherited default | A later separately approved positive collection override authorizes current terms but cannot change the old zero-royalty NFT. |
| Source drift and signed retry | Changing the default prevents settlement, preserves the full unpaid mint state and Safe nonce, and consumes neither payment nor operation root. Restoring the exact original terms permits the byte-identical signed Safe call. An exact two-call expectation witnesses both attempts. This failure is at source admission; it is not described as a late-funding failure. |
| Missing template consent and payout rotation | The original scheduled governance action fails without operation 15, then succeeds unchanged after actual Safe approval. A later actual collaborator payout designation changes the concrete primary profile while preserving its original accepted account/role/label row and symbolic assignment approval. |

The collaborator role is deliberately zero, which is a valid opaque role value.
The original collaborator identity is never replaced by its payout address.
The original poster, primary Artist, collaborator, first owner/consignor and
secondary buyer remain separately asserted identities even when Safes share the
fixture's known test signing keys.

This finite suite covers one collection, one paid collaborator, one template and
one minted NFT per case. It does not establish gas conformance, cover every
profile/finality state, exercise acquisition before mint, or claim the separate
PLATFORM_WORKS workflows. Root-owned combined native validation must execute the
new cases before this guide can report passing runtime results.
