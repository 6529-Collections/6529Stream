# Current Artist token-rights custody workflow

This authored integration profile joins the actual current Core, Manager,
Artist suite, Governor Safe, auction house, Resolver, split factory and revenue
escrow. It uses the existing acquisition and activation APIs; it adds no
production selector or permission. Source/type validation passes. The seven
new cases have not yet been executed in the combined native test campaign.

## Two transactions with separate authority

1. The real delayed Governor Safe admits and binds the canonical custody house.
   The actual Artist Safe approves the collection-specific snapshot election
   over the original scope-0 default royalty source. The Manager phase retains
   its exact mode/source commitments and current Artist policy consent.
2. The acquisition executor Safe calls `registerPreparedCustodyAuction` with the
   original platform and Artist signatures. The house receives the newly minted
   token, and the Manager copies the approved 600-bps terms into its frozen
   scope-2 royalty assignment. The actual 100-wei reveal allocation occurs once;
   the acquisition executor owns the 50-wei excess refund. No primary price is
   paid at acquisition.
3. With that actual token identity now available, the Artist Safe records an
   original operation-15 approval for a scope-2 PROFILE or dynamic TEMPLATE.
   The Resolver owner installs exactly those terms through delayed governance.
   The template retains the original accepted collaborator row, zero role,
   current typed payouts and symbolic `SALE_POSTER` allocation.
4. The original poster activates token rights before any bid. PROFILE uses
   `activateTokenProfileCustody` and its existing
   `6529StreamTokenProfileCustodyAllowCurrent` domain. The dynamic template uses
   `activateCustodyRights`, family `4`, and
   `6529StreamCustodyRightsAllowCurrent`. Both signatures bind the original
   auction/config/origin, actual token, assignment, actual-token primary policy,
   Artist, nonce and deadline. These append approval without rewriting the
   acquisition. Both routes explicitly use `ALLOW_CURRENT`.
5. The winning collector Safe uses the matching bid and settlement entry family.
   Payment resolves current, independently approved scope-2 terms. A template
   materializes the original poster, Artist and collaborator payouts into a
   concrete profile, credits actual escrow and can then deploy/fund its wallet
   through `flushEscrow`. The recorder commits the complete custody receipt and
   consumes the original sale. This transfer creates no second mint, snapshot,
   reveal fee or mint-operation receipt.

The acquisition executor, original poster and winning collector are distinct
accounts. A signed bid also demonstrates a distinct funding executor with the
collector Safe as its authenticated payer and NFT recipient. Safe transactions
use ordinary CALL, zero gas-refund fields and the original threshold signatures.
The profile does not use a mock Artist, Core, governance authority or NFT owner.
Only the external entropy service is the inherited service double.

## Authored regression cases

The new [test](../../test/current/StreamCurrentArtistCustodyRights.t.sol) and
[fixture](../../test/helpers/CurrentArtistCustodyRightsFixture.sol) cover:

- A deployed token PROFILE receives the actual primary payment while the
  original acquisition, snapshot, source hashes and Core royalty disclosure stay
  fixed. Repeated settlement returns its original result without paying twice.
- A dynamic token TEMPLATE resolves exactly four concrete rows and funds actual
  escrow. The original poster is neither the acquisition executor nor collector.
- Collection approval/fallback cannot authorize token activation. A nonexistent
  Core token cannot be approved. Missing scope-2 Artist consent fails a complete
  signed Governor Safe execution; actual operation-15 approval permits the
  identical scheduled action and signed transaction to succeed.
- A previously signed ordinary bid cannot cross activation or enter the new
  family. The same nonce works only after signing the effective configuration,
  and then cannot be replayed.
- An injected revert at the exact actual escrow funding call rolls back the
  auction, official payment, NFT and Safe nonce. The exact same signed Safe
  bytes succeed after removal of that fault. An exact two-call expectation
  prevents the retry from concealing failure before funding was attempted.
  This is an escrow-funding failure control, not an observed post-funding
  Artist-consent failure.
- A later independently approved token PROFILE is selected under the original
  `ALLOW_CURRENT` activation, including an approved 40% Artist share. The
  activation and frozen royalty do not change.
- Replacing the current token TEMPLATE with an approved PROFILE closes that
  template payment family; the original no-bid poster return still works and
  preserves the executor's reveal credit.

Receipt assertions use compiler-derived original event topics, every indexed
identity, the complete versioned payload and independent activation/facts/policy
preimages. Artist approvals are checked against their original binding-specific
association and retained Archive operation-15 evidence. The fixture uses the
existing creation-artifact helper, ordinary constructors, original callers and
real admission throughout.

Run the focused profile from a current compiled artifact graph with:

```text
forge test --match-contract StreamCurrentArtistCustodyRightsTest -vvv
```

The authored profile is separate from the earlier
[deferred primary mint and secondary resale join](current-dynamic-royalty-commerce.md).
It does not establish prior collector delivery at unpaid acquisition or classify
this later primary payment as a secondary consignment. Full native execution,
gas conformance and release acceptance remain pending.
