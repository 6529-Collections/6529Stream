# Artist delegated policy and sale consent

ART42 adds delegate creation of the original operation 14 mint-policy consent
and operation 16 sale consent for an accepted `ARTIST_DELEGATED` binding
(`consentMode = 2`). It uses the original PolicyConsent and SaleConsent signing
domains, record hashes, nonce lanes, native receipts and Archive operation
identity. The public companion is `IStreamArtistDelegatedConsent`.

## Create a consent

1. The principal proposes and accepts the original binding with mode 2, and
   completes the ordinary current Artist prerequisites. A principal may still
   sign policy and sale consent directly in this mode.
2. The principal creates an original Artist delegation for the intended
   collection, or collection zero for its existing global scope. Capability
   `2` permits mint-policy consent; `1024` permits sale consent. Both may be
   present in one grant. All existing forbidden capability bits remain denied.
3. The delegate signs `policyConsentDigest` or `saleConsentDigest` using the
   original authorization tuple and its original delegation nonce lane. The
   same calls may execute directly from the named delegate Safe with an empty
   application signature. A relayed Safe signature uses that Safe's original
   ERC-1271 message domain.
4. Call `recordDelegatedPolicyConsent(consent, grant, authorization)` or
   `recordDelegatedSaleConsent(consent, grant, authorization)` on the Artist
   registry. The coordinator checks actual binding and sale facts, the owner
   checks the grant and consumes its nonce/use, and both owners commit before
   the original Archive append. Any later failure reverts the entire operation.

The owner transport accepts only operations 14 and 16; it is an implementation
companion, not an independent delegation entry point. The record stores the
actual delegate as class 2 while retaining the original principal artist ID.
`recordDelegation(recordHash)` returns the immutable grant association, and
`ArtistConsentDelegationRecorded` emits schema version 1 with the same record,
grant, artist and operation.

Mode 1 (`ARTIST_SIGNED`) rejects these two delegated methods even when the grant
contains both bits. Existing operation-60 hydration profiles still require
their original mode-1 profile and do not import these mode-2 states.

## Grant lifetime and sale authority

Grant scope, not-before/expiry, revocation, use limit, estate delegation epoch,
current identity and original authority lanes are checked when creating the
consent. Each consent consumes one use. A consent made with a one-use grant
remains usable after that use exhausts the grant. Revocation or expiry also
prevents a new delegated action without erasing an already recorded consent.

Later consumers still require the exact consent and all ordinary current
binding, attribution, generation, policy, economics and readiness facts. A
different policy hash, sale ID or sale configuration does not inherit consent.
An authority transition continues to use the original rotation and estate
rules; this feature does not invent a new grant epoch or restore an invalidated
grant.

Sale consent is separate from purchase payment authorization. The native sale
recipe still requires its original buyer/payer/executor and principal/platform
permissions. A delegate consent does not make the delegate the buyer, refund
owner, beneficiary or payment signer.

## Safe retry and validation boundary

For a Safe transaction, retain the original CALL data, value, nonce and complete
threshold signatures. A reverted Archive append or missing sale consent must
leave both the protocol state and the Safe nonce unchanged. Retry those same
bytes only after correcting the failed prerequisite; do not substitute a new
signature and call that an identical retry.

The focused Artist suite authors 16 cases against actual Artist owners,
coordinator, facade, Archive, Manager, resolvers, registered native adapter and
threshold Safes. Its Core, metadata and governance are explicit typed unit
boundaries. The separate current-stack suite authors four paid native mint
cases against actual Core/Manager/Ledger/Artist/resolvers/recorder and buyer
Safe, with an explicit external entropy-provider fixture. The current cases
cover expiry, revocation, exhaustion and missing-consent rollback followed by
the identical signed Safe retry.

These tests are source-authored and typechecked at this handoff; actual runtime
acceptance remains pending the integrator's combined capture. Selected
production size checks establish only their recorded compiler/source profile.
This guide does not claim full mode-2 workflow or hydration acceptance.

The frozen source preserves all 1,125 prior ABI entries and the complete
physical storage types of the 26 modified original production files. The
final selected check uses solc 0.8.19, viaIR, optimizer 200 and Paris: 17 of
18 products fit. `StreamArtistEstateExtensionDeployment` is 24,765 runtime
bytes, 189 above EIP-170. Its child Estate extension fits at 22,670; the
original constructor and deployment wrapper remain unchanged. This is an
explicit deployment blocker, so the current handoff is not a deployable or
runtime-accepted completion of ART42.
