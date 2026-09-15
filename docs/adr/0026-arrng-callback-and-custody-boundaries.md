# ADR 0026: ARRNG callback and custody boundaries

Accepted for implementation on 12 September 2026 under the owner's autonomous
delivery authority. This amends the ARRNG interpretation of the shared callback
gas parameter. It does not approve a deployed fallback or complete ENT-01/02.

## Problem

The reviewed [ARRNG controller source](https://github.com/arrng/arrng-contracts/blob/fdc0286a29c6c0041fbd1cd09022d28f25f68d21/contracts/controller/ArrngController.sol)
accepts payment and a refund address, but no callback gas argument. Its oracle
supplies incoming transaction gas. A locally stored parameter cannot impose an
upstream maximum the controller does not implement. A reverted callback also
leaves no durable onchain commitment to the attempted output. Stream must
distinguish a retained result from a callback that never reached storage.

## Decision

1. On the ARRNG host, `VRF_CALLBACK_GAS_LIMIT` bounds the
   **adapter-to-Stream-coordinator** subcall. It keeps its canonical identifier,
   schema-v2 events, immutable floor, delayed class-1 authority, monotonic value
   and 2x raise bound. This is an explicit family-specific exception to the
   upstream-forwarding description in EP-VRF-CONFIG. VRF and Pyth retain their
   respective upstream request semantics.
2. Each request captures its initial delivery cap. Raises affect new requests
   and retries; the first callback retains its captured cap. Supplemental events
   identify configured and forwarded gas, including zero when delivery was not
   attempted. None of these values claims to bound the incoming ARRNG frame.
3. Authenticate the controller and request, accept exactly one word, then store
   raw output before coordinator delivery. Keep a completion reserve, use
   overflow-safe EIP-150 admission and copy at most one return word. Coordinator
   revert, OOG, malformed outcome or revocation cannot erase the stored output.
   A callback never reports successful completion before persistence.
4. Permissionless retry uses only stored output and the immutable coordinator,
   including after upstream authority drift. Failure before persistence remains
   unknown. Neither a missing local result nor an upstream redelivery promise
   authorizes a fresh draw. No new-draw recovery entry is introduced here.
5. Pin controller runtime and oracle source identity. Pin controller ownership
   separately as an operational fact. Quotes, submissions and callbacks reject
   drift. A delayed exact-context owner refresh adopts only the actual current
   owner while code and oracle pins remain unchanged. It emits the action ID
   and advances its own revision, preserving config hash and pending requests.
6. Entropy identity binds chain, coordinator, controller/code, oracle and word
   count. It excludes owner custody, payment, delivery cap and treasury. Oracle
   changes remain source changes requiring the provider-change lifecycle.
7. Quote the live configured payment, require it to cover the controller's
   minimum, and accept exactly that amount. The minimum does not promise timely
   service. Explicitly return refunds to the adapter, guard submission, and
   verify the exact request-counter transition. Failure rolls back payment and
   both request associations.
8. Refunds remain in the adapter until exact governed withdrawal pays the
   configured contract treasury. Forced ETH follows the same withdrawal route.
   Receipts and withdrawals are evented. Caller excess credit remains owned by
   the Stream coordinator; the provider does not create a duplicate ledger.

## Validation and rollout

Seventeen domain tests and a 256-input fuzz property pass independent review.
They cover submission/callback failures, raw persistence, conflicting duplicates,
gas raises and retry, exact governance contexts, owner refresh, actual two-owner
Safe retries and treasury receipts, failed withdrawal rollback and forced ETH.
Exact event reconstruction preserves the normative shared and source-specific
schemas; supplemental context events bind operational action IDs and revisions.
The tests use explicit upstream, coordinator and governance fault injectors.
Actual Core/Executor composition remains required.

ARRNG remains the preferred Ethereum implementation candidate. Deployed-code
and authority/custody checks, oracle service, measured incoming envelopes and
release sizing remain acceptance work; local tests do not establish them. Pyth
remains the specified alternate, and another chain's availability is not
Ethereum deployment evidence. EP-CUSTODY still applies to launch acceptance.

The standalone provider leaves Core and the permanent provider interface
unchanged. Its actual genesis/module inventory belongs to the new candidate.
RC1 remains immutable. Reveal policy/fee escrow, incident evidence, safe-mode
instances and fresh-recovery policy remain distinct required work.
