# Native delegate-signed secondary offers

The additive IStreamPrivateSaleDelegatedOffers capability implements
[SSA-OFFER rule 1 and SSA-DELEGATE rule 8](stream-sales-and-auctions.md).
It uses the existing native private-sale adapter, original SaleOffer digest and
the optional pinned NFTDelegation configuration described in
[native delegated claims](native-private-delegated-claims.md).

acceptDelegatedOffer presents the seven original acceptOffer arguments plus
the existing DelegationWitness tuple. The Signature authorizer names the actual
delegate; kind 1 remains explicit EOA verification and kind 2 remains explicit
ERC1271 verification, including threshold Safes. The principal is still
offer.buyer. The offer's original domain, field order and hash contain the
principal, token, price, nonce and deadline without a new delegation digest.

The adapter checks the registered manifest and live retained delegation row
before and after signature validation, after taking original owner-authorized
custody, after royalty settlement and after NFT delivery. A missing, revoked,
expired, malformed or unavailable grant fails closed and rolls back the entire
acceptance. The fixed read cap and exact-row discipline are unchanged.

Delegation provides offer-signing authority only. The original buyer must call,
supply native payment and remain the SaleAuthorization payer/executor,
beneficiary and NFT receiver. The collection sale signer still signs the
matching authorization; only the actual token owner supplies the original
custody grant. A delegate does not gain authority to revoke the principal's
offer, sign an owner grant or supply any ERC20 payment authorization.

Original acceptOffer remains maker-only and preserves direct maker/Safe
signatures. Both entrypoints share the original consumed offer, sale
authorization and owner-grant stores and their existing events. A consumed offer
cannot be revived by a fresh sale/authorization/grant or by switching between
maker and delegate entrypoints. Failed callbacks preserve all three replay
facts, custody and payment accounting atomically.

A fixed compiler-linked worker handles both entrypoints. For the original
branch it retains the original admission, signature, replay, custody,
royalty/NFT delivery and receipt ordering. Governed cap and pause values are
read from the actual host at their original phases. Host entrypoints retain
normal return/guard cleanup. No storage root, constructor field or original
public ABI/signing payload changes in this increment.

Six authored actual-current cases cover EOA and threshold-Safe delegates,
unchanged maker acceptance, unauthorized caller/signature/owner grant,
principal-only revocation, consumed-offer replay across fresh listings,
byte-identical buyer-Safe retry on registry failure, and actual NFT callback
revocation after royalty payment with exact two-payment-call rollback/retry.
The callback case uses a real controlled buyer contract, explicitly separate
from the threshold-Safe payer cases. All tokens first complete the existing
paid primary delivery to the collector Safe.

This batch has quick ABI checks and selected production bytecode measurements.
The authored cases are not executed here. Artist, entropy and governance
action contexts retain the inherited typed-fixture qualifications. Full native
integration, transaction-capacity and release acceptance remain separate.
