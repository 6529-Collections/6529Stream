# Current native-offer economic actions

This authored campaign extends the existing
[actual Artist native-offer fixture](../../test/helpers/CurrentArtistNativeOfferFixture.sol).
It starts from integration `684aaa36c9dc64066eba8f4719b6006d2cc3a299`.
Native execution is pending; this document describes test scope and expectations.

## Exact family and authority

The [model](../../test/helpers/CurrentNativeOfferEconomics.sol) uses one selected
content offer with the original Native Primary Offer Sale and Gate, Core,
Manager, Ledger, Artist, Governance Executor, Registry, contract 9 recorder,
Revenue Escrow, immutable split wallet and Entropy Coordinator. Five distinct
Safe 1.4.1 accounts have threshold two: Artist, collaborator/sale owner, seller,
buyer and governor. They reuse the fixture's signing keys but have separate
addresses, signature domains, balances and transaction nonces.

The original price is 1,000 wei. The original deferred reveal reserve is 100 wei.
The buyer supplies an independently chosen excess of 1–1,000 wei. The immutable
PROFILE pays 700 wei to the Artist, 200 to the collaborator and 100 to the
protocol. Successful refund delivery goes to a separate address explicitly
chosen by the buyer Safe. Neither sale ownership nor seller signatures confer
the buyer's refund entitlement or recorder/escrow authority.

The external entropy provider is the inherited test double. A wallet deposit
failure is explicitly injected at the original wallet's empty-calldata,
1,000-wei call. A separate test recipient naturally rejects native refund
delivery until repaired. Production code, authority checks, accounting, limits
and original fixture sources are unchanged.

## Required sequence

Fourteen opening steps run before bounded random repetition:

1. A signed buyer transaction fails without Artist sale consent. Only an actual
   Artist Safe transaction records the missing consent.
2. A seller signature made under the buyer Safe domain fails. The governor then
   removes recorder credit admission through the existing delayed Executor path.
   An injected wallet-deposit failure forces the original recorder to attempt
   escrow. Failed admission reverts actual Ledger consumption and preparation.
3. The governor restores admission. The byte-identical buyer transaction commits
   the same root, token operation and independently reconstructed settlement key,
   creates genuine revenue escrow and credits only the buyer's excess.
4. The wallet fault also rejects a real escrow flush after its debit. Removing
   the fault lets the byte-identical buyer Safe flush transaction succeed.
5. Seller and sale-owner refund attempts fail. Invalid refund destination and
   unauthorized redirection of Artist split revenue also fail.
6. The buyer's chosen refund recipient rejects after credit debit. Repairing it
   allows the byte-identical Safe refund transaction to succeed once.
7. All three split shares are released, with the seed selecting the order of the
   final two. The protocol release is permissionless but pays only the protocol.
8. The buyer Safe requests entropy and the external test provider fulfills it.
   Its inherited quote is zero, so the 100 wei remains collection reveal escrow;
   no fee spend or new refund entitlement is invented.
9. Fresh outer Safe envelopes retry the consumed offer and unauthorized recorder
   and escrow calls. Direct recorder replay supplies the actual committed facts,
   intent and full price, but still lacks the sale adapter's caller authority.

Later actions repeat consumed purchase, refund, share-release and authority
denials. Sequences stop after at most 64 steps. Expected outcomes follow action
intentions and prior modeled successes, not production preview or balance reads.

## Independent state and receipts

After each action, buyer debit must equal sale refund custody, revenue escrow,
wallet balance, all released shares, reveal reserve/provider balance and the
authorized refund destination's balance. Each partition is checked separately,
including every beneficiary's cumulative released and remaining entitlement.
The recorder must retain zero funds and report exactly one price, never the
reveal fee or excess. All five Safe nonces follow explicit transaction counts;
seller message signatures consume no transaction nonce.

The model checks original Artist consent and recorder producer revision, buyer
Ledger authorization, separate seller digest storage, original counter debit,
Core IDs/serials/ownership/content, prepared state, entropy anchors and terminal
sale state. The existing receipt checker independently reconstructs the full
prepared intent, content and facts, all twelve official result fields and the
candidate commitment. Their complete retained records must remain unchanged
through refunds, flushes, releases and rejected replays. Reverted trace events
locate the failed preparation but are not successful transaction receipts.
Successful flush, refund and split events are checked exactly.

## Authored verification and remaining acceptance

The [host](../../test/current/StreamCurrentNativeOfferEconomics.t.sol) contains
seven deterministic tests, one input-fuzzed property and one invariant. It
targets only the selected handler's `step` selector. Tests cover minimum and
maximum excess, both release orders, fixed-seed snapshot replay, unauthorized
driver access, and deliberate refund/split/Safe-nonce oracle corruption. The
input property runs 14–30 steps. `afterInvariant` requires all opening activity.

Regression seed `0x6529EC09` expands per step with
`keccak256(abi.encode("CURRENT_NATIVE_OFFER_ECONOMIC_SEED_V1", seed, index))`.
A later coordinated native capture must use the exact host through the existing
[acceptance wrapper](../../tools/development/run_current_acceptance.py), match
all nine ABI cases, preserve original deployment size limits and require 256
fuzz inputs plus 32 invariant runs at depth 64 with zero handler reverts. The
wrapper's seed remains `0x6529`. ABI checks alone establish no runtime pass.

This is one native selected-content offer family. It does not cover ERC-20,
PaymentIntent, Permit2, held payment changes, arbitrary prices or split rounding,
other sale/custody modes, natural wallet deposit failures, external oracle
security or cold-gas capacity. The earlier English-auction recovery campaign
remains separate. No universal settlement, full-v1, release or testnet acceptance
is claimed. Shared runners, catalogs, production sources, earlier campaign files
and immutable RC1 evidence are unchanged; the gate size plan remains unexecuted.
