# Current sale conservation campaign

For the separate non-WAIVED original documentary producer fixture, see
[current documentary conservation](current-documentary-conservation.md).

`test/current/StreamCurrentStackInvariant.t.sol:StreamCurrentStackInvariantTest`
targets only `StreamCurrentStackHandler.step` against the sealed current stack.
Core, Manager, Ledger, Artist, delayed governance, split wallet, escrow, entropy,
Metadata and the Core-bound conservation floor are actual contracts. The payment
token and external entropy service are explicit test substitutes. No legacy or
typed Artist owner replaces the current suite.

The original native fixed-price adapter, ERC-20 fixed-price adapter and English
auction house are registered in the actual canonical DIRECT role by a threshold
Safe through delayed governance. A separately governed collection-scoped Metadata
grant lets that Safe explicitly declare `CONSERVATION_WAIVED` before minting.
The shared commerce fixture retains its read/producer/call gas values of
300,000 / 1,000,000 / 6,000,000. Those test settings do not establish the required
500,000-gas whole-purchase ceiling or fitting deployment capacity.

## Sequence and required activity

The first fifteen actions retain the original campaign ordering. Five additional
opening actions exercise Safe identity, burns, governance and unpaid exits.
Subsequent seeds choose among all twenty actions; higher seed bits also vary
prices, payers, bids, ownership targets and selected auctions. Existing campaign
budgets remain in [tooling](../tooling.md#reproducible-fuzz-and-invariant-campaigns).

| Opening step | Action |
| --- | --- |
| 0–1 | Native purchase, then separately authorized relayed ERC-20 purchase |
| 2–6 | Auction creation, two different bidders, outbid-credit withdrawal and paid settlement |
| 7–8 | Native/ERC-20 beneficiary releases, then NFT ownership transfer |
| 9–10 | Reject already-used native and ERC-20 purchase authorizations |
| 11 | Reject ERC-20 at the actual ERC-721 receiver, enable that receiver and retry the identical commercial and payer-intent bytes; the receiver transfers its NFT |
| 12 | Reject funded native mint at that receiver, enable it and retry identical signed bytes, value and payer; the receiver transfers its NFT |
| 13 | A stranger cancels only its own nonce namespace; the Artist-signed purchase still succeeds |
| 14 | The Artist cancels a fresh signed purchase; execution rejects without a Ledger mint authorization |
| 15 | Reject an EOA submitting a Safe-bound native authorization, then execute the unchanged buy through the actual threshold Safe |
| 16 | Reject a relayer with empty ERC-20 payer proof, then execute through the actual payer Safe using the literal-caller exemption, without consuming a payer-intent nonce |
| 17 | Burn a live token through its actual owner and preserve its original paid history |
| 18 | Execute a real delayed Safe-governed pause, reject a signed buy with no progress, resume through governance and retry the identical authorization |
| 19 | Create and settle an unpaid no-bid auction without fabricating paid history |

Every dispatched action must complete a checked transition or an exact expected
negative check. Empty release/transfer opportunities choose valid alternatives.
Required counters count successful operations and verified rejection branches;
`steps` alone cannot satisfy activity. An invariant run must continue beyond the
deterministic opening. A separate smoke test traverses every random dispatch
branch. Unexpected positive-path failures propagate with `fail_on_revert=true`.

## Independent conservation checks

- Literal CONSTANT/PHASE counter keys match successful original operations. Their
  sum, Manager nonce, allocation high-water mark and lifetime supply agree.
  Burns reduce only the modeled live supply; permanent collection/serial identity,
  replay consumption and existing REGISTERED entropy remain.
- Every token's current owner or burned state matches the model. Transfers and
  burns from the fourth payer, an official Safe 1.4.1, use actual threshold-signed
  CALL transactions. Safe nonces are modeled separately from product nonces.
- Each payer retains its initial funding plus withdrawn refunds minus successful
  purchases and bids. ERC-20 debits are tracked separately for all four payers.
  Outbid credit is not cash until withdrawn. Beneficiary balances, split releases,
  dust, active auction escrow and outstanding refunds conserve actual proceeds.
- Commercial digests and submitted fields, the caller-bound Manager preview,
  independently derived per-token operation IDs, original admission time/revision
  and actual paid outcome build the expected sixteen-word DIRECT receipt.
  Product bindings, receipt hashes and complete floor receipt hashes are checked
  in their original domains. Paid auction history retains creation authority
  while recording the later winning payer and delivery beneficiary.
- The first paid sale's complete floor record remains unchanged after subsequent
  payments, beneficiary releases, transfers, burns and governed pauses. Every
  original product receipt and DIRECT floor tuple remains unchanged. DIRECT keys
  never appear as universal settlement receipts.
- This is a WAIVED graph: `releaseReceiptHash` stays zero and no documentary
  release receipt is invented. The first receipt still commits to the actual
  genesis source-set head even though no source or documentary facts are present.
- Replays, cancellation, receiver failures, wrong Safe callers and pause rejection
  preserve relevant counters, authorizations, intents, proceeds, payer/wallet
  balances, liabilities, Core allocation, entropy and candidate floor history.
  Exact receiver retries reuse the original signatures and payload, not replacements.

Sensitivity cases detect individual payer corruption despite unchanged aggregate
balances, reject an empty campaign and a missing random tail, and detect a
substituted missing first-sale read after an actual successful payment. The read
substitution is only a checker sensitivity control, never successful sale proof.

## Input-fuzz properties

`StreamCurrentStackFuzzTest` preserves the original five properties covering exact
wei conservation and dust, incorrect-value rollback/retry, changed-price signature
rejection, replay and inclusive expiry. Two additional properties exercise the
actual Safe caller boundary and a named late-floor failure followed by an exact
retry against the genuine floor. Free mints remain distinct from first paid sales.

## Evidence boundary and remaining acceptance

This source batch uses the actual current graph and unchanged deployment limits.
The captured 1,272-source ABI/AST check passes and independent source reviews are
clear. These are preparation; the expanded native stateful/fuzz campaign remains
pending a fitting joined Artist implementation. No test runtime,
production size, cold-gas, full-v1 or testnet acceptance follows from authored cases.
The external entropy service is not requested or fulfilled by this campaign.

A separate **nonzero documentary release-history campaign remains required** after
the actual recorded-or-waived personhood provider/configuration handoff and fitting
Artist graph. It must preserve genuine non-WAIVED first/release evidence across
later sales, burns and pauses. Zero WAIVED release-link checks do not satisfy that
acceptance. Other Safe batch behavior retains its
[actual Safe cases](../integrations/current-safe-batches.md).
