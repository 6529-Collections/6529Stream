# Native clearing supplemental settlement

This is the financial prerequisite for `DUTCH_AUCTION_CLEARING`, specified by
[SSA-DUTCH-CLEARING](../stream-sales-and-auctions.md#uniform-clearing-rebate-mode).
The official recorder accepts a positive native supplement for an already-minted
purchase. The clearing sale consumer, global price fixing, buyer overage custody,
rebate processing and terminal unlock state machine are separate implementation
work. This capability alone does not implement a clearing auction.

## Admission and original rights

The caller must be the candidate's sale adapter, canonically registered with
`NATIVE_PRIMARY_SALE_ADAPTER` and the existing `IStreamNativeSaleBinding` identity.
The adapter must also advertise `IStreamNativeClearingSaleBinding`, expose the
same Core, registry, resolver, recorder and immutable Manager runtime, and retain
the original sale lifecycle. ACTIVE and eligible previously created DEPRECATED
sales follow the existing native admission policy; INCIDENT_REVOKED rejects.

The complete original native floor candidate is checked against the recorder's
stored consumed key and result. Its exact digest, operation root and operation ID
remain evidence of the original purchase. The actual Manager must report the root
used. The Core must retain the same token-to-collection identity and report
`MINTED=2` or `BURNED=3`; an identity for `PREPARED_INCOMPLETE=1` is insufficient.
These Core/Manager reads do not independently prove which token belongs to an
operation. That association comes from the admitted consumer's atomic stored
purchase record and its explicit original operation ID.

`clearingPurchaseFacts(purchaseId)` is exactly fourteen ABI words (448 bytes):
floor settlement key, floor candidate commitment, original authorization digest,
purchase nonce, token ID, original operation ID, paid price, floor price, global
clearing price, override presence, override price, buyer uniform price, effective
finalize-by and financial status. Boolean, uint64 and uint8 words must be
canonical. Only the explicitly owed status `1` is accepted. During its guarded
call the consumer must expose `activeNativeSupplementalSettlement(purchaseId)`
as exactly one word equal to the commitment of the whole submitted candidate.
Every fact and the active commitment is checked again after funding.

The buyer uniform price is `min(globalClearingPrice, priceOverride)` when an
authenticated override exists, otherwise the global price. It may not exceed the
paid price and must exceed the positive original floor. The exact value is
`buyerUniformPrice - floorPrice`. A zero supplement belongs to the consumer's
terminal accounting and does not create an official settlement. Equality with the
stored effective deadline is admitted; one second past it rejects.

## Replay and current supplemental rights

The recorder consumes three independent lanes before materialization or funding:

- `(chain, recorder, adapter, purchaseId)` under
  `6529STREAM_NATIVE_CLEARING_SUPPLEMENT_LANE_V1`;
- `(chain, recorder, originalFloorSettlementKey)` under
  `6529STREAM_NATIVE_CLEARING_FLOOR_LANE_V1`;
- the ordinary official settlement key for the new supplemental execution ID.

The floor lane prevents a hostile admitted consumer from reusing a settled floor
under another asserted purchase nonce. The purchase lane prevents one purchase
from creating another financial execution by changing current policy or executor.
The canonical purchase ID retains `6529STREAM_SALE_PURCHASE_V1`, chain, adapter,
sale ID, buyer and purchase nonce. Supplemental candidate and execution preimages
are explicit `abi.encode` tuples in `StreamNativeSupplementalHash`.

Resolution uses the actual retained token ID, including the resolver's token,
collection and default precedence. It propagates the resolver's current consent
restrictions. In the current artist-bound profile, token/default assignment
support remains closed pending the corresponding artist consent implementation;
this entry does not bypass that restriction. An accepted collection PROFILE or
COLLECTION_ARTIST template remains usable. Templates materialize once from the
submitted current preview; subsequent checks retain that concrete profile and
wallet instead of observing a new payout address.

The original signed expected primary hash is compared with the actual
supplemental policy hash for drift. The original pre-mint hash includes token ID
zero; the supplemental hash includes the actual token ID. That context change can
itself produce drift even when concrete recipients have not changed. Original
floor rights and all previously materialized wallets stay unchanged and payable.

## Funding, outputs and deployment

Native funding uses the current factory `WALLET_DEPOSIT_GAS_LIMIT`, exact wallet
identity, failed-CALL-only escrow fallback and surplus conservation. A verified
empty template wallet can receive a registered escrow credit. Revoking the
recorder's escrow producer admission prevents required fallback while an ordinary
direct wallet payment can still succeed. Every failure rolls back all new replay
keys, registration, transfers, escrow owed, results and official totals together.

The new result is sixteen ABI words. It records the candidate commitment,
settlement key, purchase ID, original floor key, token ID, current profile/wallet,
amount, executor, new execution ID, escrow flag, original root/operation ID,
original expected policy hash, actual current hash and drift. The ordinary
`settlementResult` also records the financial amount. Its phase-policy fields
remain explicitly historical original-mint evidence; no new mint policy or
Manager operation is evaluated here. The canonical four official revenue events
and schema-1 `NativeSupplementalRevenueSettled` identify the financial leg.
There is no new mint, token transfer, permit, fee or entropy request.

The recorder constructor is unchanged. Deploy and link the new fixed libraries
using the compiled profile-specific link references: native supplemental
validation/rights/execution, existing-path field validation, repeated native
funding and ERC20 token routing. Existing contract20 and consumer source are
unchanged. The recorder retains its prior ABI and storage prefix and appends the
new replay/result state. Its executable changes because of these linked calls;
prior-path behavioral regressions are required rather than a bytecode-equality
claim. Mutable library direct CALL rejects; the recorder invokes those functions
through compiler-generated links. This does not prohibit another contract from
using DELEGATECALL in its own context.

The domain tests use real ModuleRegistry, factory, wallets, escrow and official
Safe contracts, with explicit Core, Manager, artist and governance-context
doubles and an admitted producer fixture. The producer fixture is not the future
clearing consumer. Native wallet failure injection is a deliberate branch fault;
ordinary wallet payments and escrow flush/release are separate real-money cases.
Current-stack governance admission, clearing consumer integration and fully cold
gas sizing remain separate acceptance evidence. Available-gas trusted registry,
Core, resolver and consumer reads retain that explicit convention; bounded
returndata does not make an underfunded transaction immune to gas exhaustion.
